import GameController
import SwiftUI
import UIKit

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Binding var selection: Int
    @State private var selectedGame: Game?
    @State private var selectedROM: ROMFolderGame?
    @State private var selectedDriveItem: ClassicDriveGameItem?
    @State private var quickRemoteTarget: MurbRemoteLaunchTarget?
    private enum GamingSection: String { case recent, library, extensions }
    @State private var activeSection: GamingSection = .recent
    @AppStorage("gaming-mode-favorites-v1") private var favoritesJSON = "[]"

    @State private var catalogSnapshot = GamingCatalogSnapshot.empty
    @State private var driveItems: [ClassicDriveGameItem] = []
    @State private var downloadingDriveIDs: Set<String> = []
    @State private var driveProgressByID: [String: Double] = [:]
    @State private var driveActionError = ""
    @State private var searchQuery = ""
    @State private var selectedConsole = "all"
    private let columns = [GridItem(.adaptive(minimum: 135), spacing: 16)]
    private var favoriteIDs: Set<String> {
        guard let data = favoritesJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }
    private func isFavorite(_ entry: GamingCatalogEntry) -> Bool {
        if favoriteIDs.contains(entry.id) { return true }
        if let cid = catalogSnapshot.canonicalIDByEntryID[entry.id],
           favoriteIDs.contains("canon:\(cid)") || favoriteIDs.contains(cid) {
            return true
        }
        return false
    }
    private var catalogFingerprint: String {
        let romPart = pocket.romFolderGames.map { "\($0.id)" }.joined(separator: ",")
        let recPart = pocket.games.map { "\($0.filename):\($0.launcherGameID):\($0.lastPlayedAt?.timeIntervalSince1970 ?? 0)" }.joined(separator: ",")
        let pcPart = GamingModeCatalog.computerFingerprint(store.snapshot.games)
        let drivePart = driveItems.map { "\($0.id):\($0.downloadStatus):\($0.downloadedLocalPath ?? "")" }.joined(separator: ",")
        return "\(romPart)|\(recPart)|\(pcPart)|\(drivePart)|\(favoritesJSON)"
    }
    private var libraryEntries: [GamingCatalogEntry] { catalogSnapshot.library }
    private var recentEntries: [GamingCatalogEntry] { catalogSnapshot.recent }
    private var activeBaseEntries: [GamingCatalogEntry] {
        (activeSection == .library || recentEntries.isEmpty) ? libraryEntries : recentEntries
    }
    private var consoleOptions: [GamingModeCatalog.GamingConsoleOption] {
        GamingModeCatalog.availableConsoles(in: activeBaseEntries)
    }
    private var filteredEntries: [GamingCatalogEntry] {
        GamingModeCatalog.filter(activeBaseEntries, query: searchQuery, consoleKey: selectedConsole)
    }
    private var hasActiveFilters: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedConsole != "all"
    }

    private func refreshCatalog() {
        catalogSnapshot = GamingModeCatalog.buildSnapshot(
            local: pocket.romFolderGames,
            records: pocket.games,
            computer: store.snapshot.games,
            cloud: driveItems,
            favorites: favoriteIDs
        )
        let validKeys = Set(consoleOptions.map(\.id))
        if selectedConsole != "all" && !validKeys.contains(selectedConsole) {
            selectedConsole = "all"
        }
    }

    private func reloadDriveItems() async {
        let checkpoint = await ClassicDriveCloudService.shared.currentCheckpoint()
        await MainActor.run {
            driveItems = checkpoint.items
            refreshCatalog()
        }
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
                        libraryTab("JOGADOS RECENTEMENTE", selected: activeSection == .recent) { activeSection = .recent }
                            .accessibilityIdentifier("gaming-mode-recent")
                        libraryTab("BIBLIOTECA", selected: activeSection == .library) { activeSection = .library }
                            .accessibilityIdentifier("gaming-mode-library")
                        libraryTab("EXTENSÕES", selected: activeSection == .extensions) { activeSection = .extensions }
                            .accessibilityIdentifier("gaming-mode-extensions")
                    }
                    if let activeRemote = store.activeRemoteGamepadSession {
                        BrumCard {
                            HStack(spacing: 12) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.title3)
                                    .foregroundStyle(BrumTheme.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sessão ativa no PC pareado (P\(activeRemote.playerNumber))")
                                        .font(.caption.bold())
                                        .foregroundStyle(BrumTheme.primary)
                                    Text(activeRemote.gameTitle.isEmpty ? "Jogo em execução no computador" : activeRemote.gameTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BrumTheme.text)
                                }
                                Spacer()
                                Button("CONECTAR GAMEPAD") {
                                    quickRemoteTarget = activeRemote
                                }.buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                    if activeSection == .extensions {
                        PokedexGamingExtensionView()
                    } else if activeBaseEntries.isEmpty {
                        BrumCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nenhum jogo pronto").font(.headline).foregroundStyle(BrumTheme.text)
                                Text("Toque na engrenagem acima para selecionar uma pasta de ROMs ou instale um jogo no computador.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        gamingSearchAndFilterBar
                        if !driveActionError.isEmpty {
                            Text(driveActionError).font(.caption).foregroundStyle(.orange)
                        }
                        if let featured = filteredEntries.first {
                            let driveOption = featuredDriveItem(for: featured)
                            GamingHero(title: featured.title, platform: platform(for: featured), artwork: artwork(for: featured)) {
                                HStack(spacing: 10) {
                                    Button("VER DETALHES") { open(featured) }
                                        .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 180)
                                    if let driveOption {
                                        let busy = downloadingDriveIDs.contains(driveOption.id)
                                        Button {
                                            startOrCancelDriveDownload(driveOption)
                                        } label: {
                                            Label(busy ? "BAIXANDO…" : "BAIXAR", systemImage: busy ? "xmark.circle.fill" : "arrow.down.circle.fill")
                                                .font(.caption.bold())
                                                .padding(.horizontal, 14)
                                                .frame(minHeight: 44)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(busy ? .orange : .cyan)
                                        .foregroundStyle(.black)
                                        .accessibilityIdentifier("gaming-hero-drive-download")
                                    }
                                }
                            }
                            let title = (activeSection == .library || recentEntries.isEmpty) ? "Biblioteca" : "Jogos recentes e favoritos"
                            gameSection(title: title) { ForEach(filteredEntries) { entryTile($0) } }
                        } else {
                            BrumCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Nenhum jogo encontrado").font(.headline).foregroundStyle(BrumTheme.text)
                                    Text("Nenhum clássico corresponde à pesquisa ou ao console selecionado.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    if hasActiveFilters {
                                        Button("Limpar pesquisa e filtros") {
                                            searchQuery = ""
                                            selectedConsole = "all"
                                        }
                                        .buttonStyle(PrimaryButtonStyle())
                                        .frame(maxWidth: 240)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }.padding(20).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
            }
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshCatalog()
        }
        .task {
            GamingOrientation.request(.landscape)
            await pocket.refreshROMFolder()
            await reloadDriveItems()
            refreshCatalog()
        }
        .task(id: catalogFingerprint) {
            refreshCatalog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .classicDriveCatalogDidChange)) { _ in
            Task { await reloadDriveItems() }
        }
        .fullScreenCover(item: $selectedGame) { game in
            GamingGameView(game: game, driveItem: catalogSnapshot.matchedDriveByPCID[game.id])
                .environment(\.gamingCatalogSnapshot, catalogSnapshot)
        }
        .fullScreenCover(item: $selectedROM) {
            GamingROMDetailView(rom: $0)
                .environment(\.gamingCatalogSnapshot, catalogSnapshot)
        }
        .fullScreenCover(item: $selectedDriveItem) { item in
            GamingDriveDetailView(item: item, matchedPC: catalogSnapshot.matchedPCByDriveID[item.id])
                .environment(\.gamingCatalogSnapshot, catalogSnapshot)
        }
        .fullScreenCover(item: $quickRemoteTarget) { target in
            MurbRemoteGamepadView(target: target.payload, gameTitle: target.gameTitle, playerNumber: target.playerNumber, p2Payload: target.p2Payload)
        }
    }

    @ViewBuilder
    private var gamingSearchAndFilterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Pesquisar jogos clássicos…", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundStyle(BrumTheme.text)
                        .accessibilityIdentifier("gaming-mode-search-field")
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Limpar pesquisa")
                        .accessibilityIdentifier("gaming-mode-search-clear")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 42)
                .background(BrumTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

                if hasActiveFilters {
                    Button("Limpar filtros") {
                        searchQuery = ""
                        selectedConsole = "all"
                    }
                    .font(.caption.bold())
                    .foregroundStyle(BrumTheme.primary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(BrumTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("gaming-mode-clear-filters")
                }
            }

            if consoleOptions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(consoleOptions) { option in
                            let selected = selectedConsole == option.id
                            Button {
                                selectedConsole = option.id
                            } label: {
                                Text(option.id == "all" ? option.label : "\(option.label) (\(option.count))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selected ? Color.black : BrumTheme.text)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 34)
                                    .background(selected ? BrumTheme.primary : BrumTheme.surface, in: Capsule())
                                    .overlay(Capsule().stroke(selected ? BrumTheme.primary : Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("gaming-mode-console-\(option.id)")
                        }
                    }
                }
            }
        }
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
        case .computer(let game):
            guard let current = store.snapshot.games.first(where: { $0.id == game.id && GamingModeCatalog.isEligibleComputerClassic($0) }) else { return }
            selectedGame = current
        case .cloud(let item):
            selectedDriveItem = item
        }
    }

    private func platform(for entry: GamingCatalogEntry) -> String {
        switch entry {
        case .local(let rom, _): return IntegratedEmulatorSupport.system(for: rom)?.rawValue.uppercased() ?? "CLASSICS"
        case .computer(let game): return game.platform
        case .cloud(let item): return item.systemHint.isEmpty ? "DRIVE" : item.systemHint.uppercased()
        }
    }

    private func matchedComputerGame(for rom: ROMFolderGame) -> Game? {
        catalogSnapshot.matchedByROMID[rom.id]
            ?? pocket.launcherGame(for: rom, launcher: store)
    }

    private func artwork(for entry: GamingCatalogEntry) -> GamingArtwork {
        switch entry {
        case .local(let rom, _):
            return GamingArtwork(game: matchedComputerGame(for: rom), rom: rom)
        case .computer(let game): return GamingArtwork(game: game)
        case .cloud(let item):
            return GamingArtwork(game: catalogSnapshot.matchedPCByDriveID[item.id], rom: nil)
        }
    }

    private func featuredDriveItem(for entry: GamingCatalogEntry) -> ClassicDriveGameItem? {
        switch entry {
        case .local: return nil
        case .computer(let game): return catalogSnapshot.matchedDriveByPCID[game.id]
        case .cloud(let item): return item
        }
    }

    private func startOrCancelDriveDownload(_ item: ClassicDriveGameItem) {
        if downloadingDriveIDs.contains(item.id) {
            Task {
                await ClassicDriveCloudService.shared.cancelDownload(fileID: item.id)
                await MainActor.run {
                    downloadingDriveIDs.remove(item.id)
                    driveProgressByID.removeValue(forKey: item.id)
                }
                await reloadDriveItems()
            }
            return
        }
        driveActionError = ""
        downloadingDriveIDs.insert(item.id)
        driveProgressByID[item.id] = 0
        Task {
            do {
                _ = try await ClassicDriveCloudService.shared.downloadGame(fileID: item.id) { received, total in
                    guard let total, total > 0 else { return }
                    let pct = min(1, max(0, Double(received) / Double(total)))
                    Task { @MainActor in
                        driveProgressByID[item.id] = pct
                    }
                }
                await pocket.refreshROMFolder()
                await reloadDriveItems()
                await MainActor.run {
                    downloadingDriveIDs.remove(item.id)
                    driveProgressByID.removeValue(forKey: item.id)
                }
            } catch {
                await MainActor.run {
                    downloadingDriveIDs.remove(item.id)
                    driveProgressByID.removeValue(forKey: item.id)
                    if !(error is CancellationError) {
                        driveActionError = "Falha ao baixar \(item.title): \(error.localizedDescription)"
                    }
                }
                await reloadDriveItems()
            }
        }
    }

    private func gameSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BrumSectionLabel(text: title)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20, content: content)
        }
    }

    @ViewBuilder private func entryTile(_ entry: GamingCatalogEntry) -> some View {
        let fav = isFavorite(entry)
        ZStack(alignment: .topTrailing) {
            switch entry {
            case .local(let rom, _):
                let matched = matchedComputerGame(for: rom)
                let playable = IntegratedEmulatorSupport.supports(rom)
                    || GamingModeCatalog.canOfferRetroArch(for: rom, imported: pocket.isImportedIntoRetroArch(rom))
                ROMFolderGameTile(
                    rom: rom,
                    launcherGame: matched,
                    retroArchReady: pocket.isImportedIntoRetroArch(rom),
                    integratedCoreName: IntegratedEmulatorSupport.core(for: rom)?.displayName,
                    platformLabel: platform(for: entry),
                    isPlayableOnPhone: playable,
                    opensDetails: true
                ) { selectedROM = rom }
            case .computer(let game):
                GamingGameTile(
                    game: game,
                    driveItem: catalogSnapshot.matchedDriveByPCID[game.id],
                    isDownloading: catalogSnapshot.matchedDriveByPCID[game.id].map { downloadingDriveIDs.contains($0.id) } ?? false,
                    openDetails: { open(entry) },
                    onDownload: {
                        if let driveItem = catalogSnapshot.matchedDriveByPCID[game.id] {
                            startOrCancelDriveDownload(driveItem)
                        }
                    }
                )
            case .cloud(let item):
                GamingDriveTile(
                    item: item,
                    matchedPC: catalogSnapshot.matchedPCByDriveID[item.id],
                    platformLabel: platform(for: entry),
                    isDownloading: downloadingDriveIDs.contains(item.id) || item.downloadStatus == "downloading",
                    progress: driveProgressByID[item.id],
                    openDetails: { selectedDriveItem = item },
                    onDownload: { startOrCancelDriveDownload(item) }
                )
            }
            Button { toggleFavorite(entry) } label: {
                Image(systemName: fav ? "star.fill" : "star")
                    .font(.headline).foregroundStyle(BrumTheme.primary)
                    .padding(9).background(BrumTheme.surface).clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fav ? "Remover \(entry.title) dos favoritos" : "Favoritar \(entry.title)")
        }
    }

    private func toggleFavorite(_ entry: GamingCatalogEntry) {
        var next = favoriteIDs
        let canonicalKey = catalogSnapshot.canonicalIDByEntryID[entry.id].map { "canon:\($0)" }
        let currentlyFavorite = isFavorite(entry)
        if currentlyFavorite {
            next.remove(entry.id)
            if let canonicalKey { next.remove(canonicalKey) }
            if let cid = catalogSnapshot.canonicalIDByEntryID[entry.id] { next.remove(cid) }
            if let sources = catalogSnapshot.sourcesByEntryID[entry.id] {
                for id in sources.allEntryIDs { next.remove(id) }
            }
        } else {
            next.insert(canonicalKey ?? entry.id)
        }
        guard let data = try? JSONEncoder().encode(next.sorted()), let text = String(data: data, encoding: .utf8) else { return }
        favoritesJSON = text
    }
}

