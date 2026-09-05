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
    @Published private(set) var realtimeWarning: String?
    @Published private(set) var pendingGameIDs: Set<String> = []
    @Published private(set) var noteConflicts: Set<String> = []
    @Published private(set) var capturingMoment = false
    @Published private(set) var performanceReceivedUptime: TimeInterval?
    @Published private(set) var personalUpdate: PersonalUpdateState = .idle
    @Published var selectedGame: Game?
    @Published var message: String?

    private let bridge = BridgeClient()
    private let offline = OfflineStore()
    private let updates = PersonalUpdateService()
    private let images = NSCache<NSString, UIImage>()
    private var eventTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var artworkSignature = ""
    private var flushing = false
    private var appActive = true
    private static let configurationKey = "brum_pairing_configuration"
    private static let tokenAccount = "launcher-token"
    private static let localLaunchesKey = "brum_local_game_launches_v1"

    init() {
        images.countLimit = 80
        Task { await restore() }
    }

    var isPaired: Bool { configuration != nil && SecureStore.read(Self.tokenAccount) != nil }
    var activeGame: Game? { guard snapshot.companion?.active == true else { return nil }; return snapshot.games.first { $0.id == snapshot.companion?.gameId } }
    var companionGame: Game? { guard let game = activeGame, game.notes.hasContent else { return nil }; return game }
    var canCaptureMoment: Bool { connection == .online && activeGame != nil && !capturingMoment }

    func syncPocketAchievements(gameID: String, raGameID: Int, username: String) async -> String? {
        do { try await bridge.syncPocketAchievements(gameID: gameID, raGameID: raGameID, username: username); await refresh(); return nil }
        catch { return "Progresso salvo no iPhone. O PC ainda não confirmou: \(error.localizedDescription). Atualize o launcher e confira a mesma conta e o vínculo do jogo." }
    }

    func syncPocketTime(_ record: PocketRuntimeRecord) async throws -> PocketTimeReceipt {
        guard connection == .online, configuration?.fingerprint == record.serverFingerprint else { throw PocketError.message("Conecte-se ao PC original para enviar as horas pendentes.") }
        return try await bridge.syncPocketTime(record)
    }

    func restore() async {
        if let cached = await offline.loadSnapshot() { snapshot = cached; applyLocalLaunches() }
        moments = await offline.loadMoments()
        if let data = UserDefaults.standard.data(forKey: Self.configurationKey), let decoded = try? JSONDecoder().decode(PairingConfiguration.self, from: data) { configuration = decoded }
        await overlayPending()
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
            eventTask?.cancel(); eventTask = nil
            await bridge.closeEvents()
            let (configuration, token) = try await bridge.pair(payload)
            try SecureStore.write(token, account: Self.tokenAccount)
            self.configuration = configuration
            UserDefaults.standard.set(try JSONEncoder().encode(configuration), forKey: Self.configurationKey)
            connection = .online
            await refresh()
            startRealtime()
            message = connection == .online ? "iPhone conectado e biblioteca sincronizada." : "iPhone pareado. Consulte o diagnóstico em Perfil para concluir a sincronização."
        } catch { connection = .error(error.localizedDescription); message = error.localizedDescription }
    }

    func disconnect() async {
        try? await bridge.unpair()
        eventTask?.cancel(); eventTask = nil; artworkTask?.cancel(); artworkTask = nil; artworkSignature = ""
        await bridge.closeEvents()
        SecureStore.remove(Self.tokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.configurationKey)
        configuration = nil; connection = .offline
        realtimeWarning = nil
        await bridge.configure(nil, token: nil)
        message = "O pareamento foi removido. A biblioteca offline permanece neste iPhone."
    }

    func refresh() async {
        guard isPaired else { connection = .offline; return }
        if let refreshTask { await refreshTask.value; return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            if self.connection != .online { self.connection = .connecting }
            do {
                await self.flushOutbox()
                let fresh = try await self.bridge.snapshot()
                guard !fresh.games.isEmpty || self.snapshot.games.isEmpty else { throw BridgeError.invalidResponse("A resposta vazia foi ignorada para preservar sua biblioteca offline.") }
                let previousPerformance = self.snapshot.performance
                self.snapshot = fresh
                self.applyLocalLaunches()
                if previousPerformance?.sampledAt != fresh.performance?.sampledAt { self.performanceReceivedUptime = fresh.performance?.active == true ? ProcessInfo.processInfo.systemUptime : nil }
                await self.overlayPending()
                try await self.offline.saveSnapshot(self.snapshot)
                self.connection = .online
                self.prefetchAllArtwork()
            } catch {
                self.connection = .error(error.localizedDescription)
            }
            self.refreshTask = nil
        }
        await refreshTask?.value
    }

    func resume() async {
        appActive = true
        await refresh()
        if isPaired { startRealtime() }
    }

    func suspend() {
        appActive = false
        eventTask?.cancel(); eventTask = nil
        artworkTask?.cancel(); artworkTask = nil; artworkSignature = ""
        if connection == .online { connection = .offline }
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

    func launchBCard(_ game: Game, mode: String = "new") async -> String? {
        guard connection == .online else { return "Conecte o iPhone ao launcher na mesma rede." }
        guard game.installed else { return "Este jogo não está confirmado como instalado." }
        do {
            try await bridge.remote(command: "bcard_launch", payload: ["gameId": game.id, "mode": mode], requestID: UUID().uuidString)
            return nil
        } catch { return error.localizedDescription }
    }

    func recordLocalLaunch(gameID: String, at date: Date = Date()) async {
        guard let index = snapshot.games.firstIndex(where: { $0.id == gameID }) else { return }
        let stamp = ISO8601DateFormatter().string(from: date)
        var launches = localLaunches()
        launches[gameID] = stamp
        if let data = try? JSONEncoder().encode(launches) { UserDefaults.standard.set(data, forKey: Self.localLaunchesKey) }
        snapshot.games[index].lastPlayedAt = stamp
        try? await offline.saveSnapshot(snapshot)
    }

    func captureMoment() async {
        guard connection == .online else { message = "Conecte-se ao launcher para tirar um print."; return }
        guard !capturingMoment else { return }
        guard let game = activeGame else { message = "Inicie um jogo pelo launcher antes de capturar um BRUMMOMENT."; return }
        capturingMoment = true
        defer { capturingMoment = false }
        do {
            let (metadata, image) = try await bridge.captureMoment(gameID: game.id)
            _ = try await offline.saveMoment(data: image, gameID: metadata.gameId, gameTitle: metadata.gameTitle, capturedAt: metadata.capturedAt)
            moments = await offline.loadMoments(); AppHaptics.success(); message = "BRUMMOMENT salvo neste iPhone."
        } catch { message = error.localizedDescription }
    }

    func updateMoment(_ moment: BrumMoment) async { try? await offline.updateMoment(moment); moments = await offline.loadMoments() }
    func removeMoment(_ moment: BrumMoment) async { try? await offline.removeMoment(moment); moments = await offline.loadMoments() }
    func momentImage(_ moment: BrumMoment) async -> UIImage? { guard let data = await offline.momentImage(moment) else { return nil }; return UIImage(data: data) }

    func saveNotes(game: Game, notes: Game.Notes, force: Bool = false) async -> Bool {
        let existing = await offline.loadOutbox().first { $0.kind == .notes && $0.gameID == game.id }
        let mutation = PendingMutation(id: UUID(), kind: .notes, gameID: game.id, revision: existing?.revision ?? game.notes.revision, force: force, notes: notes, favorite: nil, wantToPlay: nil, queuedAt: Date(), baseNotes: existing?.baseNotes ?? game.notes)
        return await queue(mutation)
    }

    func setLibraryState(game: Game, favorite: Bool, wantToPlay: Bool) async {
        let mutation = PendingMutation(id: UUID(), kind: .libraryState, gameID: game.id, revision: game.libraryStateRevision, force: false, notes: nil, favorite: favorite, wantToPlay: wantToPlay, queuedAt: Date())
        _ = await queue(mutation)
    }

    private func queue(_ mutation: PendingMutation) async -> Bool {
        var outbox = await offline.loadOutbox()
        outbox.removeAll { $0.kind == mutation.kind && $0.gameID == mutation.gameID }
        outbox.append(mutation)
        do { try await offline.saveOutbox(outbox) }
        catch { message = "Não foi possível salvar no iPhone. Suas alterações continuam no editor."; return false }
        await overlayPending()
        if isPaired { await flushOutbox(); await refresh() }
        else { message = "Alteração salva no iPhone. Ela será enviada quando o launcher reaparecer na rede local." }
        return true
    }

    private func flushOutbox() async {
        guard isPaired, !flushing else { return }
        flushing = true
        defer { flushing = false }
        let outbox = await offline.loadOutbox()
        for mutation in outbox {
            do {
                try await bridge.save(mutation)
                var latest = await offline.loadOutbox()
                latest.removeAll { $0.id == mutation.id }
                try await offline.saveOutbox(latest)
                noteConflicts.remove(mutation.gameID)
            } catch BridgeError.conflict { noteConflicts.insert(mutation.gameID) }
            catch { break }
        }
        await overlayPending()
    }

    private func overlayPending() async {
        let pending = await offline.loadOutbox()
        pendingCount = pending.count
        pendingGameIDs = Set(pending.map(\.gameID))
        for mutation in pending {
            guard let index = snapshot.games.firstIndex(where: { $0.id == mutation.gameID }) else { continue }
            if let notes = mutation.notes { snapshot.games[index].notes = notes }
            if let favorite = mutation.favorite { snapshot.games[index].favorite = favorite }
            if let wantToPlay = mutation.wantToPlay { snapshot.games[index].wantToPlay = wantToPlay }
        }
    }

    private func localLaunches() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: Self.localLaunchesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return decoded
    }

    private func applyLocalLaunches() {
        let launches = localLaunches()
        for index in snapshot.games.indices {
            guard let local = launches[snapshot.games[index].id] else { continue }
            let remote = snapshot.games[index].lastPlayedAt
            if remote.isEmpty || local > remote { snapshot.games[index].lastPlayedAt = local }
        }
    }

    func useLauncherNotes(gameID: String) async -> Bool {
        do {
            let fresh = try await bridge.snapshot()
            var pending = await offline.loadOutbox()
            pending.removeAll { $0.gameID == gameID && $0.kind == .notes }
            try await offline.saveOutbox(pending)
            snapshot = fresh; applyLocalLaunches(); noteConflicts.remove(gameID)
            await overlayPending()
            try await offline.saveSnapshot(snapshot)
            connection = .online
            return true
        } catch { message = "Não foi possível obter as anotações do launcher. O rascunho foi mantido."; return false }
    }

    private func prefetchAllArtwork() {
        // Jogos recentes chegam primeiro, mas a tarefa continua até persistir toda a biblioteca no iPhone.
        let candidates = snapshot.games.sorted { ($0.lastPlayedAt, $0.title) > ($1.lastPlayedAt, $1.title) }
        let signature = candidates.map { "\($0.id)|\($0.artworkPath)" }.joined(separator: "\n")
        guard signature != artworkSignature, appActive else { return }
        artworkTask?.cancel(); artworkSignature = signature
        artworkTask = Task(priority: .utility) { [weak self] in
            for game in candidates { guard !Task.isCancelled, let self else { return }; _ = await self.image(for: game) }
        }
    }

    private func startRealtime() {
        guard eventTask == nil, appActive else { return }
        eventTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isPaired else { return }
                do {
                    try await self.bridge.openEvents { [weak self] raw in
                        guard !raw.isEmpty, let self else { return }
                        await self.eventArrived(raw)
                    }
                } catch {
                    if !Task.isCancelled {
                        self.realtimeWarning = "Atualização ao vivo interrompida. Reconectando; a sincronização manual continua disponível."
                        await self.refresh()
                        try? await Task.sleep(for: .seconds(4))
                    }
                }
            }
        }
    }

    private func eventArrived(_ raw: String) async {
        guard let data = raw.data(using: .utf8), let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        realtimeWarning = nil
        if event["type"] as? String == "performance_changed" {
            if let payload = event["performance"], let data = try? JSONSerialization.data(withJSONObject: payload), let value = try? JSONDecoder().decode(PerformanceState.self, from: data) {
                if value.sampledAt != snapshot.performance?.sampledAt { performanceReceivedUptime = value.active ? ProcessInfo.processInfo.systemUptime : nil }
                snapshot.performance = value
            }
            return
        }
        guard ["ready", "library_changed", "companion_changed", "achievement_unlocked", "install_changed", "notes_changed", "library_state_changed", "collections_changed", "activity_changed", "profile_changed"].contains(event["type"] as? String ?? "") else { return }
        await refresh()
    }
}
