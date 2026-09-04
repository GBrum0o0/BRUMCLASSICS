import SwiftUI
import UniformTypeIdentifiers
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
    static let extensions: Set<String> = ["gba", "gb", "gbc", "nes", "sfc", "smc", "n64", "z64", "v64", "nds", "sms", "gg", "md", "gen", "pce", "chd", "pbp", "iso", "zip"]
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
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeFileProtectionUnlessOpen], ofItemAtPath: destination.path)
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
        request.setValue("BRUMCLASSICS-iOS/0.4.0", forHTTPHeaderField: "User-Agent")
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
        do { games = try await files.load(); loaded = true }
        catch { status = "Não foi possível ler o catálogo local. Seus arquivos foram preservados." }
    }
    func importFiles(_ urls: [URL]) async {
        guard loaded, !busy else { return }; busy = true; defer { busy = false }
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
    @State private var importing = false
    private var contentTypes: [UTType] { PocketRules.extensions.compactMap { UTType(filenameExtension: $0) } + [.data] }
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 20) {
            PageHeader(kicker: "CLASSICS", title: "CLASSICS in every everywhere", subtitle: "Seus clássicos no iPhone · com RetroArch")
            NavigationLink { PocketSetupView() } label: { SettingsRow(icon: "gearshape", title: "CONFIGURAR RETROARCH", detail: "Instalação, tela, áudio e RetroAchievements") }
            Button(pocket.busy ? "PROCESSANDO…" : "ADICIONAR JOGOS DO IPHONE") { importing = true }.buttonStyle(PrimaryButtonStyle()).disabled(pocket.busy)
            Text("Importe somente arquivos que você tem direito de usar. ROMs, BIOS e núcleos não são baixados pelo BRUMCLASSICS.").font(.caption).foregroundStyle(BrumTheme.muted)
            if pocket.games.isEmpty { Text("Sua biblioteca local está vazia. Adicione uma ROM pelo app Arquivos.").foregroundStyle(BrumTheme.muted) }
            ForEach(pocket.games) { game in NavigationLink { PocketGameView(id: game.id) } label: { SettingsRow(icon: "gamecontroller", title: game.title, detail: game.progress.map { "\($0.unlocked)/\($0.achievements.count) conquistas · no iPhone" } ?? "ROM no iPhone · configurar e jogar") } }
            if !pocket.status.isEmpty { Text(pocket.status).font(.caption).foregroundStyle(BrumTheme.muted) }
        }.padding(20) }.background(BrumTheme.background.ignoresSafeArea()).navigationTitle("CLASSICS")
        .fileImporter(isPresented: $importing, allowedContentTypes: contentTypes, allowsMultipleSelection: true) { result in
            switch result { case .success(let urls): Task { await pocket.importFiles(urls) }; case .failure(let error): pocket.message = error.localizedDescription }
        }
        .refreshable { await pocket.sync(launcher: launcher, force: true) }
    }
}

struct PocketGameView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var launcher: AppStore
    let id: UUID
    @State private var share: PocketShare?
    @State private var raID = ""
    @State private var linkedID = ""
    private var game: PocketClassic? { pocket.games.first { $0.id == id } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            if let game {
                Text(game.title).font(.largeTitle.bold())
                Text("1. Envie o arquivo e escolha RetroArch. Se ele não aparecer, use Salvar em Arquivos → No Meu iPhone → RetroArch → downloads. Dentro do emulador, carregue o conteúdo e selecione um núcleo compatível pelo menos uma vez.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                Button("ENVIAR ARQUIVO AO RETROARCH") { Task { do { share = PocketShare(url: try await pocket.file(game)) } catch { pocket.message = error.localizedDescription } } }.buttonStyle(PrimaryButtonStyle())
                Toggle("Já importei e executei este jogo no RetroArch", isOn: Binding(get: { game.importedIntoRetroArch }, set: { value in var next = game; next.importedIntoRetroArch = value; Task { await pocket.update(next) } }))
                Button("JOGAR NO RETROARCH") {
                    guard let url = PocketRules.launchURL(game.filename) else { return }
                    UIApplication.shared.open(url) { opened in if !opened { Task { @MainActor in pocket.message = "Instale o RetroArch 1.22.2 ou posterior. Se o emulador abrir sem o jogo, importe a ROM e execute-a primeiro dentro dele." } } }
                }.buttonStyle(PrimaryButtonStyle()).disabled(!game.importedIntoRetroArch)
                Text("O iOS confirma a abertura do emulador, não se a ROM iniciou. ZIPs podem precisar ser extraídos no RetroArch; use o nome do arquivo final para o atalho.").font(.caption).foregroundStyle(BrumTheme.muted)
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
        .sheet(item: $share) { DocumentExportView(url: $0.url) }
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
    var body: some View {
        Form {
            Section("1 · Instale o emulador") {
                Link("RetroArch na App Store", destination: URL(string: "https://apps.apple.com/app/retroarch/id6499539433")!)
                Button("Abrir RetroArch") { UIApplication.shared.open(URL(string: "retroarch://start")!) { opened in if !opened { Task { @MainActor in feedback = "RetroArch não encontrado. Instale pela App Store." } } } }
                Text("O jogo roda no RetroArch, não dentro do BRUMCLASSICS. Os dados de outros aplicativos são protegidos pelo iOS.")
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
                Text("Ao voltar ao BRUMCLASSICS, os jogos vinculados são consultados na API oficial e ficam disponíveis offline na seção Conquistas. Para atualizar o PC, vincule o mesmo jogo e use a mesma conta; o launcher deve estar atualizado, aberto e na rede local. Não copiamos ROMs nem saves para o PC.")
            }
            if !feedback.isEmpty { Section { Text(feedback) } }
        }.navigationTitle("CLASSICS · Configuração")
        .onAppear { username = pocket.credentials?.username ?? ""; key = pocket.credentials?.key ?? "" }
    }
}
