import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    enum ConnectionState: Equatable { case offline, connecting, online, error(String) }

    @Published private(set) var snapshot = LibrarySnapshot.empty
    @Published private(set) var connection: ConnectionState = .offline
    @Published private(set) var configuration: PairingConfiguration?
    @Published private(set) var pendingCount = 0
    @Published private(set) var moments: [BrumMoment] = []
    @Published private(set) var personalUpdate: PersonalUpdateState = .idle
    @Published var selectedGame: Game?
    @Published var message: String?

    private let bridge = BridgeClient()
    private let offline = OfflineStore()
    private let updates = PersonalUpdateService()
    private let images = NSCache<NSString, UIImage>()
    private var eventTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var lastEventRefresh = Date.distantPast
    private static let configurationKey = "brum_pairing_configuration"
    private static let tokenAccount = "launcher-token"

    init() {
        images.countLimit = 80
        Task { await restore() }
    }

    var isPaired: Bool { configuration != nil && SecureStore.read(Self.tokenAccount) != nil }
    var activeGame: Game? { guard snapshot.companion?.active == true else { return nil }; return snapshot.games.first { $0.id == snapshot.companion?.gameId } }

    func restore() async {
        if let cached = await offline.loadSnapshot() { snapshot = cached }
        moments = await offline.loadMoments()
        if let data = UserDefaults.standard.data(forKey: Self.configurationKey), let decoded = try? JSONDecoder().decode(PairingConfiguration.self, from: data) { configuration = decoded }
        pendingCount = await offline.loadOutbox().count
        await bridge.configure(configuration, token: SecureStore.read(Self.tokenAccount))
        if isPaired {
            await refresh()
            startRealtime()
        } else {
            connection = .offline
        }
        await checkForPersonalUpdate()
    }

    var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var installedBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }

    func checkForPersonalUpdate(showCurrentMessage: Bool = false) async {
        guard personalUpdate != .checking else { return }
        personalUpdate = .checking
        do {
            if let manifest = try await updates.check(currentVersion: installedVersion, currentBuild: installedBuild) {
                personalUpdate = .available(manifest)
            } else {
                personalUpdate = .current
                if showCurrentMessage { message = "Você já está usando a versão pessoal mais recente." }
            }
        } catch {
            personalUpdate = .failed(error.localizedDescription)
            if showCurrentMessage { message = error.localizedDescription }
        }
    }

    func pair(from url: URL) async {
        guard let payload = PairingPayload(url: url) else { message = BridgeError.invalidPairing.localizedDescription; return }
        connection = .connecting
        do {
            let (configuration, token) = try await bridge.pair(payload)
            try SecureStore.write(token, account: Self.tokenAccount)
            self.configuration = configuration
            UserDefaults.standard.set(try JSONEncoder().encode(configuration), forKey: Self.configurationKey)
            connection = .online
            await refresh()
            startRealtime()
            message = "iPhone conectado ao BRUMCLASSICS."
        } catch { connection = .error(error.localizedDescription); message = error.localizedDescription }
    }

    func disconnect() async {
        try? await bridge.unpair()
        eventTask?.cancel(); await bridge.closeEvents()
        SecureStore.remove(Self.tokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.configurationKey)
        configuration = nil; connection = .offline
        await bridge.configure(nil, token: nil)
        message = "O pareamento foi removido. A biblioteca offline permanece neste iPhone."
    }

    func refresh() async {
        guard isPaired else { connection = .offline; return }
        if refreshTask != nil { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            self.connection = .connecting
            do {
                let fresh = try await self.bridge.snapshot()
                guard !fresh.games.isEmpty || self.snapshot.games.isEmpty else { throw BridgeError.invalidResponse("A resposta vazia foi ignorada para preservar sua biblioteca offline.") }
                self.snapshot = fresh
                try await self.offline.saveSnapshot(fresh)
                await self.offline.pruneArtwork(keeping: fresh.games)
                await self.flushOutbox()
                self.connection = .online
                self.prefetchAllArtwork()
            } catch {
                self.connection = .error(error.localizedDescription)
            }
            self.refreshTask = nil
        }
        await refreshTask?.value
    }

    func image(for game: Game) async -> UIImage? {
        let key = "\(game.id)|\(game.artworkPath)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        if let data = await offline.cachedArtwork(for: game), let image = UIImage(data: data) { images.setObject(image, forKey: key); return image }
        guard isPaired else { return nil }
        do {
            let data = try await bridge.artwork(for: game)
            guard let image = UIImage(data: data) else { return nil }
            try await offline.saveArtwork(data, for: game)
            images.setObject(image, forKey: key)
            return image
        } catch { return nil }
    }

    func send(_ command: String, payload: [String: Any] = [:]) async {
        do { try await bridge.remote(command: command, payload: payload); connection = .online }
        catch { connection = .error(error.localizedDescription); message = error.localizedDescription }
    }

    func launchBCard(_ game: Game, mode: String = "new") async {
        guard game.installed else { message = "Este jogo não está confirmado como instalado."; return }
        do {
            try await bridge.remote(command: "bcard_launch", payload: ["gameId": game.id, "mode": mode], requestID: UUID().uuidString)
            message = "B-CARD enviado. Confirme a abertura no computador."
        } catch { message = error.localizedDescription }
    }

    func captureMoment() async {
        guard let game = activeGame else { message = "Inicie um jogo pelo launcher antes de capturar um BRUMMOMENT."; return }
        do {
            let (metadata, image) = try await bridge.captureMoment(gameID: game.id)
            _ = try await offline.saveMoment(data: image, gameID: metadata.gameId, gameTitle: metadata.gameTitle, capturedAt: metadata.capturedAt)
            moments = await offline.loadMoments(); AppHaptics.success(); message = "BRUMMOMENT salvo neste iPhone."
        } catch { message = error.localizedDescription }
    }

    func updateMoment(_ moment: BrumMoment) async { try? await offline.updateMoment(moment); moments = await offline.loadMoments() }
    func removeMoment(_ moment: BrumMoment) async { try? await offline.removeMoment(moment); moments = await offline.loadMoments() }
    func momentImage(_ moment: BrumMoment) async -> UIImage? { guard let data = await offline.momentImage(moment) else { return nil }; return UIImage(data: data) }

    func saveNotes(game: Game, notes: Game.Notes) async {
        let mutation = PendingMutation(id: UUID(), kind: .notes, gameID: game.id, revision: game.notes.revision, force: false, notes: notes, favorite: nil, wantToPlay: nil, queuedAt: Date())
        await queue(mutation)
    }

    func setLibraryState(game: Game, favorite: Bool, wantToPlay: Bool) async {
        let mutation = PendingMutation(id: UUID(), kind: .libraryState, gameID: game.id, revision: game.libraryStateRevision, force: false, notes: nil, favorite: favorite, wantToPlay: wantToPlay, queuedAt: Date())
        await queue(mutation)
    }

    private func queue(_ mutation: PendingMutation) async {
        var outbox = await offline.loadOutbox()
        outbox.removeAll { $0.kind == mutation.kind && $0.gameID == mutation.gameID }
        outbox.append(mutation)
        try? await offline.saveOutbox(outbox)
        pendingCount = outbox.count
        if isPaired { await flushOutbox(); await refresh() }
        else { message = "Alteração salva no iPhone. Ela será enviada quando o launcher reaparecer na rede local." }
    }

    private func flushOutbox() async {
        var outbox = await offline.loadOutbox()
        var remaining: [PendingMutation] = []
        for mutation in outbox {
            do { try await bridge.save(mutation) }
            catch { remaining.append(mutation) }
        }
        outbox = remaining
        try? await offline.saveOutbox(outbox)
        pendingCount = outbox.count
    }

    private func prefetchAllArtwork() {
        // Jogos recentes chegam primeiro, mas a tarefa continua até persistir toda a biblioteca no iPhone.
        let candidates = snapshot.games.sorted { ($0.lastPlayedAt, $0.title) > ($1.lastPlayedAt, $1.title) }
        Task.detached(priority: .utility) { [weak self] in
            for game in candidates { guard !Task.isCancelled, let self else { return }; _ = await self.image(for: game) }
        }
    }

    private func startRealtime() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isPaired else { return }
                do {
                    try await self.bridge.openEvents { [weak self] raw in
                        guard !raw.isEmpty, let self else { return }
                        await self.eventArrived()
                    }
                } catch {
                    if !Task.isCancelled { self.connection = .offline; try? await Task.sleep(for: .seconds(4)) }
                }
            }
        }
    }

    private func eventArrived() async {
        guard Date().timeIntervalSince(lastEventRefresh) > 0.7 else { return }
        lastEventRefresh = Date()
        await refresh()
    }
}
