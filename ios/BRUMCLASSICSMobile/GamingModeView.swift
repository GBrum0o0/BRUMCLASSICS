import SwiftUI
import UIKit

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Binding var selection: Int
    @State private var selectedGame: Game?
    @State private var selectedROM: ROMFolderGame?
    @AppStorage("gaming-mode-favorites-v1") private var favoritesJSON = "[]"

    private let columns = [GridItem(.adaptive(minimum: 135), spacing: 16)]
    private var favoriteIDs: Set<String> {
        guard let data = favoritesJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }
    private var libraryEntries: [GamingCatalogEntry] {
        GamingModeCatalog.library(local: pocket.romFolderGames, records: pocket.games, computer: store.snapshot.games)
    }
    private var recentEntries: [GamingCatalogEntry] {
        GamingModeCatalog.recent(libraryEntries, favorites: favoriteIDs)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Button { GamingOrientation.request(.portrait); selection = 0 } label: {
                        HStack(spacing: 10) {
                            BrumLogo(compact: true)
                            Text("BRUM CLASSICS").font(.caption.bold()).tracking(1.5).foregroundStyle(BrumTheme.text)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("gaming-mode-exit")
                    Spacer()
                    ConnectionDot(state: store.connection)
                }

                if !recentEntries.isEmpty {
                    gameSection(title: "JOGADOS RECENTEMENTE") {
                        ForEach(recentEntries) { entry in entryTile(entry) }
                    }
                }

                gameSection(title: "BIBLIOTECA") {
                    ForEach(libraryEntries) { entry in entryTile(entry) }
                }

                if libraryEntries.isEmpty {
                    BrumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NENHUM JOGO PRONTO").font(.headline.bold()).foregroundStyle(BrumTheme.text)
                            Text("Escolha uma pasta de ROMs no Perfil ou instale um jogo no computador.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            GamingOrientation.request(.landscape)
            await pocket.refreshROMFolder()
        }
        .fullScreenCover(item: $selectedGame) { GamingGameView(game: $0) }
        .fullScreenCover(item: $selectedROM) { GamingROMDetailView(rom: $0) }
    }

    private func gameSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BrumSectionLabel(text: title)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20, content: content)
        }
    }

    @ViewBuilder private func entryTile(_ entry: GamingCatalogEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            switch entry {
            case .local(let rom, _):
                ROMFolderGameTile(
                    rom: rom,
                    launcherGame: pocket.launcherGame(for: rom, launcher: store),
                    retroArchReady: pocket.isImportedIntoRetroArch(rom),
                    integratedCoreName: IntegratedEmulatorSupport.core(for: rom)?.displayName,
                    opensDetails: true
                ) { selectedROM = rom }
            case .computer(let game):
                Button { selectedGame = game } label: { GamingGameTile(game: game) }
                    .buttonStyle(.plain)
            }
            Button { toggleFavorite(entry.id) } label: {
                Image(systemName: favoriteIDs.contains(entry.id) ? "star.fill" : "star")
                    .font(.headline).foregroundStyle(BrumTheme.primary)
                    .padding(9).background(BrumTheme.surface).clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteIDs.contains(entry.id) ? "Remover \(entry.title) dos favoritos" : "Favoritar \(entry.title)")
        }
    }

    private func toggleFavorite(_ id: String) {
        var next = favoriteIDs
        if !next.insert(id).inserted { next.remove(id) }
        guard let data = try? JSONEncoder().encode(next.sorted()), let text = String(data: data, encoding: .utf8) else { return }
        favoritesJSON = text
    }
}

enum GamingCatalogEntry: Identifiable {
    case local(ROMFolderGame, Date?)
    case computer(Game)

    var id: String {
        switch self {
        case .local(let rom, _): return "local:\(rom.id)"
        case .computer(let game): return "pc:\(game.id)"
        }
    }
    var title: String {
        switch self {
        case .local(let rom, _): return rom.title
        case .computer(let game): return game.title
        }
    }
    var lastPlayedAt: Date? {
        switch self {
        case .local(_, let date): return date
        case .computer(let game): return GamingModeCatalog.date(game.lastPlayedAt)
        }
    }
}

