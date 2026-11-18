import GameController
import SwiftUI
import UIKit

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Binding var selection: Int
    @State private var selectedGame: Game?
    @State private var selectedROM: ROMFolderGame?
    @State private var showLibrary = false
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
        VStack(spacing: 0) {
            GamingHeader {
                Button { GamingOrientation.request(.portrait); selection = 0 } label: {
                    HStack(spacing: 10) {
                        BrumLogo(compact: true)
                        Text("BRUM CLASSICS").font(.caption.bold()).tracking(1.2)
                    }.foregroundStyle(BrumTheme.text)
                }.buttonStyle(.plain).accessibilityIdentifier("gaming-mode-exit")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        libraryTab("JOGADOS RECENTEMENTE", selected: !showLibrary) { showLibrary = false }
                            .accessibilityIdentifier("gaming-mode-recent")
                        libraryTab("BIBLIOTECA", selected: showLibrary) { showLibrary = true }
                            .accessibilityIdentifier("gaming-mode-library")
                    }
                    if let featured = recentEntries.first ?? libraryEntries.first {
                        GamingHero(title: featured.title, platform: platform(for: featured), artwork: artwork(for: featured)) {
                            Button("VER DETALHES") { open(featured) }
                                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 180)
                        }
                        if showLibrary || recentEntries.isEmpty {
                            gameSection(title: "Biblioteca") { ForEach(libraryEntries) { entryTile($0) } }
                        } else {
                            gameSection(title: "Jogos recentes e favoritos") { ForEach(recentEntries) { entryTile($0) } }
                        }
                    } else {
                        BrumCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nenhum jogo pronto").font(.headline).foregroundStyle(BrumTheme.text)
                                Text("Toque na engrenagem acima para selecionar uma pasta de ROMs ou instale um jogo no computador.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.padding(20).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
            }
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

    private func libraryTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? BrumTheme.primary : BrumTheme.text)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(selected ? BrumTheme.primary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func open(_ entry: GamingCatalogEntry) {
        switch entry {
        case .local(let rom, _): selectedROM = rom
        case .computer(let game): selectedGame = game
        }
    }

    private func platform(for entry: GamingCatalogEntry) -> String {
        switch entry {
        case .local(let rom, _): return IntegratedEmulatorSupport.system(for: rom)?.rawValue.uppercased() ?? "CLASSICS"
        case .computer(let game): return game.platform
        }
    }

    private func artwork(for entry: GamingCatalogEntry) -> GamingArtwork {
        switch entry {
        case .local(let rom, _): return GamingArtwork(game: pocket.launcherGame(for: rom, launcher: store), rom: rom)
        case .computer(let game): return GamingArtwork(game: game)
        }
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
    static func canOfferRetroArch(for rom: ROMFolderGame, imported: Bool) -> Bool {
        // A remembered import is not evidence that RetroArch can execute 3DS.
        if IntegratedEmulatorSupport.system(for: rom) == .nintendo3DS { return false }
        return RetroArchAppStoreLaunchRules.supports(filename: rom.filename) || imported
    }

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
    @State private var launchIntegratedVirtualP2 = false
    @State private var launchingOnPC = false
    @State private var launchingGamepad = false
    @State private var showLocalMultiplayer = false
    @State private var showMurbManual = false
    @State private var activeMurbTarget: MurbRemoteLaunchTarget?
    @State private var syncingNativeSave = false
    @State private var confirmNativeUpload = false
    @State private var confirmNativeDownload = false
    @State private var actionMessage = ""
    @State private var associationTarget: PocketClassic?

    private var record: PocketClassic? {
        pocket.games.first { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame }
    }
    private var localTime: String {
        guard let record, let runtime = pocket.runtimeRecords.first(where: { $0.id == record.id }) else {
            return "Sem registro"
        }
        let minutes = max(0, runtime.creditedSeconds) / 60
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
    private var progress: PocketProgress? {
        guard let account = pocket.credentials, let record, let progress = record.progress,
              progress.gameID == Int(record.retroAchievementID),
              progress.username.caseInsensitiveCompare(account.username) == .orderedSame else { return nil }
        return progress
    }

    private var installedCore: CoreDescriptor? { IntegratedEmulatorSupport.core(for: rom) }
    private var system: EmulatedSystemID? { IntegratedEmulatorSupport.system(for: rom) }
    private var pcNativeSaveCompatible: Bool {
        guard let system else { return false }
        return Set<EmulatedSystemID>([.gameBoy, .gameBoyColor, .gameBoyAdvance,
                                      .nintendoEntertainmentSystem, .superNintendo]).contains(system)
    }
    private var canUseRetroArch: Bool {
        GamingModeCatalog.canOfferRetroArch(for: rom, imported: pocket.isImportedIntoRetroArch(rom))
    }
    private var linkedPCGame: Game? {
        guard let link = record, !link.launcherGameID.isEmpty else { return nil }
        return store.snapshot.games.first { $0.id == link.launcherGameID && $0.installed }
    }

    var body: some View {
        VStack(spacing: 0) {
            GamingHeader {
                Button { dismiss() } label: { Label("Biblioteca", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GamingHero(title: rom.title, platform: system?.rawValue.uppercased() ?? "CLASSICS",
                               artwork: GamingArtwork(game: pocket.launcherGame(for: rom, launcher: store), rom: rom)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ExecutionBadge(kind: installedCore != nil ? .onPhone : canUseRetroArch ? .externalApp : .unavailable)
                            GamingMetrics(time: localTime, timeLabel: "Tempo neste iPhone", earned: progress?.unlocked,
                                          total: progress?.achievements.count)
                        }
                    }
                    BrumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            BrumSectionLabel(text: "EXECUÇÃO NESTE IPHONE")
                            Text(routeDescription).font(.subheadline).foregroundStyle(BrumTheme.muted)
                            Text(executionScopeSummary).font(.caption).foregroundStyle(BrumTheme.muted)
                            if system == .nintendoDS || system == .nintendo3DS {
                                Text("Segunda tela e toque: \(system == .nintendoDS ? "SkyEmu oferece 8 layouts de tela dupla e toque direto integrado." : "Azahar 3DS suporta tela dupla e toque na build experimental.")")
                                    .font(.caption2).foregroundStyle(BrumTheme.primary)
                            }
                            if system == .nintendo3DS {
                                Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?") · Azahar: \(installedCore == nil ? "arquivo ausente" : "arquivo presente")")
                                    .font(.caption2).foregroundStyle(BrumTheme.muted)
                                    .accessibilityIdentifier("brum-core-build-status")
                            }
                        }
                    }
                    GamingInfoCard(title: "Informações da ROM", items: [
                        GamingInfoItem(label: "Sistema", value: system.map { MurbProtocol.displaySystemName($0.rawValue) } ?? "Não identificado"),
                        GamingInfoItem(label: "Núcleo", value: installedCore.map { "\($0.displayName) (\($0.license))" } ?? (canUseRetroArch ? "RetroArch externo" : "Sem núcleo instalado")),
                        GamingInfoItem(label: "Arquivo", value: rom.filename),
                        GamingInfoItem(label: "Tamanho", value: ByteCountFormatter.string(fromByteCount: rom.fileSize, countStyle: .file)),
                        GamingInfoItem(label: "RetroAchievements", value: Int(record?.retroAchievementID ?? "").map { "ID \($0)" } ?? "Não vinculado"),
                        GamingInfoItem(label: "Launcher PC", value: linkedPCGame?.title ?? "Não vinculado")
                    ])
                    GamingActionBar(
                        canPlay: installedCore != nil || canUseRetroArch || linkedPCGame != nil,
                        playTitle: "JOGAR",
                        playSubtitle: installedCore != nil ? "No celular · \(installedCore!.displayName)" : (canUseRetroArch ? "No celular · RetroArch" : "No PC"),
                        gamepadBusy: launchingGamepad,
                        pcOnline: store.connection == .online,
                        onPlay: {
                            if installedCore != nil {
                                launchIntegrated = true
                            } else if canUseRetroArch {
                                Task { await pocket.launchROM(rom, launcher: store) }
                            } else if let game = linkedPCGame {
                                launchingOnPC = true
                                Task {
                                    let error = await store.launchBCard(game)
                                    actionMessage = error.map { "Não foi possível iniciar no PC: \($0)" } ?? "Jogo iniciado no computador."
                                    launchingOnPC = false
                                }
                            }
                        },
                        onGamepad: launchGamepadFromROM,
                        onLocalMultiplayer: { showLocalMultiplayer = true }
                    )
                    if let core = installedCore {
                        Text("\(CoreRegistry.experimental.contains(core) ? "TESTAR" : "JOGAR · BRUM CORE") · \(core.displayName)")
                            .font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    } else if canUseRetroArch {
                        Text(pocket.isImportedIntoRetroArch(rom) ? "RetroArch pronto" : "Importar ROM para o RetroArch ao jogar")
                            .font(.caption).foregroundStyle(BrumTheme.muted)
                    }
                    if let game = linkedPCGame {
                        if installedCore != nil && pcNativeSaveCompatible {
                            Button { confirmNativeUpload = true } label: {
                                Text("ENVIAR SAVE NATIVO PARA O PC").frame(maxWidth: .infinity).frame(height: 44)
                            }
                            .buttonStyle(.bordered).tint(BrumTheme.primary)
                            .disabled(store.connection != .online || syncingNativeSave)
                            Button { confirmNativeDownload = true } label: {
                                Text("RECEBER SAVE NATIVO DO PC").frame(maxWidth: .infinity).frame(height: 44)
                            }
                            .buttonStyle(.bordered).tint(BrumTheme.primary)
                            .disabled(store.connection != .online || syncingNativeSave)
                        }
                        Button {
                            launchingOnPC = true
                            Task {
                                let error = await store.launchBCard(game)
                                actionMessage = error.map { "Não foi possível iniciar no PC: \($0)" } ?? "Jogo iniciado no computador."
                                launchingOnPC = false
                            }
                        } label: { Text("SOMENTE INICIAR NO COMPUTADOR").frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.bordered).tint(BrumTheme.primary)
                            .disabled(store.connection != .online || launchingOnPC)
                    }
                    GamingAchievements(title: "RetroAchievements", items: progress?.achievements ?? [],
                                       earned: progress?.unlocked, total: progress?.achievements.count,
                                       emptyMessage: localAchievementMessage)
                    Button(Int(record?.retroAchievementID ?? "") == nil ? "Vincular jogo ao RetroAchievements" : "Ver vínculo e sincronização") {
                        if let record {
                            associationTarget = record
                        } else {
                            Task { associationTarget = await pocket.ensureClassicRecord(for: rom) }
                        }
                    }.font(.subheadline.weight(.semibold)).tint(BrumTheme.primary)
                    if !actionMessage.isEmpty { Text(actionMessage).font(.caption).foregroundStyle(BrumTheme.muted) }
                    if let message = pocket.message { Text(message).font(.caption).foregroundStyle(.orange) }
                }.frame(maxWidth: 1000, alignment: .leading).padding(20).frame(maxWidth: .infinity)
            }
        }.background(BrumTheme.background.ignoresSafeArea())
        .sheet(item: $associationTarget) { target in
            NavigationStack { PocketGameView(id: target.id) }
                .preferredColorScheme(.dark)
        }
        .onAppear { GamingOrientation.request(.landscape) }
        .sheet(item: $pocket.pendingROMShare) { ticket in
            DocumentExportView(url: ticket.url) { completed, error in
                Task { await pocket.finishROMShare(ticket, completed: completed, error: error) }
            }
        }
        .fullScreenCover(isPresented: $launchIntegrated) { IntegratedEmulatorView(rom: rom, returnsToPortrait: false) }
        .fullScreenCover(isPresented: $launchIntegratedVirtualP2) { IntegratedEmulatorView(rom: rom, returnsToPortrait: false, virtualPadPort: 1) }
        .fullScreenCover(item: $activeMurbTarget) { target in
            MurbRemoteGamepadView(target: target.payload, gameTitle: target.gameTitle, playerNumber: target.playerNumber, p2Payload: target.p2Payload)
        }
        .sheet(isPresented: $showMurbManual) {
            MurbRemoteGamepadLauncherSheet().preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLocalMultiplayer) {
            LocalMultiplayerSheet(
                gameTitle: rom.title,
                pcAvailable: store.connection == .online,
                phoneCoopAvailable: installedCore != nil,
                onStartPhoneCoop: { virtualPort in
                    showLocalMultiplayer = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if virtualPort == 1 { launchIntegratedVirtualP2 = true } else { launchIntegrated = true }
                    }
                },
                onStartPCLanMultiplayer: { hybridMode, myPlayerNumber in
                    showLocalMultiplayer = false
                    startPCGamepadOrMultiplayer(players: 2, hybridMode: hybridMode, myPlayerNumber: myPlayerNumber)
                },
                onOpenManualMurb: {
                    showLocalMultiplayer = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showMurbManual = true }
                }
            )
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Enviar o save deste iPhone ao perfil ativo no PC?", isPresented: $confirmNativeUpload) {
            Button("Enviar save") {
                syncingNativeSave = true
                Task {
                    do { actionMessage = try await pocket.sendNativeSaveToPC(rom, launcher: store) }
                    catch { actionMessage = error.localizedDescription }
                    syncingNativeSave = false
                }
            }
        } message: {
            Text("O save local ainda não tem vínculo de perfil. Este envio associa os bytes ao perfil atualmente aberto no Launcher Beta. Nenhum save do PC será substituído automaticamente.")
        }
        .confirmationDialog("Receber o save do perfil ativo no PC?", isPresented: $confirmNativeDownload) {
            Button("Receber e aplicar save") {
                syncingNativeSave = true
                Task {
                    do { actionMessage = try await pocket.receiveNativeSaveFromPC(rom, launcher: store) }
                    catch { actionMessage = error.localizedDescription }
                    syncingNativeSave = false
                }
            }
        } message: {
            Text("Se houver progresso diferente no iPhone, o save atual será guardado para recuperação antes da aplicação do backup do PC. Feche o jogo antes de continuar.")
        }
    }

    private var localAchievementMessage: String {
        if pocket.credentials == nil { return "Conecte sua conta nas configurações do Gaming Mode." }
        if Int(record?.retroAchievementID ?? "") == nil { return "Vincule este jogo ao RetroAchievements para consultar o progresso." }
        if progress != nil { return "O RetroAchievements não retornou conquistas para este título." }
        return "O progresso aparece após sincronizar o jogo vinculado."
    }

    private var executionScopeSummary: String {
        if installedCore != nil {
            return "No celular (offline): emulação, gamepad virtual/físico e saves locais. Depende do PC/rede: sincronizar save nativo, iniciar no computador e consultar RetroAchievements."
        }
        return "No celular: execução externa via RetroArch quando suportado. Depende do PC/rede: B-CARD no computador e sincronização."
    }

    private var routeDescription: String {
        let reason = IntegratedEmulatorSupport.availabilityReason(for: rom)
        if installedCore != nil { return reason }
        if system == .nintendo3DS { return "\(reason) A importação para o RetroArch não ativaria o BRUM Core." }
        if canUseRetroArch { return "\(reason) A opção abaixo usa explicitamente o RetroArch e não conta como suporte integrado." }
        return "\(reason) O arquivo original foi preservado."
    }

    private func launchGamepadFromROM() {
        startPCGamepadOrMultiplayer(players: 1, hybridMode: "mobile1-pc2", myPlayerNumber: 1)
    }

    private func startPCGamepadOrMultiplayer(players: Int, hybridMode: String, myPlayerNumber: Int) {
        guard store.connection == .online else {
            actionMessage = "Computador offline. Conecte o Launcher na mesma rede ou abra o Gamepad M.U.R.B manualmente."
            showMurbManual = true
            return
        }
        launchingGamepad = true
        actionMessage = "Iniciando \(rom.title) no computador e abrindo joystick virtual…"
        let resolvedGameID = linkedPCGame?.id ?? pocket.launcherGame(for: rom, launcher: store)?.id
        Task {
            let result = await store.launchGamepadOnPC(
                gameID: resolvedGameID,
                filename: rom.filename,
                title: rom.title,
                mode: "new",
                players: players,
                hybridMode: hybridMode
            )
            await MainActor.run {
                launchingGamepad = false
                switch result {
                case .success(let launch):
                    if let target = MurbRemoteLaunchTarget.from(launch.remoteGamepad, fallbackHost: store.configuration?.host, gameTitle: rom.title, playerNumber: myPlayerNumber) {
                        MurbRemoteStore().remember(target.payload)
                        actionMessage = launch.message ?? "Jogo aberto no PC. Joystick virtual conectado."
                        activeMurbTarget = target
                    } else {
                        actionMessage = (launch.message ?? "Jogo iniciado no computador.") + " Conecte o Gamepad M.U.R.B pela tela seguinte."
                        showMurbManual = true
                    }
                case .failure(let error):
                    actionMessage = error.localizedDescription
                }
            }
        }
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
    let initialGame: Game
    private var game: Game { store.snapshot.games.first { $0.id == initialGame.id } ?? initialGame }
    init(game: Game) { initialGame = game }
    private var hasAchievementTotals: Bool { game.achievementsAvailable || game.allowsManualAchievements }
    private var achievementSource: String {
        if game.allowsManualAchievements { return game.achievementCatalogLabel }
        if game.isClassic, game.achievementsAvailable { return "RetroAchievements" }
        return game.platform
    }

    @State private var launchState = ""
    @State private var launching = false
    @State private var launchingGamepad = false
    @State private var openingClient = false
    @State private var showMurbRemote = false
    @State private var showLocalMultiplayer = false
    @State private var activeMurbTarget: MurbRemoteLaunchTarget?

    private var streaming: StreamingStatus? { store.snapshot.experience?.streaming }

    var body: some View {
        VStack(spacing: 0) {
            GamingHeader {
                Button { dismiss() } label: { Label("Biblioteca", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GamingHero(title: game.title, platform: game.platform, artwork: GamingArtwork(game: game)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ExecutionBadge(kind: game.installed ? .dependsOnPC : .unavailable)
                            GamingMetrics(time: game.playtimeLabel, timeLabel: "Tempo jogado",
                                          earned: hasAchievementTotals ? game.achievementsCollected : nil,
                                          total: hasAchievementTotals ? game.achievementsTotal : nil)
                        }
                    }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Plataforma", value: game.platform),
                        GamingInfoItem(label: "Gênero", value: game.genre),
                        GamingInfoItem(label: "Origem", value: game.store),
                        GamingInfoItem(label: "Status", value: game.statusLabel),
                        GamingInfoItem(label: "Tamanho", value: game.sizeBytes > 0 ? ByteCountFormatter.string(fromByteCount: game.sizeBytes, countStyle: .file) : ""),
                        GamingInfoItem(label: "Execução", value: "Depende do PC (B-CARD / Streaming / M.U.R.B)")
                    ])
                    GamingActionBar(
                        canPlay: canStartOnPC,
                        playTitle: "JOGAR",
                        playSubtitle: streaming?.available == true ? "Streaming no celular" : "Iniciar no PC",
                        gamepadBusy: launchingGamepad,
                        pcOnline: canStartOnPC,
                        onPlay: {
                            if streaming?.available == true { playStream() } else { playOnPC() }
                        },
                        onGamepad: { startPCGamepad(players: 1, hybridMode: "mobile1-pc2", myPlayerNumber: 1) },
                        onLocalMultiplayer: { showLocalMultiplayer = true }
                    )
                    if streaming?.available == true {
                        Button(action: playOnPC) { Text("SOMENTE INICIAR NO COMPUTADOR").font(.caption.bold()).frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.bordered).tint(BrumTheme.primary).disabled(!canStartOnPC || launching).opacity(canStartOnPC ? 1 : 0.38)
                    }
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    GamingAchievements(title: achievementSource, items: game.achievements,
                                       earned: hasAchievementTotals ? game.achievementsCollected : nil,
                                       total: hasAchievementTotals ? game.achievementsTotal : nil,
                                       emptyMessage: "As conquistas aparecem quando o launcher disponibiliza o progresso deste título.")
                    if !game.description.isEmpty {
                        Text(game.description).font(.body).foregroundStyle(.secondary)
                    }
                    BrumCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { BrumSectionLabel(text: "STREAMING"); Spacer(); Text(streaming?.available == true ? "PRONTO" : "AÇÃO NECESSÁRIA").font(.caption2.bold()).foregroundStyle(streaming?.available == true ? BrumTheme.primary : .orange) }
                            Text(streamingDescription).font(.caption).foregroundStyle(BrumTheme.muted)
                            if streaming?.network.remoteReady == true { Label("Acesso remoto protegido disponível", systemImage: "checkmark.shield.fill").font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
                        }
                    }
                }.frame(maxWidth: 1000, alignment: .leading).padding(20).frame(maxWidth: .infinity)
            }
        }.background(BrumTheme.background.ignoresSafeArea())
        .onAppear { GamingOrientation.request(.landscape) }
        .sheet(isPresented: $showMurbRemote) {
            MurbRemoteGamepadLauncherSheet()
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $activeMurbTarget) { target in
            MurbRemoteGamepadView(target: target.payload, gameTitle: target.gameTitle, playerNumber: target.playerNumber, p2Payload: target.p2Payload)
        }
        .sheet(isPresented: $showLocalMultiplayer) {
            LocalMultiplayerSheet(
                gameTitle: game.title,
                pcAvailable: canStartOnPC,
                phoneCoopAvailable: false,
                onStartPhoneCoop: { _ in },
                onStartPCLanMultiplayer: { hybridMode, myPlayerNumber in
                    showLocalMultiplayer = false
                    startPCGamepad(players: 2, hybridMode: hybridMode, myPlayerNumber: myPlayerNumber)
                },
                onOpenManualMurb: {
                    showLocalMultiplayer = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showMurbRemote = true }
                }
            )
            .preferredColorScheme(.dark)
        }
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

    private func startPCGamepad(players: Int, hybridMode: String, myPlayerNumber: Int) {
        guard canStartOnPC else {
            launchState = "Computador offline ou jogo não confirmado."
            showMurbRemote = true
            return
        }
        launchingGamepad = true
        launchState = "Abrindo \(game.title) no computador e preparando o joystick virtual…"
        Task {
            let result = await store.launchGamepadOnPC(
                gameID: game.id,
                filename: nil,
                title: game.title,
                mode: "new",
                players: players,
                hybridMode: hybridMode
            )
            await MainActor.run {
                launchingGamepad = false
                switch result {
                case .success(let launch):
                    if let target = MurbRemoteLaunchTarget.from(launch.remoteGamepad, fallbackHost: store.configuration?.host, gameTitle: game.title, playerNumber: myPlayerNumber) {
                        MurbRemoteStore().remember(target.payload)
                        launchState = launch.message ?? "Jogo aberto no computador; joystick virtual ativo."
                        activeMurbTarget = target
                    } else {
                        launchState = launch.message ?? "Jogo aberto no computador. Conecte o Gamepad manualmente."
                        showMurbRemote = true
                    }
                case .failure(let error):
                    launchState = "Não foi possível abrir o modo Gamepad: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct GamingActionBar: View {
    let canPlay: Bool
    let playTitle: String
    let playSubtitle: String
    let gamepadBusy: Bool
    let pcOnline: Bool
    let onPlay: () -> Void
    let onGamepad: () -> Void
    let onLocalMultiplayer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onPlay) {
                    VStack(spacing: 2) {
                        Label(playTitle, systemImage: "play.fill").font(.subheadline.bold())
                        Text(playSubtitle).font(.caption2).opacity(0.82).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canPlay)
                .opacity(canPlay ? 1 : 0.42)
                .accessibilityIdentifier("gaming-action-play")

                Button(action: onGamepad) {
                    VStack(spacing: 2) {
                        if gamepadBusy {
                            ProgressView().tint(BrumTheme.primary)
                        } else {
                            Label("GAMEPAD", systemImage: "gamecontroller.fill").font(.subheadline.bold())
                        }
                        Text(pcOnline ? "Abre no PC + Celular" : "Requer PC · LAN").font(.caption2).opacity(0.82).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered).tint(BrumTheme.primary)
                .disabled(gamepadBusy)
                .accessibilityIdentifier("gaming-action-gamepad")

                Button(action: onLocalMultiplayer) {
                    VStack(spacing: 2) {
                        Label("MULTIJOGADOR LOCAL", systemImage: "person.2.fill").font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.75)
                        Text("2 a 4 jogadores").font(.caption2).opacity(0.82).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered).tint(BrumTheme.text)
                .accessibilityIdentifier("gaming-action-multiplayer")
            }
        }
    }
}

private struct LocalMultiplayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gameTitle: String
    let pcAvailable: Bool
    let phoneCoopAvailable: Bool
    let onStartPhoneCoop: (Int) -> Void
    let onStartPCLanMultiplayer: (String, Int) -> Void
    let onOpenManualMurb: () -> Void
    @State private var controllers: [GCController] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Multijogador Local no Computador (LAN)") {
                    Button {
                        onStartPCLanMultiplayer("pc1-mobile2", 2)
                    } label: {
                        Label("PC (Jogador 1) + Este celular (Jogador 2)", systemImage: "laptopcomputer.and.iphone")
                    }
                    .disabled(!pcAvailable)

                    Button {
                        onStartPCLanMultiplayer("mobile1-pc2", 1)
                    } label: {
                        Label("Este celular (Jogador 1) + PC (Jogador 2)", systemImage: "iphone.and.arrow.forward")
                    }
                    .disabled(!pcAvailable)

                    Button {
                        onStartPCLanMultiplayer("dual-mobile", 1)
                    } label: {
                        Label("2 celulares no Wi-Fi (P1 e P2 · QR para 2º celular)", systemImage: "person.2.wave.2.fill")
                    }
                    .disabled(!pcAvailable)

                    if !pcAvailable {
                        Button("Abrir Gamepad M.U.R.B manualmente") { onOpenManualMurb() }
                    }
                    Text("Ao iniciar no PC em rede local, este celular abre automaticamente o joystick virtual conectado no jogador escolhido.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if phoneCoopAvailable {
                    Section("Multijogador Local neste iPhone (Offline)") {
                        Text(controllers.isEmpty
                             ? "Conecte controles Bluetooth/USB no iPhone ou use 1 controle como P1 e este celular na tela como P2."
                             : "\(controllers.count) controle(s) físico(s) detectado(s) para P1–P4.")
                            .font(.caption).foregroundStyle(.secondary)

                        Button {
                            onStartPhoneCoop(0)
                        } label: {
                            Label("Iniciar com controles conectados (Virtual = P1)", systemImage: "gamecontroller.fill")
                        }

                        Button {
                            onStartPhoneCoop(1)
                        } label: {
                            Label("Controle Bluetooth = P1 · Tela do celular = P2", systemImage: "hand.tap.fill")
                        }
                    }
                }
            }
            .navigationTitle("Multijogador · \(gameTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
            .onAppear { controllers = GCController.controllers().filter { !$0.isSnapshot } }
        }
    }
}