enum GamingCatalogEntry: Identifiable {
    case local(ROMFolderGame, Date?)
    case computer(Game)
    case cloud(ClassicDriveGameItem)

    var id: String {
        switch self {
        case .local(let rom, _): return "local:\(rom.id)"
        case .computer(let game): return "pc:\(game.id)"
        case .cloud(let item): return "drive:\(item.id)"
        }
    }
    var title: String {
        switch self {
        case .local(let rom, _): return rom.title
        case .computer(let game): return game.title
        case .cloud(let item): return item.title
        }
    }
    var lastPlayedAt: Date? {
        switch self {
        case .local(_, let date): return date
        case .computer(let game): return GamingModeCatalog.date(game.lastPlayedAt)
        case .cloud: return nil
        }
    }
}

enum GamingSourceKind: String, Equatable, Hashable, Sendable {
    case local
    case computer
    case cloud
}

struct GamingGameVariant: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let source: GamingSourceKind
    let filename: String
    let label: String
    let discNumber: Int?
    let region: String?
    let revision: String?
    let serial: String?
    let romHash: String?
}

struct GamingGameDescriptor: Equatable, Sendable {
    let consoleKey: String
    let canonicalTitle: String
    let serial: String?
    let discNumber: Int?
    let region: String?
    let revision: String?
    let romHash: String?

    var canonicalID: String {
        let consolePart = consoleKey.isEmpty ? "unidentified" : consoleKey
        return "\(consolePart)|\(canonicalTitle)"
    }
}

struct GamingUnifiedSources: Equatable {
    let canonicalID: String
    let consoleKey: String
    let localROMs: [ROMFolderGame]
    let computerGame: Game?
    let driveItems: [ClassicDriveGameItem]
    let variants: [GamingGameVariant]

    var primaryROM: ROMFolderGame? { localROMs.first }
    var primaryDriveItem: ClassicDriveGameItem? { driveItems.first }
    var hasLocal: Bool { !localROMs.isEmpty }
    var hasComputer: Bool { computerGame != nil }
    var hasCloud: Bool { !driveItems.isEmpty }
    var isMultiDisc: Bool {
        let distinctDiscs = Set(variants.compactMap(\.discNumber))
        return distinctDiscs.count > 1 || localROMs.count > 1 || driveItems.count > 1
    }
    var allEntryIDs: [String] {
        var ids: [String] = []
        ids.append(contentsOf: localROMs.map { "local:\($0.id)" })
        if let pc = computerGame { ids.append("pc:\(pc.id)") }
        ids.append(contentsOf: driveItems.map { "drive:\($0.id)" })
        return ids
    }
}

struct GamingCatalogSnapshot {
    let library: [GamingCatalogEntry]
    let recent: [GamingCatalogEntry]
    let matchedByROMID: [ROMFolderGame.ID: Game]
    let matchedDriveByPCID: [Game.ID: ClassicDriveGameItem]
    let matchedPCByDriveID: [String: Game]
    let sourcesByEntryID: [String: GamingUnifiedSources]
    let canonicalIDByEntryID: [String: String]
    let allDriveItemsByPCID: [Game.ID: [ClassicDriveGameItem]]
    let allDriveItemsByROMID: [ROMFolderGame.ID: [ClassicDriveGameItem]]
    let allLocalROMsByROMID: [ROMFolderGame.ID: [ROMFolderGame]]

    init(
        library: [GamingCatalogEntry],
        recent: [GamingCatalogEntry],
        matchedByROMID: [ROMFolderGame.ID: Game],
        matchedDriveByPCID: [Game.ID: ClassicDriveGameItem],
        matchedPCByDriveID: [String: Game],
        sourcesByEntryID: [String: GamingUnifiedSources] = [:],
        canonicalIDByEntryID: [String: String] = [:],
        allDriveItemsByPCID: [Game.ID: [ClassicDriveGameItem]] = [:],
        allDriveItemsByROMID: [ROMFolderGame.ID: [ClassicDriveGameItem]] = [:],
        allLocalROMsByROMID: [ROMFolderGame.ID: [ROMFolderGame]] = [:]
    ) {
        self.library = library
        self.recent = recent
        self.matchedByROMID = matchedByROMID
        self.matchedDriveByPCID = matchedDriveByPCID
        self.matchedPCByDriveID = matchedPCByDriveID
        self.sourcesByEntryID = sourcesByEntryID
        self.canonicalIDByEntryID = canonicalIDByEntryID
        self.allDriveItemsByPCID = allDriveItemsByPCID
        self.allDriveItemsByROMID = allDriveItemsByROMID
        self.allLocalROMsByROMID = allLocalROMsByROMID
    }

    static let empty = GamingCatalogSnapshot(
        library: [],
        recent: [],
        matchedByROMID: [:],
        matchedDriveByPCID: [:],
        matchedPCByDriveID: [:]
    )
}

private struct GamingCatalogSnapshotKey: EnvironmentKey {
    static let defaultValue = GamingCatalogSnapshot.empty
}

extension EnvironmentValues {
    var gamingCatalogSnapshot: GamingCatalogSnapshot {
        get { self[GamingCatalogSnapshotKey.self] }
        set { self[GamingCatalogSnapshotKey.self] = newValue }
    }
}

enum GamingModePresentation {
    static let localAvailabilityLabel = "Disponível"
    static let computerAvailabilityLabel = "No computador"
    static let cloudAvailabilityLabel = "Na nuvem"
    static let downloadingAvailabilityLabel = "Baixando…"
    static let unavailableOnPhoneLabel = "Indisponível neste aparelho"
}