enum GamingModeCatalog {
    static func library(local: [ROMFolderGame], records: [PocketClassic], computer: [Game]) -> [GamingCatalogEntry] {
        let localFiles = Set(local.map { $0.filename.lowercased() })
        let linkedPCIDs = Set(records.filter { localFiles.contains($0.filename.lowercased()) && !$0.launcherGameID.isEmpty }.map(\.launcherGameID))
        let localEntries = local.map { rom in
            GamingCatalogEntry.local(rom, records.first { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame }?.lastPlayedAt)
        }
        let pcEntries = computer.filter { $0.installed && !linkedPCIDs.contains($0.id) }.map(GamingCatalogEntry.computer)
        return (localEntries + pcEntries).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    static func recent(_ entries: [GamingCatalogEntry], favorites: Set<String>, limit: Int = 12) -> [GamingCatalogEntry] {
        let pinned = entries.filter { favorites.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let played = entries.filter { $0.lastPlayedAt != nil && !favorites.contains($0.id) }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        return Array((pinned + played).prefix(max(0, limit)))
    }

    static func date(_ stamp: String) -> Date? {
        guard !stamp.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: stamp) ?? ISO8601DateFormatter().date(from: stamp)
    }
}

private struct GamingROMDetailView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let rom: ROMFolderGame
    @State private var launchIntegrated = false
    @State private var launchingOnPC = false
    @State private var actionMessage = ""

    private var installedCore: CoreDescriptor? { IntegratedEmulatorSupport.core(for: rom) }
    private var system: EmulatedSystemID? { IntegratedEmulatorSupport.system(for: rom) }
    private var canUseRetroArch: Bool {
        if system == .nintendo3DS { return false }
        return RetroArchAppStoreLaunchRules.supports(filename: rom.filename) || pocket.isImportedIntoRetroArch(rom)
    }
    private var linkedPCGame: Game? {
        guard let link = pocket.games.first(where: {
            $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame && !$0.launcherGameID.isEmpty
        }) else { return nil }
        return store.snapshot.games.first { $0.id == link.launcherGameID && $0.installed }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(system?.rawValue.uppercased() ?? "CLASSICS")
                        .font(.caption.bold()).tracking(1.5).foregroundStyle(BrumTheme.primary)
                    Text(rom.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                    Text(rom.filename).font(.caption).foregroundStyle(BrumTheme.muted)
                    BrumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            BrumSectionLabel(text: "EXECUÇÃO NESTE IPHONE")
                            Text(routeDescription).font(.subheadline).foregroundStyle(BrumTheme.muted)
                            if system == .nintendo3DS {
                                Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?") · Azahar: \(installedCore == nil ? "arquivo ausente" : "arquivo presente")")
                                    .font(.caption2).foregroundStyle(BrumTheme.muted)
                                    .accessibilityIdentifier("brum-core-build-status")
                            }
                        }
                    }
                    if let core = installedCore {
                        Button { launchIntegrated = true } label: {
                            Text("\(CoreRegistry.experimental.contains(core) ? "TESTAR" : "JOGAR") NO BRUM CORE · \(core.displayName.uppercased())").frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle())
                    } else if canUseRetroArch {
                        Button {
                            Task { await pocket.launchROM(rom, launcher: store) }
                        } label: {
                            Text(pocket.isImportedIntoRetroArch(rom) ? "ABRIR NO RETROARCH" : "IMPORTAR PARA O RETROARCH")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle())
                    }
                    if let game = linkedPCGame {
                        Button {
                            launchingOnPC = true
                            Task {
                                let error = await store.launchBCard(game)
                                actionMessage = error.map { "Não foi possível iniciar no PC: \($0)" } ?? "Jogo iniciado no computador."
                                launchingOnPC = false
                            }
                        } label: { Text("JOGAR NO PC").frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.bordered).tint(BrumTheme.primary)
                            .disabled(store.connection != .online || launchingOnPC)
                    }
                    if !actionMessage.isEmpty { Text(actionMessage).font(.caption).foregroundStyle(BrumTheme.muted) }
                    if let message = pocket.message { Text(message).font(.caption).foregroundStyle(.orange) }
                }.frame(maxWidth: 700, alignment: .leading).padding(20).frame(maxWidth: .infinity)
            }
            .background(BrumTheme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
            } }
        }
        .onAppear { GamingOrientation.request(.landscape) }
        .sheet(item: $pocket.pendingROMShare) { ticket in
            DocumentExportView(url: ticket.url) { completed, error in
                Task { await pocket.finishROMShare(ticket, completed: completed, error: error) }
            }
        }
        .fullScreenCover(isPresented: $launchIntegrated) { IntegratedEmulatorView(rom: rom, returnsToPortrait: false) }
    }

    private var routeDescription: String {
        if let installedCore { return "\(installedCore.displayName) está incluído nesta instalação. A ROM será aberta pelo BRUM Core, sem importar para o RetroArch." }
        if system == .nintendo3DS { return "O arquivo 3DS foi reconhecido, mas o Azahar não está incluído nesta instalação. A importação para o RetroArch não ativaria o BRUM Core." }
        if canUseRetroArch { return "O BRUM Core ainda não tem um backend instalado para este jogo. A opção abaixo usa explicitamente o RetroArch e não conta como suporte integrado." }
        return "Este formato foi reconhecido, mas não há um backend de execução disponível nesta instalação. O arquivo original foi preservado."
    }
}

