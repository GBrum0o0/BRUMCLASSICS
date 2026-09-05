import SwiftUI
import UIKit

struct PocketClassic: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var filename: String
    var retroAchievementID = ""
    var launcherGameID = ""
    var importedIntoRetroArch = false
    var progress: PocketProgress?
}

struct PocketProgress: Codable, Equatable {
    var username: String
    var gameID: Int
    var title: String
    var achievements: [Game.Achievement]
    var updatedAt: Date
    var unlocked: Int { achievements.filter(\.unlocked).count }

    static func decode(_ data: Data, username: String, expectedID: Int) throws -> Self {
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              raw["Error"] == nil, (raw["ID"] as? NSNumber)?.intValue == expectedID,
              let title = raw["Title"] as? String,
              let rows = raw["Achievements"] as? [String: [String: Any]] else {
            throw PocketError.message("O RetroAchievements não retornou o jogo solicitado. O cache foi preservado.")
        }
        let achievements = rows.compactMap { key, item -> Game.Achievement? in
            guard let title = item["Title"] as? String else { return nil }
            let soft = item["DateEarned"] as? String ?? ""
            let hard = item["DateEarnedHardcore"] as? String ?? ""
            return Game.Achievement(id: key, title: title, description: item["Description"] as? String ?? "", points: (item["Points"] as? NSNumber)?.intValue ?? 0, unlocked: !soft.isEmpty || !hard.isEmpty, hardcore: !hard.isEmpty, unlockedAt: hard.isEmpty ? soft : hard, badgeUrl: nil)
        }.sorted { $0.title < $1.title }
        return Self(username: username, gameID: expectedID, title: title, achievements: achievements, updatedAt: Date())
    }
}

enum PocketError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

enum PocketRules {
    static let extensions: Set<String> = ["gba", "gb", "gbc", "nes", "sfc", "smc", "n64", "z64", "v64", "nds", "sms", "gg", "md", "gen", "pce", "chd", "pbp", "iso", "cso", "rvz", "cue", "m3u", "gdi", "wad", "zip"]
    static func safeFilename(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") && !value.contains("\0")
    }
    static func launchURL(_ filename: String) -> URL? {
        guard safeFilename(filename) else { return nil }
        var parts = URLComponents(); parts.scheme = "retroarch"; parts.host = "game"; parts.path = "/" + filename
        return parts.url
    }
}