enum GamingModeCatalog {
    private static let nonClassicPlatforms: Set<String> = [
        "pc", "windows", "win", "win32", "win64", "steam", "epic", "epic games",
        "gog", "ea", "ea app", "origin", "ubisoft", "ubisoft connect",
        "battlenet", "battle.net", "amazon", "amazon games", "microsoft store",
        "xbox app", "xbox", "xbox one", "xbox series", "xbox series x",
        "xbox series s", "ps4", "ps5", "playstation 4", "playstation 5",
        "switch", "nintendo switch"
    ]

    private static let genericPlatformTokens: Set<String> = [
        "", "unknown", "unidentified", "classic", "retro", "auto", "other", "outros"
    ]

    static func isNonClassicPlatform(_ platform: String) -> Bool {
        let lower = platform.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalized = normalizedPlatform(lower)
        return nonClassicPlatforms.contains(lower) || nonClassicPlatforms.contains(normalized)
    }

    static func isEligibleClassicCategory(_ game: Game) -> Bool {
        game.isClassic
            && !isNonClassicPlatform(game.platform)
            && !game.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasSuffix(".exe")
    }

    static func isEligibleComputerClassic(_ game: Game) -> Bool {
        game.installed && isEligibleClassicCategory(game)
    }

    static func computerFingerprint(_ games: [Game]) -> Int {
        var hasher = Hasher()
        for game in games {
            hasher.combine(game.id)
            hasher.combine(game.category)
            hasher.combine(game.title)
            hasher.combine(game.platform)
            hasher.combine(game.installed)
            hasher.combine(game.lastPlayedAt)
        }
        return hasher.finalize()
    }
    static func canOfferRetroArch(for rom: ROMFolderGame, imported: Bool) -> Bool {
        // A remembered import is not evidence that RetroArch can execute 3DS.
        if IntegratedEmulatorSupport.system(for: rom) == .nintendo3DS { return false }
        if IntegratedEmulatorSupport.system(for: rom) == .playStationPortable { return false }
        return RetroArchAppStoreLaunchRules.supports(filename: rom.filename) || imported
    }

    static func normalizedKey(_ value: String) -> String {
        RetroArchLibraryRules.normalizedTitle(ROMTitleRules.clean(value))
    }