@MainActor enum GamingOrientation {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard #available(iOS 16.0, *) else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
    }
}

private struct GamingGameTile: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameCoverView(game: game, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
            Text(game.platform.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.primary)
            Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
            Text("NO COMPUTADOR").font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
        }
    }
}

private struct GamingGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var launchState = ""
    @State private var launching = false
    @State private var openingClient = false

    private var streaming: StreamingStatus? { store.snapshot.experience?.streaming }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GameCoverView(game: game, cornerRadius: 16).aspectRatio(0.72, contentMode: .fit).frame(maxWidth: 330).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(routeLabel).font(.caption.bold()).tracking(1.5).foregroundStyle(BrumTheme.primary)
                        Text(game.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text(game.description).font(.body).foregroundStyle(BrumTheme.muted)
                    }
                    Button(action: playStream) { HStack { if launching { ProgressView().tint(.black) }; Text(streamPlayLabel) }.frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!canPlay || launching).opacity(canPlay ? 1 : 0.38)
                    Button(action: playOnPC) { Text("SOMENTE INICIAR NO COMPUTADOR").font(.caption.bold()).frame(maxWidth: .infinity).frame(height: 44) }
                        .buttonStyle(.bordered).tint(BrumTheme.primary).disabled(!canStartOnPC || launching).opacity(canStartOnPC ? 1 : 0.38)
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    BrumCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { BrumSectionLabel(text: "STREAMING"); Spacer(); Text(streaming?.available == true ? "PRONTO" : "AÇÃO NECESSÁRIA").font(.caption2.bold()).foregroundStyle(streaming?.available == true ? BrumTheme.primary : .orange) }
                            Text(streamingDescription).font(.caption).foregroundStyle(BrumTheme.muted)
                            if streaming?.network.remoteReady == true { Label("Acesso remoto protegido disponível", systemImage: "checkmark.shield.fill").font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
                        }
                    }
                }.padding(20)
            }.background(BrumTheme.background.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) } } }
        }
        .onAppear { GamingOrientation.request(.landscape) }
    }

    private var routeLabel: String { "PC · CANAL SEGURO" }
    private var streamPlayLabel: String {
        if !game.installed { return "INSTALAÇÃO NÃO CONFIRMADA" }
        if store.connection != .online { return "COMPUTADOR OFFLINE" }
        return streaming?.available == true ? "JOGAR NO IPHONE" : "CONFIGURE O STREAMING NO PC"
    }
    private var canPlay: Bool { game.installed && store.connection == .online && streaming?.available == true }
    private var canStartOnPC: Bool { game.installed && store.connection == .online }
    private var streamingDescription: String {
        guard let streaming else { return "Atualize e sincronize o launcher para verificar Sunshine e Moonlight." }
        if streaming.available { return streaming.network.remoteReady ? "Sunshine ativo. Funciona na rede local e pela rede privada configurada." : "Sunshine ativo na rede local. Conecte Tailscale no computador e no iPhone para jogar fora de casa." }
        return streaming.message
    }

    private func playOnPC() {
        launching = true
        launchState = "Conectando ao computador e validando a instalação…"
        Task {
            let error = await store.launchBCard(game)
            await MainActor.run {
                launching = false
                launchState = error.map { "Não foi possível iniciar: \($0)" } ?? "Jogo iniciado no computador."
            }
        }
    }

    private func playStream() {
        launching = true
        launchState = "Preparando vídeo, áudio e controles…"
        Task {
            let result = await store.launchStream(game)
            await MainActor.run {
                launching = false
                switch result {
                case .success(let session):
                    launchState = "Jogo iniciado. Abrindo Moonlight…"
                    openStreamingClient(session)
                case .failure(let error): launchState = "Não foi possível iniciar: \(error.localizedDescription)"
                }
            }
        }
    }

    private func openStreamingClient(_ session: StreamingSession) {
        guard !openingClient else { return }
        openingClient = true
        let scheme = URL(string: session.client.iosScheme)
        let storeURL = URL(string: session.client.iosStoreURL)
        if let scheme {
            UIApplication.shared.open(scheme, options: [:]) { opened in
                if !opened, let storeURL { UIApplication.shared.open(storeURL) }
                Task { @MainActor in openingClient = false }
            }
        } else {
            if let storeURL { UIApplication.shared.open(storeURL) }
            openingClient = false
        }
    }
}