actor PocketFiles {
    private let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClassicsEverywhere", isDirectory: true)
    }
    func load() throws -> [PocketClassic] {
        let index = root.appendingPathComponent("games.json")
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        return try JSONDecoder().decode([PocketClassic].self, from: Data(contentsOf: index))
    }
    func save(_ games: [PocketClassic]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(games).write(to: root.appendingPathComponent("games.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    func file(_ game: PocketClassic) throws -> URL {
        guard PocketRules.safeFilename(game.filename) else { throw PocketError.message("Nome de arquivo inválido.") }
        return root.appendingPathComponent(game.id.uuidString, isDirectory: true).appendingPathComponent(game.filename)
    }
    func importROM(_ source: URL) throws -> PocketClassic {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        guard PocketRules.extensions.contains(source.pathExtension.lowercased()), PocketRules.safeFilename(source.lastPathComponent) else {
            throw PocketError.message("Formato não aceito. Para jogos com vários arquivos, importe um pacote ZIP completo; não envie um CUE sem seus BINs.")
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 8_589_934_592 else { throw PocketError.message("O arquivo precisa ser uma ROM válida de até 8 GB.") }
        let game = PocketClassic(id: UUID(), title: source.deletingPathExtension().lastPathComponent, filename: source.lastPathComponent)
        let destination = try file(game)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // File copy runs on this actor, away from the UI; original ROM and emulator saves are untouched.
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: destination.path)
        return game
    }
}

actor PocketRAClient {
    private let session = URLSession(configuration: .ephemeral)
    func progress(gameID: Int, username: String, key: String) async throws -> PocketProgress {
        guard gameID > 0, !username.isEmpty, !key.isEmpty else { throw PocketError.message("Informe usuário e Web API Key em Configurações do app → CLASSICS.") }
        var url = URLComponents(string: "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php")!
        url.queryItems = [URLQueryItem(name: "y", value: key), URLQueryItem(name: "u", value: username), URLQueryItem(name: "g", value: String(gameID))]
        var request = URLRequest(url: url.url!, timeoutInterval: 20)
        request.setValue("BRUMCLASSICS-iOS/0.7.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 12 * 1024 * 1024 else { throw PocketError.message("RetroAchievements indisponível ou credencial inválida. Tente mais tarde; o progresso salvo foi mantido.") }
        return try PocketProgress.decode(data, username: username, expectedID: gameID)
    }
}

@MainActor final class PocketClassicsStore: ObservableObject {
    @Published private(set) var games: [PocketClassic] = []
    @Published private(set) var busy = false
    @Published var message: String?
    @Published private(set) var status = ""
    @Published private(set) var runtimeRecords: [PocketRuntimeRecord] = []
    @Published private(set) var runtimeConfigured = false
    @Published private(set) var runtimeStatus = ""
    @Published private(set) var retroArchGames: [RetroArchLibraryGame] = []
    @Published private(set) var retroArchLibraryStatus = ""
    @Published private(set) var romFolderGames: [ROMFolderGame] = []
    @Published private(set) var romFolderConfigured = false
    @Published private(set) var romFolderName = "Downloads"
    @Published private(set) var romFolderStatus = ""
    private let runtime = PocketRuntimeFiles()
    private let retroArchFiles = RetroArchLibraryFiles()
    private let romFolder = ROMFolderAccess()
    private var timeBusy = false
    private let files = PocketFiles()
    private let api = PocketRAClient()
    private var loaded = false
    private var lastSync = Date.distantPast
    static let accountKey = "pocket-ra-credentials"
    struct Credentials: Codable { let username: String; let key: String }
    var credentials: Credentials? {
        guard let text = SecureStore.read(Self.accountKey), let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }
    func configure(username: String, key: String) throws {
        let account = Credentials(username: username.trimmingCharacters(in: .whitespacesAndNewlines), key: key.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !account.username.isEmpty, !account.key.isEmpty else { throw PocketError.message("Preencha usuário e Web API Key.") }
        let json = try JSONEncoder().encode(account)
        try SecureStore.write(String(decoding: json, as: UTF8.self), account: Self.accountKey)
        lastSync = .distantPast
    }
    func restore() async {
        guard !loaded else { return }
        do {
            games = try await files.load()
            loaded = true
            retroArchGames = (try? await retroArchFiles.load()) ?? []
            romFolderConfigured = await romFolder.configured
            romFolderName = await romFolder.displayName
            if romFolderConfigured { await refreshROMFolder() }
            await reloadRuntime()
        }
        catch { status = "Não foi possível ler o catálogo local. Seus arquivos foram preservados." }
    }
    func configureROMFolder(_ folder: URL) async {
        do {
            let scan = try await romFolder.configure(folder)
            romFolderConfigured = true
            romFolderName = await romFolder.displayName
            try await applyROMFolderScan(scan)
        } catch { message = error.localizedDescription }
    }
    func refreshROMFolder() async {
        let hasBookmark = await romFolder.configured
        guard romFolderConfigured || hasBookmark else {
            romFolderConfigured = false
            romFolderStatus = "Selecione a pasta de ROMs do RetroArch uma vez em Perfil → Configurações do app → CLASSICS."
            return
        }
        do {
            romFolderConfigured = true
            romFolderName = await romFolder.displayName
            try await applyROMFolderScan(try await romFolder.scan())
        } catch { romFolderStatus = "A pasta precisa ser autorizada novamente em Perfil → Configurações do app → CLASSICS. Seus dados foram preservados." }
    }
    private func applyROMFolderScan(_ scan: ROMFolderScan) async throws {
        var reconciled = games
        for rom in scan.games {
            if let index = reconciled.firstIndex(where: { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame }) {
                // Migrate only the display name. IDs, RetroAchievements progress and PC links stay intact.
                reconciled[index].title = rom.title
            } else {
                reconciled.append(PocketClassic(id: UUID(), title: rom.title, filename: rom.filename))
            }
        }
        if reconciled != games { try await files.save(reconciled); games = reconciled }
        romFolderGames = scan.games
        let duplicates = scan.duplicateFilenames > 0 ? " · \(scan.duplicateFilenames) arquivo(s) repetido(s) omitido(s)" : ""
        romFolderStatus = "\(scan.games.count) jogo(s) encontrado(s) em \(romFolderName)\(duplicates)."
    }
    func requestRetroArchLibrary() {
        retroArchLibraryStatus = "Consultando a biblioteca do RetroArch…"
        UIApplication.shared.open(RetroArchLibraryRules.queryURL()) { opened in
            if !opened { Task { @MainActor in self.retroArchLibraryStatus = "Instale a edição compatível do RetroArch fornecida com o BRUMCLASSICS." } }
        }
    }
    func receiveRetroArchLibrary(_ url: URL, launcher: AppStore) async {
        do {
            let decoded = try RetroArchLibraryRules.decode(url)
            try await retroArchFiles.save(decoded)
            retroArchGames = decoded
            // Build the BRUM metadata/link record from RetroArch's real library.
            // Never infer ownership or delete an old record when a playlist changes.
            var reconciled = games
            for retro in decoded {
                let existingIndex = reconciled.firstIndex { $0.filename.caseInsensitiveCompare(retro.filename) == .orderedSame }
                let normalized = normalizedLibraryTitle(retro.titleName)
                let matchingPC = launcher.snapshot.games.filter { $0.isClassic && normalizedLibraryTitle($0.title) == normalized }
                if let index = existingIndex {
                    reconciled[index].importedIntoRetroArch = true
                    if reconciled[index].launcherGameID.isEmpty, matchingPC.count == 1 { reconciled[index].launcherGameID = matchingPC[0].id }
                } else {
                    reconciled.append(PocketClassic(id: UUID(), title: retro.titleName, filename: retro.filename,
                        launcherGameID: matchingPC.count == 1 ? matchingPC[0].id : "", importedIntoRetroArch: true))
                }
            }
            if reconciled != games { try await files.save(reconciled); games = reconciled }
            retroArchLibraryStatus = decoded.isEmpty ? "O RetroArch respondeu, mas sua biblioteca está vazia." : "\(decoded.count) jogo(s) disponível(is) para abrir diretamente."
        } catch { message = error.localizedDescription }
    }
    func retroArchGame(for launcherGame: Game) -> RetroArchLibraryGame? {
        if let link = games.first(where: { $0.launcherGameID == launcherGame.id }),
           let exact = retroArchGames.first(where: { $0.filename.caseInsensitiveCompare(link.filename) == .orderedSame }) { return exact }
        let normalized = normalizedLibraryTitle(launcherGame.title)
        let matches = retroArchGames.filter { normalizedLibraryTitle($0.titleName) == normalized }
        return matches.count == 1 ? matches[0] : nil
    }
    func launcherGame(for retro: RetroArchLibraryGame, launcher: AppStore) -> Game? {
        if let link = games.first(where: { $0.filename.caseInsensitiveCompare(retro.filename) == .orderedSame }),
           let exact = launcher.snapshot.games.first(where: { $0.id == link.launcherGameID }) { return exact }
        let normalized = normalizedLibraryTitle(retro.titleName)
        let matches = launcher.snapshot.games.filter { $0.isClassic && normalizedLibraryTitle($0.title) == normalized }
        return matches.count == 1 ? matches[0] : nil
    }
    func pocketGame(for retro: RetroArchLibraryGame) -> PocketClassic? {
        games.first { $0.filename.caseInsensitiveCompare(retro.filename) == .orderedSame }
    }
    func retroArchGame(for rom: ROMFolderGame) -> RetroArchLibraryGame? {
        retroArchGames.first { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame }
    }
    func launcherGame(for rom: ROMFolderGame, launcher: AppStore) -> Game? {
        if let link = games.first(where: { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame && !$0.launcherGameID.isEmpty }),
           let exact = launcher.snapshot.games.first(where: { $0.id == link.launcherGameID }) { return exact }
        if let retro = retroArchGame(for: rom), let exact = launcherGame(for: retro, launcher: launcher) { return exact }
        let normalized = normalizedLibraryTitle(rom.title)
        let matches = launcher.snapshot.games.filter { $0.isClassic && normalizedLibraryTitle($0.title) == normalized }
        return matches.count == 1 ? matches[0] : nil
    }
    private func normalizedLibraryTitle(_ value: String) -> String {
        RetroArchLibraryRules.normalizedTitle(ROMTitleRules.clean(value))
    }
    func launchROM(_ rom: ROMFolderGame, launcher: AppStore) async {
        guard var record = games.first(where: { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame }) else {
            message = "Atualize a pasta de ROMs novamente antes de jogar."
            return
        }
        if record.launcherGameID.isEmpty, let matched = launcherGame(for: rom, launcher: launcher) {
            record.launcherGameID = matched.id
            record.title = matched.title
            await update(record)
        }
        if RetroArchDirectLaunchRules.supports(filename: rom.filename) {
            do {
                let directURL = try await romFolder.directLaunchURL(for: rom)
                // Optional runtime permissions must never prevent a valid ROM from opening.
                do { try await runtime.prepare(record, allGames: games) }
                catch { runtimeStatus = "O jogo pode abrir, mas a medição não foi preparada: \(error.localizedDescription)" }
                UIApplication.shared.open(directURL) { opened in
                    if !opened { Task { @MainActor in self.message = "O RetroArch compatível não aceitou a abertura direta. Confirme se a pasta escolhida pertence ao RetroArch." } }
                }
            } catch { message = error.localizedDescription }
            return
        }
        if retroArchGame(for: rom) != nil {
            await launch(record, launcher: launcher)
        } else {
            retroArchLibraryStatus = "Este formato não identifica sozinho o sistema. Organize a ROM em uma playlist do RetroArch e sincronize as playlists."
            requestRetroArchLibrary()
        }
    }
    func launchRetroArch(_ game: RetroArchLibraryGame, launcher: AppStore) async {
        guard let pocketGame = pocketGame(for: game) else { message = "Atualize a biblioteca do RetroArch novamente antes de jogar."; return }
        await launch(pocketGame, launcher: launcher)
    }
    private func reloadRuntime() async {
        do { runtimeRecords = try await runtime.load(); runtimeConfigured = try await runtime.configured() }
        catch { runtimeStatus = "Não foi possível ler o registro de horas. Seus arquivos foram preservados." }
    }
    func configureRuntime(_ folder: URL) async {
        do { try await runtime.configure(folder); await reloadRuntime(); runtimeStatus = "Pasta autorizada. Novos jogos iniciam a medição no próximo lançamento. Jogos já medidos precisam reestabelecer o ponto de partida." }
        catch { message = error.localizedDescription }
    }
    func runtimeSummary(_ id: UUID) -> String {
        guard let record = runtimeRecords.first(where: { $0.id == id }) else { return "Horas: habilite os logs e inicie o jogo pelo BRUMCLASSICS." }
        let seconds = record.creditedSeconds
        let pending = max(0, seconds - max(0, record.acknowledgedSeconds))
        return "No iPhone: \(seconds / 3600)h \((seconds % 3600) / 60)min · " + (pending > 0 ? "\(pending / 60)min pendentes no PC" : record.acknowledgedSeconds < 0 ? "aguardando vínculo com o PC" : "sincronizado")
    }
    func rebaseline(_ id: UUID) async {
        do { try await runtime.rebaseline(id); await reloadRuntime(); runtimeStatus = "Novo ponto de partida salvo. Horas já registradas e pendentes foram mantidas." }
        catch { message = error.localizedDescription }
    }
    func syncHours(launcher: AppStore) async {
        guard loaded, !timeBusy else { return }
        timeBusy = true; defer { timeBusy = false }
        var errors: [String] = []; var sent = false
        do { errors = try await runtime.collect(); await reloadRuntime() }
        catch { runtimeStatus = error.localizedDescription; return }
        if launcher.connection == .online, let fingerprint = launcher.configuration?.fingerprint {
            for record in runtimeRecords where record.acknowledgedSeconds < record.creditedSeconds {
                guard let game = games.first(where: { $0.id == record.id }), !game.launcherGameID.isEmpty else { continue }
                do {
                    let bound = try await runtime.bind(record.id, gameID: game.launcherGameID, fingerprint: fingerprint)
                    let receipt = try await launcher.syncPocketTime(bound)
                    try await runtime.acknowledge(record.id, sentSeconds: bound.creditedSeconds, receipt: receipt)
                    sent = true
                } catch { errors.append("\(game.title): \(error.localizedDescription)") }
            }
        }
        await reloadRuntime()
        if sent { await launcher.refresh() }
        runtimeStatus = errors.isEmpty ? "Horas lidas dos logs do RetroArch e salvas neste iPhone. Pendências serão enviadas com o app aberto na rede do PC." : errors.joined(separator: "\n")
    }
    func launch(_ game: PocketClassic, launcher: AppStore) async {
        do { try await runtime.prepare(game, allGames: games); await syncHours(launcher: launcher) }
        catch { runtimeStatus = "O jogo pode abrir, mas a medição não foi preparada: \(error.localizedDescription)" }
        guard let url = PocketRules.launchURL(game.filename) else { return }
        UIApplication.shared.open(url) { opened in if !opened { Task { @MainActor in self.message = "Instale o RetroArch 1.22.2 ou posterior. Importe e execute a ROM dentro dele primeiro." } } }
    }
    func importFiles(_ urls: [URL]) async {
        guard loaded else { message = "O catálogo não pôde ser aberto. Não vamos sobrescrever seus dados."; return }
        guard !busy else { return }; busy = true; defer { busy = false }
        var errors: [String] = []
        for url in urls {
            do {
                guard !games.contains(where: { $0.filename.caseInsensitiveCompare(url.lastPathComponent) == .orderedSame }) else { errors.append("\(url.lastPathComponent): já existe. Use um nome diferente para outra edição."); continue }
                let game = try await files.importROM(url)
                let next = games + [game]; try await files.save(next); games = next
            } catch { errors.append(error.localizedDescription) }
        }
        status = errors.isEmpty ? "ROMs copiadas para o iPhone. Envie-as ao RetroArch antes de jogar." : errors.joined(separator: "\n")
    }
    func update(_ game: PocketClassic) async {
        guard loaded else { return }
        let next = games.map { $0.id == game.id ? game : $0 }
        do { try await files.save(next); games = next; lastSync = .distantPast }
        catch { message = "Não foi possível salvar. Sua configuração anterior foi preservada." }
    }
    func file(_ game: PocketClassic) async throws -> URL { try await files.file(game) }
    func sync(launcher: AppStore, force: Bool = false) async {
        // Runtime logs and the offline outbox do not require a RetroAchievements key.
        await syncHours(launcher: launcher)
        guard loaded, !busy, let account = credentials, force || Date().timeIntervalSince(lastSync) >= 60 else { return }
        busy = true; lastSync = Date(); defer { busy = false }
        var errors: [String] = []; var refreshed = 0
        for item in games {
            guard let id = Int(item.retroAchievementID), id > 0 else { continue }
            do {
                let progress = try await api.progress(gameID: id, username: account.username, key: account.key)
                // Re-read the latest record after awaiting the API so an edited association is not overwritten.
                guard let current = games.first(where: { $0.id == item.id }), current.retroAchievementID == item.retroAchievementID else { continue }
                var next = current; next.progress = progress
                let updated = games.map { $0.id == next.id ? next : $0 }
                try await files.save(updated); games = updated; refreshed += 1
                if !next.launcherGameID.isEmpty, launcher.connection == .online {
                    if let error = await launcher.syncPocketAchievements(gameID: next.launcherGameID, raGameID: id, username: account.username) { errors.append(error) }
                }
            } catch { errors.append("\(item.title): não foi possível sincronizar. Confira a conta, o ID do jogo e a conexão.") }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        status = errors.isEmpty ? "\(refreshed) jogo(s) atualizado(s) pela conta RetroAchievements. O emulador deve estar online para registrar desbloqueios." : errors.joined(separator: "\n")
    }
}

struct ClassicsEverywhereView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var launcher: AppStore
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 20) {
            PageHeader(kicker: "CLASSICS", title: "CLASSICS Everywhere", subtitle: "Seus clássicos no iPhone · com RetroArch")
            HStack {
                Button("VERIFICAR \(pocket.romFolderName.uppercased())") { Task { await pocket.refreshROMFolder() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("rom-folder-refresh")
            }
            Text("A biblioteca mostra somente arquivos encontrados na pasta autorizada. Para a abertura direta funcionar, use uma pasta dentro de No Meu iPhone → RetroArch. Para trocar, abra Perfil → Configurações do app → CLASSICS.").font(.caption).foregroundStyle(BrumTheme.muted)
            if !pocket.romFolderConfigured {
                Text("Nenhuma pasta autorizada. Abra Perfil → Configurações do app → CLASSICS e selecione a pasta de ROMs do RetroArch uma vez.").foregroundStyle(BrumTheme.muted)
            } else if pocket.romFolderGames.isEmpty {
                Text("Nenhuma ROM compatível foi encontrada em \(pocket.romFolderName).").foregroundStyle(BrumTheme.muted)
            } else {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(pocket.romFolderGames) { rom in
                        ROMFolderGameTile(rom: rom, launcherGame: pocket.launcherGame(for: rom, launcher: launcher), retroArchReady: pocket.retroArchGame(for: rom) != nil) {
                            Task { await pocket.launchROM(rom, launcher: launcher) }
                        }
                    }
                }
            }
            if pocket.romFolderGames.contains(where: { !RetroArchDirectLaunchRules.supports(filename: $0.filename) }) {
                BrumSectionLabel(text: "FORMATOS QUE PRECISAM DE PLAYLIST")
                Text("ISO, CHD, ZIP, CUE e outros formatos podem representar sistemas diferentes. Para eles, organize o jogo no RetroArch e use a sincronização abaixo. O RetroArch abre e retorna ao BRUMCLASSICS automaticamente; isso é esperado e não inicia o jogo.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
                Button("SINCRONIZAR PLAYLISTS DO RETROARCH") { pocket.requestRetroArchLibrary() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("retroarch-library-refresh")
            }
            if !pocket.status.isEmpty { Text(pocket.status).font(.caption).foregroundStyle(BrumTheme.muted) }
            if !pocket.romFolderStatus.isEmpty { Text(pocket.romFolderStatus).font(.caption).foregroundStyle(BrumTheme.muted) }
            if !pocket.retroArchLibraryStatus.isEmpty { Text(pocket.retroArchLibraryStatus).font(.caption).foregroundStyle(BrumTheme.muted) }
        }.padding(20) }.background(BrumTheme.background.ignoresSafeArea()).navigationTitle("CLASSICS")
        .refreshable { await pocket.sync(launcher: launcher, force: true) }
        .task { await pocket.refreshROMFolder() }
    }
}

struct ROMFolderGameTile: View {
    let rom: ROMFolderGame
    let launcherGame: Game?
    let retroArchReady: Bool
    let play: () -> Void
    @State private var artwork: ROMArtwork?
    @State private var artworkImage: UIImage?
    private var displayedTitle: String { launcherGame?.title ?? artwork?.title ?? rom.title }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: play) {
                VStack(alignment: .leading, spacing: 8) {
                    if let launcherGame, !launcherGame.artworkPath.isEmpty {
                        GameCoverView(game: launcherGame).aspectRatio(0.72, contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(BrumTheme.surface).aspectRatio(0.72, contentMode: .fit)
                            .overlay {
                                if let artworkImage { Image(uiImage: artworkImage).resizable().scaledToFit() }
                                else { Image(systemName: "gamecontroller.fill").font(.largeTitle).foregroundStyle(BrumTheme.primary) }
                            }.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(displayedTitle).font(.system(size: 15, weight: .bold)).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                }
            }.buttonStyle(.plain).accessibilityLabel("Jogar \(displayedTitle)")
            Text(RetroArchDirectLaunchRules.supports(filename: rom.filename) ? "JOGAR · ABERTURA DIRETA" : retroArchReady ? "JOGAR · RETROARCH" : "PRECISA DE PLAYLIST")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(BrumTheme.primary)
        }.task(id: rom.id + (launcherGame?.artworkPath ?? "")) {
            guard launcherGame?.artworkPath.isEmpty != false else { return }
            let result = await ROMArtworkCache.shared.artwork(for: rom)
            guard !Task.isCancelled else { return }
            artwork = result
            artworkImage = result.flatMap { UIImage(contentsOfFile: $0.imageURL.path) }
        }
    }
}

struct RetroArchGameTile: View {
    let game: RetroArchLibraryGame
    let launcherGame: Game?
    let pocketID: UUID?
    let play: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: play) {
                VStack(alignment: .leading, spacing: 8) {
                if let launcherGame { GameCoverView(game: launcherGame).aspectRatio(0.72, contentMode: .fit) }
                else { RoundedRectangle(cornerRadius: 12).fill(BrumTheme.surface).aspectRatio(0.72, contentMode: .fit).overlay(Image(systemName: "gamecontroller.fill").font(.largeTitle).foregroundStyle(BrumTheme.primary)) }
                Text(game.titleName).font(.system(size: 15, weight: .bold)).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                }
            }.buttonStyle(.plain).accessibilityLabel("Jogar \(game.titleName)")
            HStack {
                Text("JOGAR · \((game.system ?? game.coreName ?? "CLASSICS").uppercased())").font(.system(size: 10, weight: .bold)).foregroundStyle(BrumTheme.primary)
                Spacer()
                if let pocketID { NavigationLink { PocketGameView(id: pocketID) } label: { Image(systemName: "info.circle").foregroundStyle(BrumTheme.muted) }.accessibilityLabel("Detalhes de \(game.titleName)") }
            }
        }
    }
}