    static func normalizedPlatform(_ value: String) -> String {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "gb", "game boy", "gameboy": return "gb"
        case "gbc", "game boy color", "gameboy color": return "gbc"
        case "gba", "game boy advance", "gameboy advance": return "gba"
        case "ds", "nds", "nintendo ds": return "nds"
        case "3ds", "n3ds", "nintendo 3ds": return "3ds"
        case "nes", "nintendo", "famicom", "nintendo entertainment system": return "nes"
        case "sfc", "snes", "super nintendo", "super famicom", "super nintendo entertainment system": return "sfc"
        case "n64", "nintendo 64": return "n64"
        case "gc", "gamecube", "nintendo gamecube": return "gamecube"
        case "wii", "nintendo wii": return "wii"
        case "wiiu", "wii u", "nintendo wii u": return "wiiu"
        case "psx", "ps1", "playstation", "playstation 1", "sony playstation": return "psx"
        case "ps2", "playstation 2", "sony playstation 2": return "ps2"
        case "psp", "ppsspp", "playstation portable", "sony psp": return "psp"
        case "md", "genesis", "mega drive", "megadrive", "sega genesis", "sega mega drive": return "md"
        case "sms", "master system", "sega master system": return "sms"
        case "gg", "game gear", "sega game gear": return "gg"
        case "segacd", "sega cd", "mega cd", "megacd": return "segacd"
        case "32x", "sega 32x": return "32x"
        case "saturn", "sega saturn": return "saturn"
        case "dreamcast", "sega dreamcast": return "dreamcast"
        case "pce", "pc engine", "turbografx-16", "turbografx 16": return "pce"
        case "neogeo", "neo geo", "neo-geo": return "neogeo"
        case "ws", "wonderswan": return "ws"
        case "wsc", "wonderswan color": return "wsc"
        case "a2600", "atari2600", "atari 2600": return "atari2600"
        case "arcade", "fbneo", "mame": return "arcade"
        default: return lower
        }
    }

    static func platformMatches(_ system: EmulatedSystemID?, pcPlatform: String) -> Bool {
        guard let system else { return false }
        let pcNorm = normalizedPlatform(pcPlatform)
        if pcNorm == system.rawValue { return true }
        if (system == .gameBoy || system == .gameBoyColor) && (pcNorm == "gb" || pcNorm == "gbc") { return true }
        if (system == .wonderSwan || system == .wonderSwanColor) && (pcNorm == "ws" || pcNorm == "wsc") { return true }
        return false
    }

    private static let serialRegex = try? NSRegularExpression(
        pattern: #"\b(SLUS|SCUS|SLES|SCES|SLPS|SLPM|SCPS|ULUS|ULES|UCUS|NPJH|NPUH|NPUG|NTR|TWL|CTR|AGB|CGB|DMG)[-_ ]?([A-Z0-9]{4,5})\b"#,
        options: [.caseInsensitive]
    )
    private static let discRegex = try? NSRegularExpression(
        pattern: #"(?:^|[\s(\[_-])(?:disc|disk|cd|gd)[-_.\s]*([1-9])(?:\b|[\s)\]_.-]|$)"#,
        options: [.caseInsensitive]
    )
    private static let sideRegex = try? NSRegularExpression(
        pattern: #"(?:^|[\s(\[_-])side[-_.\s]*([ab])(?:\b|[\s)\]_.-]|$)"#,
        options: [.caseInsensitive]
    )
    private static let bracketRegex = try? NSRegularExpression(
        pattern: #"\(([^)]+)\)|\[([^\]]+)\]"#
    )

    static func describe(
        title: String,
        filename: String = "",
        relativePath: String = "",
        platform: String = "",
        romHash: String? = nil
    ) -> GamingGameDescriptor {
        var resolvedConsole = normalizedPlatform(platform)
        if genericPlatformTokens.contains(resolvedConsole) {
            let hinted = ClassicDriveLinkParser.detectSystemHint(relativePath: relativePath, filename: filename)
            let normalizedHint = normalizedPlatform(hinted)
            resolvedConsole = genericPlatformTokens.contains(normalizedHint) ? "" : normalizedHint
        }

        let inspectionText = [title, filename, relativePath].filter { !$0.isEmpty }.joined(separator: " ")
        var serial: String? = nil
        if let serialRegex {
            let ns = inspectionText as NSString
            if let match = serialRegex.firstMatch(in: inspectionText, range: NSRange(location: 0, length: ns.length)),
               match.numberOfRanges >= 3 {
                let p = ns.substring(with: match.range(at: 1)).uppercased()
                let code = ns.substring(with: match.range(at: 2)).uppercased()
                serial = p + code
            }
        }

        let nameSurface = [filename, title].filter { !$0.isEmpty }.joined(separator: " ")
        var discNumber: Int? = nil
        if let discRegex {
            let ns = nameSurface as NSString
            if let match = discRegex.firstMatch(in: nameSurface, range: NSRange(location: 0, length: ns.length)),
               match.numberOfRanges >= 2,
               let num = Int(ns.substring(with: match.range(at: 1))) {
                discNumber = num
            }
        }
        if discNumber == nil, let sideRegex {
            let ns = nameSurface as NSString
            if let match = sideRegex.firstMatch(in: nameSurface, range: NSRange(location: 0, length: ns.length)),
               match.numberOfRanges >= 2 {
                let side = ns.substring(with: match.range(at: 1)).uppercased()
                discNumber = side == "A" ? 1 : (side == "B" ? 2 : nil)
            }
        }

        var region: String? = nil
        var revision: String? = nil
        if let bracketRegex {
            let ns = nameSurface as NSString
            for match in bracketRegex.matches(in: nameSurface, range: NSRange(location: 0, length: ns.length)) {
                let tokenRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                guard tokenRange.location != NSNotFound else { continue }
                let rawTag = ns.substring(with: tokenRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = rawTag.lowercased()
                if lower.hasPrefix("disc ") || lower.hasPrefix("disk ") || lower.hasPrefix("cd ") || lower.hasPrefix("side ") {
                    continue
                }
                if region == nil {
                    switch lower {
                    case "u", "usa": region = "USA"
                    case "e", "eur", "europe": region = "Europe"
                    case "j", "jpn", "japan": region = "Japan"
                    case "world": region = "World"
                    case "br", "brazil", "pt-br": region = "Brazil"
                    default:
                        if lower.contains("usa") || lower.contains("europe") || lower.contains("japan") || lower.contains("brazil") {
                            region = rawTag
                        }
                    }
                }
                if revision == nil,
                   lower.range(of: #"^(?:rev(?:\s+|ision\s*)?[a-z0-9]+|v\d+(?:\.\d+)*|dualshock\s+ver\.?|alt(?:\s*\d*)?|beta.*|proto.*)$"#, options: .regularExpression) != nil {
                    revision = rawTag
                }
            }
        }

        let rawTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title
            : filename
        var cleaned = rawTitle
            .replacingOccurrences(of: #"\.[a-z0-9]{2,5}$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^\s*\d{1,6}\s*(?:[-_.:]\s*)+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(?:SLUS|SCUS|SLES|SCES|SLPS|SLPM|SCPS|ULUS|ULES|UCUS|NPJH|NPUH|NPUG|NTR|TWL|CTR|AGB|CGB|DMG)[-_ ]?[A-Z0-9]{4,5}\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*(?:[-–:|]\s*)?\b(?:disc|disk|cd|gd)[-_.\s]*[1-9]\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*(?:[-–:|]\s*)?\bside[-_.\s]*[ab]\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bdualshock\s+ver(?:sion|\.)?\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\b(?:rev(?:ision)?\s*[a-z0-9]+|v\d+(?:\.\d+)+)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"(?:\s*-\s*|\s+)version\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"([a-zà-öø-ÿ])([A-Z])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
        cleaned = RetroArchLibraryRules.normalizedTitle(cleaned)
        if cleaned.isEmpty {
            cleaned = RetroArchLibraryRules.normalizedTitle(
                filename.replacingOccurrences(of: #"\.[a-z0-9]{2,5}$"#, with: "", options: [.regularExpression, .caseInsensitive])
            )
        }

        let cleanHash = romHash?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return GamingGameDescriptor(
            consoleKey: resolvedConsole,
            canonicalTitle: cleaned,
            serial: serial,
            discNumber: discNumber,
            region: region,
            revision: revision,
            romHash: (cleanHash?.isEmpty == false) ? cleanHash : nil
        )
    }

    private static let dateLock = NSLock()
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoFormatter = ISO8601DateFormatter()

    static func matchedComputerGame(for rom: ROMFolderGame, records: [PocketClassic], computer: [Game]) -> Game? {
        if let linked = records.first(where: { $0.filename.caseInsensitiveCompare(rom.filename) == .orderedSame && !$0.launcherGameID.isEmpty }),
           let exact = computer.first(where: { isEligibleClassicCategory($0) && $0.id == linked.launcherGameID }) {
            return exact
        }
        let system = IntegratedEmulatorSupport.system(for: rom)
        let titleDesc = describe(title: rom.title, filename: rom.filename, relativePath: rom.relativePath, platform: system?.rawValue ?? "")
        let fileKey = describe(title: rom.filename, filename: rom.filename, relativePath: rom.relativePath, platform: system?.rawValue ?? "").canonicalTitle
        let candidates = computer.filter { game in
            guard isEligibleClassicCategory(game) else { return false }
            let gDesc = describe(title: game.title, filename: "", relativePath: "", platform: game.platform)
            guard !gDesc.canonicalTitle.isEmpty else { return false }
            return gDesc.canonicalTitle == titleDesc.canonicalTitle || (!fileKey.isEmpty && gDesc.canonicalTitle == fileKey)
        }
        if candidates.isEmpty { return nil }
        let platformFiltered = candidates.filter { platformMatches(system, pcPlatform: $0.platform) }
        if !platformFiltered.isEmpty {
            return platformFiltered.first(where: \.installed) ?? platformFiltered.first
        }
        if system != nil {
            let genericOnly = candidates.filter { genericPlatformTokens.contains(normalizedPlatform($0.platform)) }
            return genericOnly.first(where: \.installed) ?? genericOnly.first
        }
        return candidates.first(where: \.installed) ?? candidates.first
    }

    private final class MutableUnifiedGroup {
        var consoleKey: String
        var canonicalTitle: String
        var serials: Set<String> = []
        var romHashes: Set<String> = []
        var explicitPCIDs: Set<String> = []
        var localROMs: [ROMFolderGame] = []
        var localFilenamesLower: Set<String> = []
        var dates: [Date] = []
        var computerGames: [Game] = []
        var computerGameIDs: Set<String> = []
        var driveItems: [ClassicDriveGameItem] = []
        var driveItemIDs: Set<String> = []
        var variants: [GamingGameVariant] = []

        init(consoleKey: String, canonicalTitle: String) {
            self.consoleKey = consoleKey
            self.canonicalTitle = canonicalTitle
        }

        var canonicalID: String {
            let c = consoleKey.isEmpty ? "unidentified" : consoleKey
            return "\(c)|\(canonicalTitle)"
        }

        func consolesCompatible(with otherConsole: String) -> Bool {
            consoleKey.isEmpty || otherConsole.isEmpty || consoleKey == otherConsole
        }
    }

    private static func variantLabel(for descriptor: GamingGameDescriptor, fallbackName: String, source: GamingSourceKind) -> String {
        var parts: [String] = []
        if let disc = descriptor.discNumber { parts.append("Disco \(disc)") }
        if let region = descriptor.region { parts.append(region) }
        if let revision = descriptor.revision { parts.append(revision) }
        if let serial = descriptor.serial { parts.append(serial) }
        if parts.isEmpty {
            switch source {
            case .local: return fallbackName.isEmpty ? "No aparelho" : fallbackName
            case .computer: return "Biblioteca PC"
            case .cloud: return fallbackName.isEmpty ? "Google Drive" : fallbackName
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func romPriorityRank(_ rom: ROMFolderGame) -> Int {
        switch (rom.filename as NSString).pathExtension.lowercased() {
        case "m3u": return 0
        case "cue": return 1
        case "chd": return 2
        case "pbp": return 3
        case "iso": return 4
        default: return 5
        }
    }

    static func buildSnapshot(
        local: [ROMFolderGame],
        records: [PocketClassic],
        computer: [Game],
        cloud: [ClassicDriveGameItem] = [],
        favorites: Set<String> = [],
        recentLimit: Int = 12
    ) -> GamingCatalogSnapshot {
        var recordsByFilename: [String: PocketClassic] = [:]
        recordsByFilename.reserveCapacity(records.count)
        for record in records {
            let key = record.filename.lowercased()
            if recordsByFilename[key] == nil {
                recordsByFilename[key] = record
            }
        }

        var computerByID: [String: Game] = [:]
        var pcDateByID: [String: Date] = [:]
        var allEligiblePC: [(game: Game, descriptor: GamingGameDescriptor)] = []
        computerByID.reserveCapacity(computer.count)
        allEligiblePC.reserveCapacity(computer.count)
        for game in computer {
            guard isEligibleClassicCategory(game) else { continue }
            computerByID[game.id] = game
            if let parsed = date(game.lastPlayedAt) {
                pcDateByID[game.id] = parsed
            }
            allEligiblePC.append((game, describe(title: game.title, platform: game.platform)))
        }

        var groups: [MutableUnifiedGroup] = []
        groups.reserveCapacity(local.count + computer.count + cloud.count)

        func addDescriptorKeys(_ d: GamingGameDescriptor, to group: MutableUnifiedGroup) {
            if group.consoleKey.isEmpty, !d.consoleKey.isEmpty {
                group.consoleKey = d.consoleKey
            }
            if group.canonicalTitle.isEmpty, !d.canonicalTitle.isEmpty {
                group.canonicalTitle = d.canonicalTitle
            }
            if let s = d.serial, !s.isEmpty { group.serials.insert(s) }
            if let h = d.romHash, !h.isEmpty { group.romHashes.insert(h) }
        }

        func findGroup(
            explicitPCID: String? = nil,
            filenameLower: String? = nil,
            descriptor d: GamingGameDescriptor
        ) -> MutableUnifiedGroup? {
            if let explicitPCID, !explicitPCID.isEmpty,
               let byExplicit = groups.first(where: { $0.explicitPCIDs.contains(explicitPCID) || $0.computerGameIDs.contains(explicitPCID) }),
               byExplicit.consolesCompatible(with: d.consoleKey) {
                return byExplicit
            }
            if let h = d.romHash, !h.isEmpty,
               let byHash = groups.first(where: { $0.romHashes.contains(h) && $0.consolesCompatible(with: d.consoleKey) }) {
                return byHash
            }
            if let s = d.serial, !s.isEmpty,
               let bySerial = groups.first(where: { $0.serials.contains(s) && $0.consolesCompatible(with: d.consoleKey) }) {
                return bySerial
            }
            if !d.consoleKey.isEmpty && !d.canonicalTitle.isEmpty {
                if let exact = groups.first(where: { $0.consoleKey == d.consoleKey && $0.canonicalTitle == d.canonicalTitle }) {
                    return exact
                }
            }
            if let filenameLower, !filenameLower.isEmpty {
                let exactFilenameMatches = groups.filter {
                    ($0.localFilenamesLower.contains(filenameLower) || $0.driveItems.contains { $0.name.lowercased() == filenameLower })
                        && $0.consolesCompatible(with: d.consoleKey)
                }
                if exactFilenameMatches.count == 1 {
                    return exactFilenameMatches[0]
                }
            }
            if !d.canonicalTitle.isEmpty {
                if d.consoleKey.isEmpty {
                    let sameTitle = groups.filter { $0.canonicalTitle == d.canonicalTitle }
                    if sameTitle.count == 1 {
                        return sameTitle[0]
                    }
                } else {
                    let unidentifiedMatches = groups.filter { $0.consoleKey.isEmpty && $0.canonicalTitle == d.canonicalTitle }
                    if unidentifiedMatches.count == 1 {
                        return unidentifiedMatches[0]
                    }
                }
            }
            return nil
        }

        // 1. Group local ROMs (collapses multi-disc sets and identical titles within the same console).
        for rom in local {
            let filenameLower = rom.filename.lowercased()
            let record = recordsByFilename[filenameLower]
            let explicitID = record?.launcherGameID
            let explicitPC = explicitID.flatMap { computerByID[$0] }
            let romSys = IntegratedEmulatorSupport.system(for: rom)?.rawValue ?? explicitPC?.platform ?? ""
            let d = describe(title: rom.title, filename: rom.filename, relativePath: rom.relativePath, platform: romSys)

            let group: MutableUnifiedGroup
            if let existing = findGroup(explicitPCID: explicitPC?.id, filenameLower: filenameLower, descriptor: d) {
                group = existing
            } else {
                group = MutableUnifiedGroup(consoleKey: d.consoleKey, canonicalTitle: d.canonicalTitle)
                groups.append(group)
            }

            addDescriptorKeys(d, to: group)
            if let explicitPC { group.explicitPCIDs.insert(explicitPC.id) }
            if !group.localROMs.contains(where: { $0.id == rom.id }) {
                group.localROMs.append(rom)
            }
            group.localFilenamesLower.insert(filenameLower)
            if let rDate = record?.lastPlayedAt { group.dates.append(rDate) }
            if let explicitPC, let pcDate = pcDateByID[explicitPC.id] { group.dates.append(pcDate) }
            group.variants.append(GamingGameVariant(
                id: "local:\(rom.id)",
                source: .local,
                filename: rom.filename,
                label: variantLabel(for: d, fallbackName: rom.filename, source: .local),
                discNumber: d.discNumber,
                region: d.region,
                revision: d.revision,
                serial: d.serial,
                romHash: d.romHash
            ))
        }

        // 2. Attach eligible installed computer games to existing groups or create PC groups.
        for game in computer where isEligibleComputerClassic(game) {
            let d = describe(title: game.title, platform: game.platform)
            let group: MutableUnifiedGroup
            if let existing = findGroup(explicitPCID: game.id, descriptor: d) {
                group = existing
            } else {
                group = MutableUnifiedGroup(consoleKey: d.consoleKey, canonicalTitle: d.canonicalTitle)
                groups.append(group)
            }

            addDescriptorKeys(d, to: group)
            if group.computerGameIDs.insert(game.id).inserted {
                group.computerGames.append(game)
            }
            if let pcDate = pcDateByID[game.id] { group.dates.append(pcDate) }
            group.variants.append(GamingGameVariant(
                id: "pc:\(game.id)",
                source: .computer,
                filename: game.title,
                label: variantLabel(for: d, fallbackName: game.platform, source: .computer),
                discNumber: d.discNumber,
                region: d.region,
                revision: d.revision,
                serial: d.serial,
                romHash: d.romHash
            ))
        }

        // 3. Attach Google Drive games (including multi-disc entries) to matching local/PC/Drive groups.
        var seenDriveIDs = Set<String>()
        for item in cloud where seenDriveIDs.insert(item.id).inserted {
            let pathForHint = item.relativePath.isEmpty ? item.parentRelativePath : item.relativePath
            let d = describe(title: item.title, filename: item.name, relativePath: pathForHint, platform: item.systemHint)
            let nameLower = (item.name as NSString).lastPathComponent.lowercased()
            let group: MutableUnifiedGroup
            if let existing = findGroup(filenameLower: nameLower, descriptor: d) {
                group = existing
            } else {
                group = MutableUnifiedGroup(consoleKey: d.consoleKey, canonicalTitle: d.canonicalTitle)
                groups.append(group)
            }

            addDescriptorKeys(d, to: group)
            if group.driveItemIDs.insert(item.id).inserted {
                group.driveItems.append(item)
            }
            group.variants.append(GamingGameVariant(
                id: "drive:\(item.id)",
                source: .cloud,
                filename: item.name,
                label: variantLabel(for: d, fallbackName: item.name, source: .cloud),
                discNumber: d.discNumber,
                region: d.region,
                revision: d.revision,
                serial: d.serial,
                romHash: d.romHash
            ))
        }

        // 4. Emit ONE unified GamingCatalogEntry per group (priority: Local > PC > Cloud).
        var entries: [GamingCatalogEntry] = []
        entries.reserveCapacity(groups.count)
        var matchedByROMID: [ROMFolderGame.ID: Game] = [:]
        var matchedDriveByPCID: [Game.ID: ClassicDriveGameItem] = [:]
        var matchedPCByDriveID: [String: Game] = [:]
        var sourcesByEntryID: [String: GamingUnifiedSources] = [:]
        var canonicalIDByEntryID: [String: String] = [:]
        var allDriveItemsByPCID: [Game.ID: [ClassicDriveGameItem]] = [:]
        var allDriveItemsByROMID: [ROMFolderGame.ID: [ClassicDriveGameItem]] = [:]
        var allLocalROMsByROMID: [ROMFolderGame.ID: [ROMFolderGame]] = [:]
        var candidateFavoriteIDsByEntryID: [String: Set<String>] = [:]

        for group in groups {
            let sortedROMs = group.localROMs.sorted { lhs, rhs in
                let dL = describe(title: lhs.title, filename: lhs.filename, relativePath: lhs.relativePath).discNumber ?? 99
                let dR = describe(title: rhs.title, filename: rhs.filename, relativePath: rhs.relativePath).discNumber ?? 99
                if dL != dR { return dL < dR }
                let rL = romPriorityRank(lhs)
                let rR = romPriorityRank(rhs)
                if rL != rR { return rL < rR }
                return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
            }
            let sortedDrive = group.driveItems.sorted { lhs, rhs in
                let dL = describe(title: lhs.title, filename: lhs.name, relativePath: lhs.relativePath, platform: lhs.systemHint).discNumber ?? 99
                let dR = describe(title: rhs.title, filename: rhs.name, relativePath: rhs.relativePath, platform: rhs.systemHint).discNumber ?? 99
                if dL != dR { return dL < dR }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            let primaryPC = group.computerGames.first
                ?? sortedROMs.first.flatMap { matchedComputerGame(for: $0, records: records, computer: computer) }
                ?? allEligiblePC.first(where: { cand in
                    !group.canonicalTitle.isEmpty
                        && cand.descriptor.canonicalTitle == group.canonicalTitle
                        && (group.consoleKey.isEmpty || cand.descriptor.consoleKey.isEmpty || cand.descriptor.consoleKey == group.consoleKey)
                })?.game

            let entry: GamingCatalogEntry
            if let primaryROM = sortedROMs.first {
                if let primaryPC {
                    matchedByROMID[primaryROM.id] = primaryPC
                }
                for rom in sortedROMs {
                    if let primaryPC, matchedByROMID[rom.id] == nil {
                        matchedByROMID[rom.id] = primaryPC
                    }
                    allLocalROMsByROMID[rom.id] = sortedROMs
                    if !sortedDrive.isEmpty {
                        allDriveItemsByROMID[rom.id] = sortedDrive
                    }
                }
                entry = .local(primaryROM, group.dates.max())
            } else if let primaryPC = group.computerGames.first {
                if let firstDrive = sortedDrive.first {
                    matchedDriveByPCID[primaryPC.id] = firstDrive
                }
                if !sortedDrive.isEmpty {
                    allDriveItemsByPCID[primaryPC.id] = sortedDrive
                }
                entry = .computer(primaryPC)
            } else if let primaryDrive = sortedDrive.first {
                if let primaryPC {
                    matchedPCByDriveID[primaryDrive.id] = primaryPC
                }
                entry = .cloud(primaryDrive)
            } else {
                continue
            }

            let unifiedSources = GamingUnifiedSources(
                canonicalID: group.canonicalID,
                consoleKey: group.consoleKey,
                localROMs: sortedROMs,
                computerGame: primaryPC,
                driveItems: sortedDrive,
                variants: group.variants
            )
            sourcesByEntryID[entry.id] = unifiedSources
            canonicalIDByEntryID[entry.id] = group.canonicalID

            var favCandidates = Set(unifiedSources.allEntryIDs)
            favCandidates.insert(entry.id)
            favCandidates.insert(group.canonicalID)
            favCandidates.insert("canon:\(group.canonicalID)")
            candidateFavoriteIDsByEntryID[entry.id] = favCandidates
            entries.append(entry)
        }

        let library = entries.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let recentEntries = recent(
            library,
            favorites: favorites,
            limit: recentLimit,
            pcDates: pcDateByID,
            candidateFavoriteIDsByEntryID: candidateFavoriteIDsByEntryID
        )
        return GamingCatalogSnapshot(
            library: library,
            recent: recentEntries,
            matchedByROMID: matchedByROMID,
            matchedDriveByPCID: matchedDriveByPCID,
            matchedPCByDriveID: matchedPCByDriveID,
            sourcesByEntryID: sourcesByEntryID,
            canonicalIDByEntryID: canonicalIDByEntryID,
            allDriveItemsByPCID: allDriveItemsByPCID,
            allDriveItemsByROMID: allDriveItemsByROMID,
            allLocalROMsByROMID: allLocalROMsByROMID
        )
    }

    static func library(local: [ROMFolderGame], records: [PocketClassic], computer: [Game]) -> [GamingCatalogEntry] {
        // Backing snapshot powers GamingModeCatalog.library while preserving linear O(N + M) indexing.
        buildSnapshot(local: local, records: records, computer: computer).library
    }

    static func recent(_ entries: [GamingCatalogEntry], favorites: Set<String>, limit: Int = 12) -> [GamingCatalogEntry] {
        recent(entries, favorites: favorites, limit: limit, pcDates: nil, candidateFavoriteIDsByEntryID: [:])
    }

    private static func recent(
        _ entries: [GamingCatalogEntry],
        favorites: Set<String>,
        limit: Int,
        pcDates: [String: Date]?,
        candidateFavoriteIDsByEntryID: [String: Set<String>] = [:]
    ) -> [GamingCatalogEntry] {
        let cap = max(0, limit)
        guard cap > 0 else { return [] }
        var pinned: [GamingCatalogEntry] = []
        var played: [(entry: GamingCatalogEntry, date: Date)] = []
        for entry in entries {
            let favKeys = candidateFavoriteIDsByEntryID[entry.id] ?? [entry.id]
            if !favorites.isDisjoint(with: favKeys) {
                pinned.append(entry)
                continue
            }
            let playedAt: Date?
            switch entry {
            case .local(_, let date):
                playedAt = date
            case .computer(let game):
                playedAt = pcDates?[game.id] ?? date(game.lastPlayedAt)
            case .cloud:
                playedAt = nil
            }
            if let playedAt {
                played.append((entry, playedAt))
            }
        }
        pinned.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if pinned.count >= cap {
            return Array(pinned.prefix(cap))
        }
        played.sort { $0.date > $1.date }
        var result = pinned
        result.reserveCapacity(min(cap, pinned.count + played.count))
        for item in played.prefix(cap - pinned.count) {
            result.append(item.entry)
        }
        return result
    }

    static func date(_ stamp: String) -> Date? {
        guard !stamp.isEmpty else { return nil }
        dateLock.lock()
        defer { dateLock.unlock() }
        return isoFractionalFormatter.date(from: stamp) ?? isoFormatter.date(from: stamp)
    }

    struct GamingConsoleOption: Identifiable, Equatable {
        let id: String
        let label: String
        let count: Int
    }

    static func normalizeSearch(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func consoleKey(for entry: GamingCatalogEntry) -> String {
        switch entry {
        case .local(let rom, _):
            guard let sys = IntegratedEmulatorSupport.system(for: rom) else { return "unidentified" }
            return sys.rawValue
        case .computer(let game):
            let key = normalizedPlatform(game.platform)
            if ["", "unknown", "unidentified", "classic", "retro", "auto", "other", "outros"].contains(key) {
                return "unidentified"
            }
            return key
        case .cloud(let item):
            let key = normalizedPlatform(item.systemHint)
            if key.isEmpty || ["unknown", "unidentified", "classic", "retro", "auto", "other", "outros"].contains(key) {
                return "unidentified"
            }
            return key
        }
    }

    static func consoleLabel(for key: String) -> String {
        switch key {
        case "all": return "Todos os consoles"
        case "unidentified": return "Não identificado"
        case "gb": return "Game Boy"
        case "gbc": return "Game Boy Color"
        case "gba": return "Game Boy Advance"
        case "nds", "ds": return "Nintendo DS"
        case "3ds": return "Nintendo 3DS"
        case "nes": return "NES"
        case "sfc", "snes": return "Super Nintendo"
        case "n64": return "Nintendo 64"
        case "gamecube": return "GameCube"
        case "wii": return "Nintendo Wii"
        case "wiiu": return "Wii U"
        case "psx", "ps1": return "PlayStation"
        case "ps2": return "PlayStation 2"
        case "psp": return "PSP"
        case "md": return "Mega Drive"
        case "sms": return "Master System"
        case "gg": return "Game Gear"
        case "segacd": return "Sega CD"
        case "32x": return "Sega 32X"
        case "saturn": return "Sega Saturn"
        case "dreamcast": return "Dreamcast"
        case "pce": return "PC Engine"
        case "neogeo": return "Neo Geo"
        case "ws": return "WonderSwan"
        case "wsc": return "WonderSwan Color"
        case "atari2600": return "Atari 2600"
        case "arcade": return "Arcade"
        default: return key.uppercased()
        }
    }

    static func availableConsoles(in entries: [GamingCatalogEntry]) -> [GamingConsoleOption] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[consoleKey(for: entry), default: 0] += 1
        }
        var sorted = counts
            .filter { $0.key != "unidentified" }
            .map { GamingConsoleOption(id: $0.key, label: consoleLabel(for: $0.key), count: $0.value) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        if let unidentifiedCount = counts["unidentified"] {
            sorted.append(GamingConsoleOption(id: "unidentified", label: consoleLabel(for: "unidentified"), count: unidentifiedCount))
        }
        return [GamingConsoleOption(id: "all", label: consoleLabel(for: "all"), count: entries.count)] + sorted
    }

    static func filter(_ entries: [GamingCatalogEntry], query: String, consoleKey selectedConsole: String) -> [GamingCatalogEntry] {
        let foldedQuery = normalizeSearch(query)
        let console = selectedConsole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            if !console.isEmpty && console != "all" && consoleKey(for: entry) != console {
                return false
            }
            if !foldedQuery.isEmpty {
                return normalizeSearch(entry.title).contains(foldedQuery)
            }
            return true
        }
    }
}

private struct GamingROMDetailView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.gamingCatalogSnapshot) private var catalogSnapshot
    @Environment(\.dismiss) private var dismiss
    let rom: ROMFolderGame
    @State private var selectedDiscROM: ROMFolderGame?
    @State private var downloadingDriveFileID: String?
    @State private var launchIntegrated = false
    @State private var launchIntegratedVirtualP2 = false
    @State private var launchingOnPC = false
    @State private var launchingGamepad = false
    @State private var showLocalMultiplayer = false
    @State private var showMurbManual = false
    @State private var activeMurbTarget: MurbRemoteLaunchTarget?
    @State private var syncingNativeSave = false
    @State private var showSaveConflictDialog = false
    @State private var saveConflictDetail = ""
    @State private var actionMessage = ""
    @State private var associationTarget: PocketClassic?

    private var activeROM: ROMFolderGame { selectedDiscROM ?? rom }
    private var unifiedSources: GamingUnifiedSources? { catalogSnapshot.sourcesByEntryID["local:\(rom.id)"] }
    private var availableLocalDiscs: [ROMFolderGame] {
        let list = unifiedSources?.localROMs ?? []
        return list.isEmpty ? [rom] : list
    }
    private var missingDriveItems: [ClassicDriveGameItem] {
        let localNames = Set(availableLocalDiscs.map { $0.filename.lowercased() })
        return (unifiedSources?.driveItems ?? []).filter { !localNames.contains($0.name.lowercased()) }
    }
    private var linkedSourcesSummary: String {
        var labels = [GamingModePresentation.localAvailabilityLabel]
        if linkedPCGame != nil { labels.append(GamingModePresentation.computerAvailabilityLabel) }
        if !(unifiedSources?.driveItems.isEmpty ?? true) { labels.append(GamingModePresentation.cloudAvailabilityLabel) }
        return labels.joined(separator: " · ")
    }

    private var record: PocketClassic? {
        pocket.games.first { $0.filename.caseInsensitiveCompare(activeROM.filename) == .orderedSame }
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

    private var installedCore: CoreDescriptor? { IntegratedEmulatorSupport.core(for: activeROM) }
    private var system: EmulatedSystemID? { IntegratedEmulatorSupport.system(for: activeROM) }
    private var isAvailableOnPhone: Bool { installedCore != nil || canUseRetroArch }
    private var pcNativeSaveCompatible: Bool { installedCore != nil }
    private var canUseRetroArch: Bool {
        GamingModeCatalog.canOfferRetroArch(for: activeROM, imported: pocket.isImportedIntoRetroArch(activeROM))
    }
    private var linkedPCGame: Game? {
        if let unifiedPC = unifiedSources?.computerGame {
            return unifiedPC
        }
        if let link = record, !link.launcherGameID.isEmpty,
           let explicit = store.snapshot.games.first(where: { GamingModeCatalog.isEligibleComputerClassic($0) && $0.id == link.launcherGameID }) {
            return explicit
        }
        if let matched = GamingModeCatalog.matchedComputerGame(for: activeROM, records: pocket.games, computer: store.snapshot.games),
           matched.installed {
            return matched
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            GamingHeader {
                Button { dismiss() } label: { Label("Biblioteca", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GamingHero(title: activeROM.title, platform: system?.rawValue.uppercased() ?? "CLASSICS",
                               artwork: GamingArtwork(game: pocket.launcherGame(for: activeROM, launcher: store) ?? linkedPCGame, rom: activeROM)) {
                        VStack(alignment: .leading, spacing: 10) {
                            GamingAvailabilityBadge(kind: isAvailableOnPhone ? .available : (linkedPCGame != nil ? .onComputer : .unavailable))
                            GamingMetrics(time: localTime, timeLabel: "Tempo neste iPhone", earned: progress?.unlocked,
                                          total: progress?.achievements.count)
                        }
                    }
                    GamingActionBar(
                        canPlay: isAvailableOnPhone || linkedPCGame != nil,
                        playTitle: "JOGAR",
                        playSubtitle: isAvailableOnPhone ? GamingModePresentation.localAvailabilityLabel : GamingModePresentation.computerAvailabilityLabel,
                        gamepadBusy: launchingGamepad,
                        pcOnline: store.connection == .online,
                        onPlay: {
                            if installedCore != nil {
                                launchIntegrated = true
                            } else if canUseRetroArch {
                                let rom = activeROM
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
                    if availableLocalDiscs.count > 1 || !missingDriveItems.isEmpty {
                        BrumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                BrumSectionLabel(text: "DISCOS E FONTES VINCULADAS")
                                if availableLocalDiscs.count > 1 {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(availableLocalDiscs) { disc in
                                                let selected = disc.id == activeROM.id
                                                let d = GamingModeCatalog.describe(title: disc.title, filename: disc.filename, relativePath: disc.relativePath)
                                                let label = d.discNumber.map { "Disco \($0)" } ?? disc.filename
                                                Button(label) { selectedDiscROM = disc }
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 12).frame(minHeight: 34)
                                                    .background(selected ? BrumTheme.primary : BrumTheme.elevated, in: Capsule())
                                                    .foregroundStyle(selected ? Color.black : BrumTheme.text)
                                                    .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                ForEach(missingDriveItems) { cloudDisc in
                                    HStack {
                                        Text(cloudDisc.name).font(.caption).foregroundStyle(BrumTheme.muted).lineLimit(1)
                                        Spacer()
                                        if downloadingDriveFileID == cloudDisc.id {
                                            ProgressView().tint(.cyan).controlSize(.small)
                                        } else {
                                            Button("BAIXAR DO DRIVE") {
                                                downloadingDriveFileID = cloudDisc.id
                                                Task {
                                                    _ = try? await ClassicDriveCloudService.shared.downloadGame(fileID: cloudDisc.id)
                                                    await pocket.refreshROMFolder()
                                                    await MainActor.run { downloadingDriveFileID = nil }
                                                }
                                            }
                                            .font(.caption2.bold())
                                            .tint(.cyan)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !actionMessage.isEmpty { Text(actionMessage).font(.caption).foregroundStyle(BrumTheme.primary) }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Sistema", value: system.map { MurbProtocol.displaySystemName($0.rawValue) } ?? "Não identificado"),
                        GamingInfoItem(label: "Disponibilidade", value: isAvailableOnPhone ? GamingModePresentation.localAvailabilityLabel : (linkedPCGame != nil ? GamingModePresentation.computerAvailabilityLabel : GamingModePresentation.unavailableOnPhoneLabel)),
                        GamingInfoItem(label: "Fontes vinculadas", value: linkedSourcesSummary),
                        GamingInfoItem(label: "Arquivo", value: activeROM.filename),
                        GamingInfoItem(label: "Tamanho", value: ByteCountFormatter.string(fromByteCount: activeROM.fileSize, countStyle: .file)),
                        GamingInfoItem(label: "RetroAchievements", value: Int(record?.retroAchievementID ?? "").map { "ID \($0)" } ?? "Não vinculado"),
                        GamingInfoItem(label: "Biblioteca PC", value: linkedPCGame?.title ?? "Não vinculado")
                    ])
                    if system == .playStationPortable {
                        Text("Saves de PSP ficam armazenados localmente neste aparelho.")
                            .font(.caption).foregroundStyle(BrumTheme.muted)
                    }
                    if installedCore != nil && system != .playStationPortable {
                        Button {
                            syncingNativeSave = true
                            Task {
                                await performDirectSaveSync(choice: nil)
                                syncingNativeSave = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if syncingNativeSave { ProgressView().tint(BrumTheme.primary).controlSize(.small) }
                                Text(syncingNativeSave ? "SINCRONIZANDO SAVE…" : "SINCRONIZAR SAVE COM PC")
                            }
                            .frame(maxWidth: .infinity).frame(height: 44)
                        }
                        .buttonStyle(.bordered).tint(BrumTheme.primary)
                        .disabled(store.connection != .online || syncingNativeSave)
                    }
                    if let game = linkedPCGame {
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
                            Task { associationTarget = await pocket.ensureClassicRecord(for: activeROM) }
                        }
                    }.font(.subheadline.weight(.semibold)).tint(BrumTheme.primary)
                    if !actionMessage.isEmpty { Text(actionMessage).font(.caption).foregroundStyle(BrumTheme.muted) }
                    if !pocket.lastSaveSyncSummary.isEmpty && pocket.lastSaveSyncSummary != actionMessage {
                        Text(pocket.lastSaveSyncSummary).font(.caption).foregroundStyle(BrumTheme.muted)
                    }
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
        .fullScreenCover(isPresented: $launchIntegrated) {
            let rom = activeROM
            IntegratedEmulatorView(rom: rom, returnsToPortrait: false)
        }
        .fullScreenCover(isPresented: $launchIntegratedVirtualP2) {
            let rom = activeROM
            IntegratedEmulatorView(rom: rom, returnsToPortrait: false, virtualPadPort: 1)
        }
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
        .confirmationDialog("Conflito de save entre iPhone e PC", isPresented: $showSaveConflictDialog, titleVisibility: .visible) {
            Button("Usar save deste iPhone (enviar ao PC)") {
                syncingNativeSave = true
                Task {
                    await performDirectSaveSync(choice: .keepPhone)
                    syncingNativeSave = false
                }
            }
            Button("Usar save do PC (aplicar no iPhone)") {
                syncingNativeSave = true
                Task {
                    await performDirectSaveSync(choice: .usePC)
                    syncingNativeSave = false
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(saveConflictDetail.isEmpty ? "Tanto este iPhone quanto o computador possuem saves diferentes. Escolha qual versão manter (um backup da versão substituída é preservado)." : saveConflictDetail)
        }
    }

    private func performDirectSaveSync(choice: DirectSaveConflictChoice?) async {
        do {
            let outcome = try await pocket.syncNativeSaveDirectly(activeROM, launcher: store, conflictChoice: choice)
            switch outcome {
            case .synced(let text), .upToDate(let text), .quarantined(let text):
                actionMessage = text
            case .conflict:
                saveConflictDetail = "Tanto o iPhone quanto o computador possuem progresso diferente para este jogo. Escolha qual versão deseja manter."
                showSaveConflictDialog = true
            }
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private var localAchievementMessage: String {
        if pocket.credentials == nil { return "Conecte sua conta nas configurações do Gaming Mode." }
        if Int(record?.retroAchievementID ?? "") == nil { return "Vincule este jogo ao RetroAchievements para consultar o progresso." }
        if progress != nil { return "O RetroAchievements não retornou conquistas para este título." }
        return "O progresso aparece após sincronizar o jogo vinculado."
    }

    private func launchGamepadFromROM() {
        startPCGamepadOrMultiplayer(players: 1, hybridMode: "mobile1-pc2", myPlayerNumber: 1)
    }

    private func startPCGamepadOrMultiplayer(players: Int, hybridMode: String, myPlayerNumber: Int) {
        guard store.connection == .online else {
            actionMessage = "Computador offline. Conecte o Launcher na mesma rede ou pareie o controle manualmente."
            showMurbManual = true
            return
        }
        launchingGamepad = true
        actionMessage = "Iniciando \(activeROM.title) no computador e abrindo joystick virtual…"
        let resolvedGameID = linkedPCGame?.id ?? pocket.launcherGame(for: activeROM, launcher: store)?.id
        Task {
            let outcome = await GamingGamepadLaunch.start(
                store: store,
                gameID: resolvedGameID,
                filename: activeROM.filename,
                title: activeROM.title,
                players: players,
                hybridMode: hybridMode,
                myPlayerNumber: myPlayerNumber
            )
            launchingGamepad = false
            actionMessage = outcome.message
            if let target = outcome.target { activeMurbTarget = target }
            else if outcome.openManualSheet { showMurbManual = true }
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
    var driveItem: ClassicDriveGameItem? = nil
    var isDownloading = false
    let openDetails: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: openDetails) {
                    GameCoverView(game: game, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
                }
                .buttonStyle(.plain)
                if let driveItem {
                    Button(action: onDownload) {
                        ZStack {
                            Circle().fill(BrumTheme.background.opacity(0.9))
                            Circle().stroke((isDownloading ? Color.orange : Color.cyan).opacity(0.75), lineWidth: 1)
                            if isDownloading {
                                ProgressView().tint(.orange).controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(Color.cyan)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel(isDownloading ? "Baixando \(driveItem.title)" : "Baixar \(driveItem.title) do Google Drive")
                    .accessibilityIdentifier("gaming-pc-drive-download-\(driveItem.id)")
                }
            }
            Button(action: openDetails) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.platform.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.muted)
                    Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                    Text(isDownloading
                         ? GamingModePresentation.downloadingAvailabilityLabel
                         : (driveItem != nil ? "\(GamingModePresentation.computerAvailabilityLabel) · Drive" : GamingModePresentation.computerAvailabilityLabel))
                        .font(.caption2.bold())
                        .foregroundStyle(isDownloading ? Color.orange : (driveItem != nil ? Color.cyan : BrumTheme.muted))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GamingDriveTile: View {
    let item: ClassicDriveGameItem
    let matchedPC: Game?
    let platformLabel: String
    let isDownloading: Bool
    let progress: Double?
    let openDetails: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: openDetails) {
                    if let matchedPC, !matchedPC.artworkPath.isEmpty {
                        GameCoverView(game: matchedPC, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(BrumTheme.surface)
                            .aspectRatio(0.72, contentMode: .fit)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "icloud.and.arrow.down.fill")
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(Color.cyan)
                                    Text(platformLabel)
                                        .font(.caption2.bold())
                                        .foregroundStyle(BrumTheme.muted)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ver detalhes de \(item.title)")

                Button(action: onDownload) {
                    ZStack {
                        Circle().fill(BrumTheme.background.opacity(0.9))
                        Circle().stroke((isDownloading ? Color.orange : Color.cyan).opacity(0.75), lineWidth: 1)
                        if isDownloading {
                            ProgressView().tint(.orange).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Color.cyan)
                        }
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(isDownloading ? "Cancelar download de \(item.title)" : "Baixar \(item.title) do Google Drive")
                .accessibilityIdentifier("gaming-drive-download-\(item.id)")
            }

            Button(action: openDetails) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(platformLabel).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.muted)
                    Text(item.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                    if isDownloading {
                        let pctText = progress.map { "\(Int(($0 * 100).rounded()))%" } ?? ""
                        Text("Baixando… \(pctText)")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    } else {
                        Text(GamingModePresentation.cloudAvailabilityLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GamingDriveDetailView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.gamingCatalogSnapshot) private var catalogSnapshot
    @Environment(\.dismiss) private var dismiss
    let item: ClassicDriveGameItem
    let matchedPC: Game?

    @State private var currentItem: ClassicDriveGameItem
    @State private var downloading = false
    @State private var progressFraction: Double?
    @State private var receivedBytes: Int64 = 0
    @State private var totalBytes: Int64?
    @State private var statusMessage = ""
    @State private var downloadedROM: ROMFolderGame?
    @State private var launchIntegrated = false

    init(item: ClassicDriveGameItem, matchedPC: Game?) {
        self.item = item
        self.matchedPC = matchedPC
        _currentItem = State(initialValue: item)
    }

    private var driveDiscs: [ClassicDriveGameItem] {
        let list = catalogSnapshot.sourcesByEntryID["drive:\(item.id)"]?.driveItems ?? []
        return list.isEmpty ? [currentItem] : list
    }

    private var resolvedPlatform: String {
        if let rom = downloadedROM, let sys = IntegratedEmulatorSupport.system(for: rom) {
            return MurbProtocol.displaySystemName(sys.rawValue)
        }
        return currentItem.systemHint.isEmpty ? "CLASSICS" : GamingModeCatalog.consoleLabel(for: GamingModeCatalog.normalizedPlatform(currentItem.systemHint))
    }

    var body: some View {
        VStack(spacing: 0) {
            GamingHeader {
                Button { dismiss() } label: { Label("Biblioteca", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GamingHero(title: currentItem.title, platform: resolvedPlatform, artwork: GamingArtwork(game: matchedPC, rom: downloadedROM)) {
                        VStack(alignment: .leading, spacing: 10) {
                            GamingAvailabilityBadge(kind: downloadedROM != nil ? .available : (downloading ? .downloading : .inCloud))
                            if let rom = downloadedROM {
                                Text("Salvo em \(rom.filename) para jogar offline.")
                                    .font(.caption)
                                    .foregroundStyle(BrumTheme.primary)
                            }
                        }
                    }

                    if driveDiscs.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            BrumSectionLabel(text: "DISCOS DISPONÍVEIS NO GOOGLE DRIVE")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(driveDiscs) { disc in
                                        let selected = disc.id == currentItem.id
                                        let d = GamingModeCatalog.describe(title: disc.title, filename: disc.name, relativePath: disc.relativePath, platform: disc.systemHint)
                                        Button(d.discNumber.map { "Disco \($0)" } ?? disc.name) {
                                            currentItem = disc
                                            refreshDownloadedROM()
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12).frame(minHeight: 34)
                                        .background(selected ? Color.cyan : BrumTheme.surface, in: Capsule())
                                        .foregroundStyle(selected ? Color.black : BrumTheme.text)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if let rom = downloadedROM {
                        Button {
                            launchIntegrated = true
                        } label: {
                            Label("JOGAR AGORA", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("gaming-drive-detail-play")
                    } else if downloading {
                        VStack(alignment: .leading, spacing: 10) {
                            if let progressFraction {
                                ProgressView(value: progressFraction).tint(.cyan)
                            } else {
                                ProgressView().tint(.cyan)
                            }
                            HStack {
                                Text(progressSummary)
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("CANCELAR", role: .cancel) {
                                    cancelDownload()
                                }
                                .font(.caption.bold())
                            }
                        }
                        .padding(14)
                        .background(BrumTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            startDownload()
                        } label: {
                            Label("BAIXAR DO GOOGLE DRIVE", systemImage: "arrow.down.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .foregroundStyle(.black)
                        .accessibilityIdentifier("gaming-drive-detail-download")
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(statusMessage.lowercased().contains("falha") || statusMessage.lowercased().contains("erro") ? Color.orange : BrumTheme.primary)
                    }

                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Sistema", value: resolvedPlatform),
                        GamingInfoItem(label: "Fontes vinculadas", value: matchedPC != nil ? "Google Drive · Computador" : "Google Drive (Nuvem)"),
                        GamingInfoItem(label: "Arquivo", value: currentItem.name),
                        GamingInfoItem(label: "Pasta no Drive", value: currentItem.parentRelativePath.isEmpty ? "Raiz" : currentItem.parentRelativePath),
                        GamingInfoItem(label: "Tamanho", value: (currentItem.sizeBytes ?? 0) > 0 ? ByteCountFormatter.string(fromByteCount: currentItem.sizeBytes ?? 0, countStyle: .file) : "Calculado ao baixar")
                    ])
                }.frame(maxWidth: 1000, alignment: .leading).padding(20).frame(maxWidth: .infinity)
            }
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .onAppear {
            GamingOrientation.request(.landscape)
            refreshDownloadedROM()
        }
        .task {
            let cp = await ClassicDriveCloudService.shared.currentCheckpoint()
            if let updated = cp.items.first(where: { $0.id == currentItem.id }) {
                currentItem = updated
            }
            refreshDownloadedROM()
        }
        .fullScreenCover(isPresented: $launchIntegrated) {
            if let downloadedROM {
                IntegratedEmulatorView(rom: downloadedROM, returnsToPortrait: false)
            }
        }
    }

    private var progressSummary: String {
        if let progressFraction {
            let pct = Int((progressFraction * 100).rounded())
            return "Baixando do Google Drive… \(pct)%"
        }
        if receivedBytes > 0 {
            return "Baixando… \(ByteCountFormatter.string(fromByteCount: receivedBytes, countStyle: .file))"
        }
        return "Conectando ao Google Drive…"
    }

    private func refreshDownloadedROM() {
        let filename = (currentItem.downloadedLocalPath.map { URL(fileURLWithPath: $0).lastPathComponent }) ?? currentItem.name
        downloadedROM = pocket.romFolderGames.first { $0.filename.caseInsensitiveCompare(filename) == .orderedSame }
    }

    private func startDownload() {
        downloading = true
        progressFraction = nil
        receivedBytes = 0
        totalBytes = nil
        statusMessage = ""
        Task {
            do {
                let savedURL = try await ClassicDriveCloudService.shared.downloadGame(fileID: currentItem.id) { rec, tot in
                    Task { @MainActor in
                        receivedBytes = rec
                        totalBytes = tot
                        if let tot, tot > 0 {
                            progressFraction = min(1, max(0, Double(rec) / Double(tot)))
                        }
                    }
                }
                await pocket.refreshROMFolder()
                let cp = await ClassicDriveCloudService.shared.currentCheckpoint()
                await MainActor.run {
                    if let updated = cp.items.first(where: { $0.id == currentItem.id }) {
                        currentItem = updated
                    }
                    refreshDownloadedROM()
                    downloading = false
                    statusMessage = "Salvo offline em \(savedURL.lastPathComponent)."
                }
            } catch {
                await MainActor.run {
                    downloading = false
                    if !(error is CancellationError) {
                        statusMessage = "Falha ao baixar: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func cancelDownload() {
        Task {
            await ClassicDriveCloudService.shared.cancelDownload(fileID: currentItem.id)
            await MainActor.run {
                downloading = false
                statusMessage = "Download cancelado."
            }
        }
    }
}

private struct GamingGameView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.gamingCatalogSnapshot) private var catalogSnapshot
    @Environment(\.dismiss) private var dismiss
    let initialGame: Game
    let driveItem: ClassicDriveGameItem?
    private var game: Game { store.snapshot.games.first { $0.id == initialGame.id } ?? initialGame }
    init(game: Game, driveItem: ClassicDriveGameItem? = nil) {
        initialGame = game
        self.driveItem = driveItem
    }
    private var allDriveItems: [ClassicDriveGameItem] {
        let list = catalogSnapshot.allDriveItemsByPCID[game.id] ?? []
        if !list.isEmpty { return list }
        return driveItem.map { [$0] } ?? []
    }
    @State private var selectedDriveDiscID: String?
    private var activeDriveItem: ClassicDriveGameItem? {
        if let selectedDriveDiscID, let match = allDriveItems.first(where: { $0.id == selectedDriveDiscID }) {
            return match
        }
        return allDriveItems.first ?? driveItem
    }
    private var linkedSourcesLabel: String {
        var list = [GamingModePresentation.computerAvailabilityLabel]
        if !allDriveItems.isEmpty { list.append(GamingModePresentation.cloudAvailabilityLabel) }
        if downloadedROM != nil { list.insert(GamingModePresentation.localAvailabilityLabel, at: 0) }
        return list.joined(separator: " · ")
    }
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
    @State private var downloadingDrive = false
    @State private var driveProgress: Double?
    @State private var downloadedROM: ROMFolderGame?
    @State private var launchDownloadedROM = false

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
                            GamingAvailabilityBadge(kind: game.installed ? .onComputer : .unavailable)
                            GamingMetrics(time: game.playtimeLabel, timeLabel: "Tempo jogado",
                                          earned: hasAchievementTotals ? game.achievementsCollected : nil,
                                          total: hasAchievementTotals ? game.achievementsTotal : nil)
                        }
                    }
                    GamingActionBar(
                        canPlay: canStartOnPC,
                        playTitle: "JOGAR",
                        playSubtitle: streaming?.available == true ? "Streaming no celular" : GamingModePresentation.computerAvailabilityLabel,
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
                    if allDriveItems.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allDriveItems) { disc in
                                    let isSelected = disc.id == activeDriveItem?.id
                                    let d = GamingModeCatalog.describe(title: disc.title, filename: disc.name, relativePath: disc.relativePath, platform: disc.systemHint)
                                    Button(d.discNumber.map { "Disco \($0)" } ?? disc.name) {
                                        selectedDriveDiscID = disc.id
                                        downloadedROM = pocket.romFolderGames.first { $0.filename.caseInsensitiveCompare(disc.name) == .orderedSame }
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12).frame(minHeight: 34)
                                    .background(isSelected ? Color.cyan : BrumTheme.surface, in: Capsule())
                                    .foregroundStyle(isSelected ? Color.black : BrumTheme.text)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if let driveItem = activeDriveItem {
                        if let downloadedROM {
                            Button {
                                launchDownloadedROM = true
                            } label: {
                                Label("JOGAR NO IPHONE (OFFLINE)", systemImage: "play.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity, minHeight: 46)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("gaming-pc-drive-play-local")
                        } else if downloadingDrive {
                            HStack(spacing: 10) {
                                ProgressView(value: driveProgress ?? 0).tint(.cyan)
                                Button("CANCELAR", role: .cancel) {
                                    Task {
                                        await ClassicDriveCloudService.shared.cancelDownload(fileID: driveItem.id)
                                        await MainActor.run {
                                            downloadingDrive = false
                                            launchState = "Download cancelado."
                                        }
                                    }
                                }
                                .font(.caption.bold())
                            }
                        } else {
                            Button {
                                startMatchedDriveDownload(driveItem)
                            } label: {
                                Label("BAIXAR DO GOOGLE DRIVE PARA O IPHONE", systemImage: "arrow.down.circle.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity, minHeight: 46)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .foregroundStyle(.black)
                            .accessibilityIdentifier("gaming-pc-drive-detail-download")
                        }
                    }
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Plataforma", value: game.platform),
                        GamingInfoItem(label: "Gênero", value: game.genre),
                        GamingInfoItem(label: "Origem", value: game.store),
                        GamingInfoItem(label: "Fontes vinculadas", value: linkedSourcesLabel),
                        GamingInfoItem(label: "Status", value: game.statusLabel),
                        GamingInfoItem(label: "Tamanho", value: game.sizeBytes > 0 ? ByteCountFormatter.string(fromByteCount: game.sizeBytes, countStyle: .file) : ""),
                        GamingInfoItem(label: "Disponibilidade", value: GamingModePresentation.computerAvailabilityLabel)
                    ])
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
        .fullScreenCover(isPresented: $launchDownloadedROM) {
            if let downloadedROM {
                IntegratedEmulatorView(rom: downloadedROM, returnsToPortrait: false)
            }
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
            let outcome = await GamingGamepadLaunch.start(
                store: store,
                gameID: game.id,
                filename: nil,
                title: game.title,
                players: players,
                hybridMode: hybridMode,
                myPlayerNumber: myPlayerNumber
            )
            launchingGamepad = false
            launchState = outcome.message
            if let target = outcome.target { activeMurbTarget = target }
            else if outcome.openManualSheet { showMurbRemote = true }
        }
    }

    private func startMatchedDriveDownload(_ item: ClassicDriveGameItem) {
        downloadingDrive = true
        driveProgress = nil
        launchState = "Baixando \(item.title) do Google Drive…"
        Task {
            do {
                let savedURL = try await ClassicDriveCloudService.shared.downloadGame(fileID: item.id) { received, total in
                    guard let total, total > 0 else { return }
                    let pct = min(1, max(0, Double(received) / Double(total)))
                    Task { @MainActor in driveProgress = pct }
                }
                await pocket.refreshROMFolder()
                await MainActor.run {
                    downloadingDrive = false
                    let name = savedURL.lastPathComponent
                    downloadedROM = pocket.romFolderGames.first { $0.filename.caseInsensitiveCompare(name) == .orderedSame }
                    launchState = "Baixado em \(name). Pronto para jogar no iPhone!"
                }
            } catch {
                await MainActor.run {
                    downloadingDrive = false
                    if !(error is CancellationError) {
                        launchState = "Falha no download do Drive: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

@MainActor enum GamingGamepadLaunch {
    static func start(
        store: AppStore,
        gameID: String?,
        filename: String?,
        title: String,
        players: Int,
        hybridMode: String,
        myPlayerNumber: Int
    ) async -> (target: MurbRemoteLaunchTarget?, message: String, openManualSheet: Bool) {
        let result = await store.launchGamepadOnPC(
            gameID: gameID,
            filename: filename,
            title: title,
            mode: "new",
            players: players,
            hybridMode: hybridMode
        )
        switch result {
        case .success(let launch):
            if let target = MurbRemoteLaunchTarget.from(launch.remoteGamepad, fallbackHost: store.configuration?.host, gameTitle: title, playerNumber: myPlayerNumber, preferFallbackHost: true) {
                MurbRemoteStore().remember(target.payload)
                return (target, launch.message ?? "Jogo aberto no computador; joystick virtual ativo.", false)
            }
            return (nil, (launch.message ?? "Jogo aberto no computador.") + " Conecte o Gamepad MURB pela tela seguinte.", true)
        case .failure(let error):
            return (nil, "Não foi possível abrir o modo Gamepad: \(error.localizedDescription)", false)
        }
    }
}

struct GamingActionBar: View {
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

struct LocalMultiplayerSheet: View {
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
                        Button("Abrir Gamepad para PC manualmente") { onOpenManualMurb() }
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
