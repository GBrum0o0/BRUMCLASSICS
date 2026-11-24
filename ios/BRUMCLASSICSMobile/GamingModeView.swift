import GameController
import SwiftUI
import UIKit

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Binding var selection: Int
    @State private var selectedGame: Game?
    @State private var selectedROM: ROMFolderGame?
    @State private var quickRemoteTarget: MurbRemoteLaunchTarget?
    private enum GamingSection: String { case recent, library, extensions, myBrumControl }
    @State private var activeSection: GamingSection = .recent
    @AppStorage("gaming-mode-favorites-v1") private var favoritesJSON = "[]"

    @State private var catalogSnapshot = GamingCatalogSnapshot.empty
    @State private var searchQuery = ""
    @State private var selectedConsole = "all"
    private let columns = [GridItem(.adaptive(minimum: 135), spacing: 16)]
    private var favoriteIDs: Set<String> {
        guard let data = favoritesJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }
    private var catalogFingerprint: String {
        let romPart = pocket.romFolderGames.map { "\($0.id)" }.joined(separator: ",")
        let recPart = pocket.games.map { "\($0.filename):\($0.launcherGameID):\($0.lastPlayedAt?.timeIntervalSince1970 ?? 0)" }.joined(separator: ",")
        let pcPart = GamingModeCatalog.computerFingerprint(store.snapshot.games)
        return "\(romPart)|\(recPart)|\(pcPart)|\(favoritesJSON)"
    }
    private var libraryEntries: [GamingCatalogEntry] { catalogSnapshot.library }
    private var recentEntries: [GamingCatalogEntry] { catalogSnapshot.recent }
    private var activeBaseEntries: [GamingCatalogEntry] {
        (activeSection == .library || recentEntries.isEmpty) ? libraryEntries : recentEntries
    }
    private var consoleOptions: [GamingConsoleOption] {
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
            favorites: favoriteIDs
        )
        let validKeys = Set(consoleOptions.map(\.id))
        if selectedConsole != "all" && !validKeys.contains(selectedConsole) {
            selectedConsole = "all"
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
                        libraryTab("MYbrumCONTROL", selected: activeSection == .myBrumControl) { activeSection = .myBrumControl }
                            .accessibilityIdentifier("gaming-mode-mybrumcontrol")
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
                    } else if activeSection == .myBrumControl {
                        MyBrumControlView()
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
                        if let featured = filteredEntries.first {
                            GamingHero(title: featured.title, platform: platform(for: featured), artwork: artwork(for: featured)) {
                                Button("VER DETALHES") { open(featured) }
                                    .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 180)
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
            refreshCatalog()
        }
        .task(id: catalogFingerprint) {
            refreshCatalog()
        }
        .fullScreenCover(item: $selectedGame) { GamingGameView(game: $0) }
        .fullScreenCover(item: $selectedROM) { GamingROMDetailView(rom: $0) }
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
        }
    }

    private func platform(for entry: GamingCatalogEntry) -> String {
        switch entry {
        case .local(let rom, _): return IntegratedEmulatorSupport.system(for: rom)?.rawValue.uppercased() ?? "CLASSICS"
        case .computer(let game): return game.platform
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
                Button { open(entry) } label: { GamingGameTile(game: game) }
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

struct GamingCatalogSnapshot {
    let library: [GamingCatalogEntry]
    let recent: [GamingCatalogEntry]
    let matchedByROMID: [ROMFolderGame.ID: Game]

    static let empty = GamingCatalogSnapshot(library: [], recent: [], matchedByROMID: [:])
}

enum GamingModePresentation {
    static let localAvailabilityLabel = "Disponível"
    static let computerAvailabilityLabel = "No computador"
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
        case "gb", "game boy": return "gb"
        case "gbc", "game boy color": return "gbc"
        case "gba", "game boy advance": return "gba"
        case "ds", "nds", "nintendo ds": return "nds"
        case "3ds", "n3ds", "nintendo 3ds": return "3ds"
        case "nes", "nintendo", "famicom", "nintendo entertainment system": return "nes"
        case "sfc", "snes", "super nintendo", "super famicom": return "sfc"
        case "n64", "nintendo 64": return "n64"
        case "gc", "gamecube", "nintendo gamecube": return "gamecube"
        case "wii", "nintendo wii": return "wii"
        case "wiiu", "wii u", "nintendo wii u": return "wiiu"
        case "psx", "ps1", "playstation", "playstation 1": return "psx"
        case "ps2", "playstation 2": return "ps2"
        case "psp", "playstation portable": return "psp"
        case "md", "genesis", "mega drive", "sega genesis": return "md"
        case "sms", "master system", "sega master system": return "sms"
        case "gg", "game gear": return "gg"
        case "segacd", "sega cd", "mega cd": return "segacd"
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
        let titleKey = normalizedKey(rom.title)
        let fileKey = normalizedKey(rom.filename)
        let candidates = computer.filter { game in
            guard isEligibleClassicCategory(game) else { return false }
            let gKey = normalizedKey(game.title)
            guard !gKey.isEmpty else { return false }
            return gKey == titleKey || (!fileKey.isEmpty && gKey == fileKey)
        }
        if candidates.isEmpty { return nil }
        let platformFiltered = candidates.filter { platformMatches(system, pcPlatform: $0.platform) }
        let pool = platformFiltered.isEmpty ? candidates : platformFiltered
        if let installedMatch = pool.first(where: \.installed) { return installedMatch }
        return pool.first
    }

    private static func matchedComputerGame(
        for rom: ROMFolderGame,
        system: EmulatedSystemID?,
        record: PocketClassic?,
        computerByID: [String: Game],
        computerByTitleKey: [String: [Game]]
    ) -> Game? {
        if let linkedID = record?.launcherGameID, !linkedID.isEmpty,
           let exact = computerByID[linkedID], isEligibleClassicCategory(exact) {
            return exact
        }
        let titleKey = normalizedKey(rom.title)
        let fileKey = normalizedKey(rom.filename)
        var candidates: [Game] = []
        var seenIDs = Set<String>()
        func appendCandidates(for key: String) {
            guard !key.isEmpty, let bucket = computerByTitleKey[key] else { return }
            for game in bucket {
                guard isEligibleClassicCategory(game) else { continue }
                if seenIDs.insert(game.id).inserted {
                    candidates.append(game)
                }
            }
        }
        appendCandidates(for: titleKey)
        if fileKey != titleKey {
            appendCandidates(for: fileKey)
        }
        if candidates.isEmpty { return nil }
        let platformFiltered = candidates.filter { platformMatches(system, pcPlatform: $0.platform) }
        let pool = platformFiltered.isEmpty ? candidates : platformFiltered
        if let installedMatch = pool.first(where: \.installed) { return installedMatch }
        return pool.first
    }

    static func buildSnapshot(
        local: [ROMFolderGame],
        records: [PocketClassic],
        computer: [Game],
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
        var computerByTitleKey: [String: [Game]] = [:]
        var pcDateByID: [String: Date] = [:]
        computerByID.reserveCapacity(computer.count)
        computerByTitleKey.reserveCapacity(computer.count)
        for game in computer {
            guard isEligibleClassicCategory(game) else { continue }
            computerByID[game.id] = game
            let gKey = normalizedKey(game.title)
            if !gKey.isEmpty {
                computerByTitleKey[gKey, default: []].append(game)
            }
            if let parsed = date(game.lastPlayedAt) {
                pcDateByID[game.id] = parsed
            }
        }

        var matchedPCIDs = Set<String>()
        var localTitleKeys = Set<String>()
        var matchedByROMID: [ROMFolderGame.ID: Game] = [:]
        matchedByROMID.reserveCapacity(local.count)

        var localEntries: [GamingCatalogEntry] = []
        localEntries.reserveCapacity(local.count)
        for rom in local {
            let record = recordsByFilename[rom.filename.lowercased()]
            if let explicitID = record?.launcherGameID, !explicitID.isEmpty {
                matchedPCIDs.insert(explicitID)
            }
            let system = IntegratedEmulatorSupport.system(for: rom)
            let matchedPC = matchedComputerGame(
                for: rom,
                system: system,
                record: record,
                computerByID: computerByID,
                computerByTitleKey: computerByTitleKey
            )
            if let matchedPC {
                matchedPCIDs.insert(matchedPC.id)
                matchedByROMID[rom.id] = matchedPC
            }
            let sysKey = system?.rawValue ?? ""
            let tKey = normalizedKey(rom.title)
            if !tKey.isEmpty {
                localTitleKeys.insert("\(tKey)|\(sysKey)")
            }
            let pcDate = matchedPC.flatMap { pcDateByID[$0.id] }
            let latestDate = [record?.lastPlayedAt, pcDate].compactMap { $0 }.max()
            localEntries.append(GamingCatalogEntry.local(rom, latestDate))
        }

        var seenPCKeys = Set<String>()
        var pcEntries: [GamingCatalogEntry] = []
        pcEntries.reserveCapacity(computer.count)
        for game in computer {
            guard isEligibleComputerClassic(game), !matchedPCIDs.contains(game.id) else { continue }
            let gKey = normalizedKey(game.title)
            let pKey = normalizedPlatform(game.platform)
            if !gKey.isEmpty && isEligibleClassicCategory(game) && localTitleKeys.contains("\(gKey)|\(pKey)") {
                continue
            }
            let dedupKey = gKey.isEmpty ? "id:\(game.id)" : "\(gKey)|\(pKey)"
            guard seenPCKeys.insert(dedupKey).inserted else { continue }
            pcEntries.append(GamingCatalogEntry.computer(game))
        }

        let library = (localEntries + pcEntries).sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let recentEntries = recent(library, favorites: favorites, limit: recentLimit, pcDates: pcDateByID)
        return GamingCatalogSnapshot(library: library, recent: recentEntries, matchedByROMID: matchedByROMID)
    }

    static func library(local: [ROMFolderGame], records: [PocketClassic], computer: [Game]) -> [GamingCatalogEntry] {
        // Backing snapshot powers GamingModeCatalog.library while preserving linear O(N + M) indexing.
        buildSnapshot(local: local, records: records, computer: computer).library
    }

    static func recent(_ entries: [GamingCatalogEntry], favorites: Set<String>, limit: Int = 12) -> [GamingCatalogEntry] {
        recent(entries, favorites: favorites, limit: limit, pcDates: nil)
    }

    private static func recent(
        _ entries: [GamingCatalogEntry],
        favorites: Set<String>,
        limit: Int,
        pcDates: [String: Date]?
    ) -> [GamingCatalogEntry] {
        let cap = max(0, limit)
        guard cap > 0 else { return [] }
        var pinned: [GamingCatalogEntry] = []
        var played: [(entry: GamingCatalogEntry, date: Date)] = []
        for entry in entries {
            if favorites.contains(entry.id) {
                pinned.append(entry)
                continue
            }
            let playedAt: Date?
            switch entry {
            case .local(_, let date):
                playedAt = date
            case .computer(let game):
                playedAt = pcDates?[game.id] ?? date(game.lastPlayedAt)
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
    @State private var showSaveConflictDialog = false
    @State private var saveConflictDetail = ""
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
    private var isAvailableOnPhone: Bool { installedCore != nil || canUseRetroArch }
    private var pcNativeSaveCompatible: Bool { installedCore != nil }
    private var canUseRetroArch: Bool {
        GamingModeCatalog.canOfferRetroArch(for: rom, imported: pocket.isImportedIntoRetroArch(rom))
    }
    private var linkedPCGame: Game? {
        if let link = record, !link.launcherGameID.isEmpty,
           let explicit = store.snapshot.games.first(where: { GamingModeCatalog.isEligibleComputerClassic($0) && $0.id == link.launcherGameID }) {
            return explicit
        }
        if let matched = GamingModeCatalog.matchedComputerGame(for: rom, records: pocket.games, computer: store.snapshot.games),
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
                    GamingHero(title: rom.title, platform: system?.rawValue.uppercased() ?? "CLASSICS",
                               artwork: GamingArtwork(game: pocket.launcherGame(for: rom, launcher: store), rom: rom)) {
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
                    if !actionMessage.isEmpty { Text(actionMessage).font(.caption).foregroundStyle(BrumTheme.primary) }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Sistema", value: system.map { MurbProtocol.displaySystemName($0.rawValue) } ?? "Não identificado"),
                        GamingInfoItem(label: "Disponibilidade", value: isAvailableOnPhone ? GamingModePresentation.localAvailabilityLabel : (linkedPCGame != nil ? GamingModePresentation.computerAvailabilityLabel : GamingModePresentation.unavailableOnPhoneLabel)),
                        GamingInfoItem(label: "Arquivo", value: rom.filename),
                        GamingInfoItem(label: "Tamanho", value: ByteCountFormatter.string(fromByteCount: rom.fileSize, countStyle: .file)),
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
                            Task { associationTarget = await pocket.ensureClassicRecord(for: rom) }
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
            let outcome = try await pocket.syncNativeSaveDirectly(rom, launcher: store, conflictChoice: choice)
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
        actionMessage = "Iniciando \(rom.title) no computador e abrindo joystick virtual…"
        let resolvedGameID = linkedPCGame?.id ?? pocket.launcherGame(for: rom, launcher: store)?.id
        Task {
            let outcome = await GamingGamepadLaunch.start(
                store: store,
                gameID: resolvedGameID,
                filename: rom.filename,
                title: rom.title,
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameCoverView(game: game, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
            Text(game.platform.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.muted)
            Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
            Text(GamingModePresentation.computerAvailabilityLabel).font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
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
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Plataforma", value: game.platform),
                        GamingInfoItem(label: "Gênero", value: game.genre),
                        GamingInfoItem(label: "Origem", value: game.store),
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
            return (nil, (launch.message ?? "Jogo aberto no computador.") + " Conecte o Gamepad M.U.R.B pela tela seguinte.", true)
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