struct PocketGameView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var launcher: AppStore
    let id: UUID
    @State private var raID = ""
    @State private var linkedID = ""
    private var game: PocketClassic? { pocket.games.first { $0.id == id } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            if let game {
                Text(game.title).font(.largeTitle.bold())
                if let playable = pocket.retroArchGames.first(where: { $0.filename.caseInsensitiveCompare(game.filename) == .orderedSame }) {
                    Button("JOGAR") { Task { await pocket.launchRetroArch(playable, launcher: launcher) } }.buttonStyle(PrimaryButtonStyle())
                    Text("O jogo foi confirmado pela biblioteca real do RetroArch. Um toque abre diretamente este título.").font(.caption).foregroundStyle(BrumTheme.muted)
                } else {
                    Button("ATUALIZAR BIBLIOTECA DO RETROARCH") { pocket.requestRetroArchLibrary() }.buttonStyle(PrimaryButtonStyle())
                    Text("Há metadados deste jogo no BRUMCLASSICS, mas o RetroArch não confirmou o arquivo jogável no iPhone. Uma capa não contém o jogo. Disponibilize legalmente a ROM no RetroArch uma vez e atualize a biblioteca.").font(.caption).foregroundStyle(BrumTheme.muted)
                }
                BrumSectionLabel(text: "HORAS OFFLINE")
                Text(pocket.runtimeSummary(id)).font(.subheadline)
                Text("Depois de jogar, use Close Content no RetroArch e volte aqui. Só contabilizamos o tempo registrado pelo emulador, não o tempo que ele ficou aberto em outro aplicativo.").font(.caption).foregroundStyle(BrumTheme.muted)
                Button("ATUALIZAR HORAS E CONQUISTAS") { Task { await pocket.sync(launcher: launcher, force: true) } }.disabled(pocket.busy)
                if pocket.runtimeRecords.first(where: { $0.id == id })?.counterReset == true {
                    Button("REESTABELECER PONTO DE PARTIDA DO LOG") { Task { await pocket.rebaseline(id) } }
                    Text("Mantém o histórico já medido e começa a contar os próximos acréscimos a partir do log atual.").font(.caption).foregroundStyle(BrumTheme.muted)
                }
                Text(pocket.runtimeStatus).font(.caption).foregroundStyle(BrumTheme.muted)
                BrumSectionLabel(text: "CONQUISTAS E VÍNCULO")
                TextField("ID do jogo no RetroAchievements", text: $raID).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Text("Use o número em retroachievements.org/game/… correspondente à ROM reconhecida pelo RetroArch. Uma capa ou um nome parecido não comprovam compatibilidade.").font(.caption).foregroundStyle(BrumTheme.muted)
                Picker("Mesmo jogo no launcher", selection: $linkedID) {
                    Text("Sem vínculo com um jogo do PC").tag("")
                    ForEach(launcher.snapshot.games.filter(\.isClassic)) { Text($0.title).tag($0.id) }
                }
                Button("SALVAR VÍNCULO E SINCRONIZAR") {
                    guard raID.isEmpty || (Int(raID) ?? 0) > 0 else { pocket.message = "Informe um ID numérico válido."; return }
                    var next = game; next.retroAchievementID = raID; next.launcherGameID = linkedID
                    if game.retroAchievementID != raID { next.progress = nil }
                    Task { await pocket.update(next); await pocket.sync(launcher: launcher, force: true) }
                }.disabled(pocket.busy)
                if let progress = game.progress { PocketAchievementList(progress: progress) }
                Text(pocket.status).font(.caption).foregroundStyle(BrumTheme.muted)
            }
        }.padding(20) }.background(BrumTheme.background.ignoresSafeArea()).navigationTitle("Jogar no iPhone")
        .onAppear { raID = game?.retroAchievementID ?? ""; linkedID = game?.launcherGameID ?? "" }
    }
}

struct PocketShare: Identifiable { let id = UUID(); let url: URL }
struct DocumentExportView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct PocketAchievementList: View {
    let progress: PocketProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(progress.unlocked)/\(progress.achievements.count) CONQUISTAS").font(.headline).foregroundStyle(BrumTheme.primary)
            Text("\(progress.username) · atualizado \(progress.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(BrumTheme.muted)
            ForEach(progress.achievements) { item in
                HStack(alignment: .top) { Image(systemName: item.unlocked ? "checkmark.seal.fill" : "lock.fill").foregroundStyle(item.unlocked ? BrumTheme.primary : BrumTheme.muted)
                    VStack(alignment: .leading) { Text(item.title).font(.subheadline.bold()); Text(item.description).font(.caption).foregroundStyle(BrumTheme.muted) }
                }
            }
        }
    }
}

struct PocketSetupView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var username = ""
    @State private var key = ""
    @State private var feedback = ""
    @State private var choosingRuntime = false
    var body: some View {
        Form {
            Section("1 · Instale o emulador") {
                Link("Baixar RetroArch compatível · Libretro", destination: URL(string: "https://buildbot.libretro.com/nightly/apple/ios-arm64/RetroArch.ipa")!)
                Button("Abrir RetroArch") { UIApplication.shared.open(URL(string: "retroarch://start")!) { opened in if !opened { Task { @MainActor in feedback = "RetroArch não encontrado. Instale o IPA compatível indicado acima." } } } }
                Text("Use a edição compatível indicada acima. A versão estável 1.22.2 da App Store abre o emulador, mas ainda não oferece ao BRUMCLASSICS consulta da biblioteca e abertura de um jogo específico.")
                Text("O jogo roda no RetroArch, não dentro do BRUMCLASSICS. A ROM precisa existir uma vez no iPhone; somente nomes e capas sincronizados não são arquivos jogáveis.")
            }
            Section("2 · Tela, volume e controles") {
                Text("No RetroArch: Settings → Video → Scaling → Aspect Ratio: Core provided. Isso preserva a proporção original. Ajuste Integer Scale se preferir pixels inteiros.")
                Text("Settings → Audio: ajuste Volume Gain. Settings → Input → On-Screen Overlay: habilite os botões na tela; controles Bluetooth usam o mapeamento do RetroArch.")
                Text("Antes de alterar um retroarch.cfg existente, copie-o no app Arquivos. O BRUMCLASSICS não sobrescreve suas preferências ou saves.")
            }
            Section("3 · RetroAchievements") {
                Text("No RetroArch: Settings → Achievements → Enabled. Entre com seu usuário e senha RetroAchievements. Use a MESMA conta no launcher e aqui. A Web API Key abaixo serve para consultar o progresso, não para desbloquear conquistas.")
                TextField("Usuário RetroAchievements", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Web API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Link("Obter minha Web API Key", destination: URL(string: "https://retroachievements.org/settings")!)
                Button("Salvar conta neste iPhone") { do { try pocket.configure(username: username, key: key); feedback = "Credenciais salvas no Keychain. Vincule o ID de cada jogo para consultar conquistas." } catch { feedback = error.localizedDescription } }
                Text("É necessário estar online no RetroArch para registrar conquistas. O modo Hardcore restringe save states. ROMs incompatíveis ou núcleos sem suporte não geram conquistas.")
            }
            Section("4 · Sincronização") {
                Text("Em CLASSICS Everywhere, as ROMs de plataformas identificáveis abrem diretamente com o núcleo compatível. Atualizar vínculo continua disponível para formatos ambíguos e jogos já organizados em playlists. Para atualizar o PC, vincule o mesmo jogo e use a mesma conta; o launcher deve estar atualizado, aberto e na rede local. Não copiamos ROMs nem saves para o PC.")
            }
            Section("5 · Horas offline do RetroArch") {
                Text("No RetroArch: Settings → Playlists → Save runtime log (aggregate): ON. Em Settings → Directory → Runtime Logs, confira a pasta usada. Feche o conteúdo após jogar para gravar o log.")
                Text("Selecione essa pasta no app Arquivos abaixo. Use os logs agregados (.lrtl), não pastas de um núcleo. A permissão é somente para leitura; não alteramos o emulador, saves ou ROMs.")
                Button(pocket.runtimeConfigured ? "REAUTORIZAR PASTA DE LOGS" : "AUTORIZAR PASTA DE LOGS") { choosingRuntime = true }
                Text("Antes da primeira sessão offline, vincule cada jogo ao mesmo CLASSICS do PC e inicie-o uma vez pelo BRUMCLASSICS com o launcher conectado. Isso registra o ponto de partida sem duplicar horas da conta. Horas antigas do emulador não são importadas automaticamente.")
                Text("Ao voltar à rede, mantenha este app aberto e o launcher ligado. O envio é automático e tolera novas tentativas. O iOS não permite garantir sincronização com o app encerrado. Sem internet, conquistas oficiais não são garantidas; tempo local e conquistas são independentes.")
                Text(pocket.runtimeStatus).font(.caption)
            }
            if !feedback.isEmpty { Section { Text(feedback) } }
        }.navigationTitle("CLASSICS · Configuração")
        .fileImporter(isPresented: $choosingRuntime, allowedContentTypes: [.folder]) { result in
            switch result { case .success(let folder): Task { await pocket.configureRuntime(folder) }; case .failure(let error): feedback = error.localizedDescription }
        }
        .onAppear { username = pocket.credentials?.username ?? ""; key = pocket.credentials?.key ?? "" }
    }
}
