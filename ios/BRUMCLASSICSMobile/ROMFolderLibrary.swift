import Foundation

struct ROMFolderGame: Codable, Equatable, Identifiable {
    let relativePath: String
    let filename: String
    let title: String
    let fileSize: Int64

    var id: String { relativePath.lowercased() }
}

struct ROMFolderScan: Equatable {
    let games: [ROMFolderGame]
    let duplicateFilenames: Int
}

struct ROMShareTicket: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let title: String
}

enum ROMTitleRules {
    static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\.[a-z0-9]{2,5}$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^\s*\d{1,6}\s*(?:[-_.:]\s*)+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"([a-zà-öø-ÿ])([A-Z])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+-\s+(?:rev(?:ision)?|beta|proto(?:type)?|demo|sample)\b.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+version\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_. "))
    }
}

enum ROMFolderScanner {
    static let maximumFiles = 10_000

    static func scan(_ root: URL, allowedExtensions: Set<String> = PocketRules.extensions) throws -> ROMFolderScan {
        let root = root.standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw PocketError.message("Não foi possível ler a pasta de ROMs autorizada.") }

        var candidates: [ROMFolderGame] = []
        for case let file as URL in enumerator {
            if candidates.count >= maximumFiles { break }
            let values = try file.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  allowedExtensions.contains(file.pathExtension.lowercased()),
                  let size = values.fileSize, size > 0 else { continue }
            let standardized = file.standardizedFileURL
            let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            guard standardized.path.hasPrefix(rootPrefix) else { continue }
            let relative = String(standardized.path.dropFirst(rootPrefix.count))
            guard !relative.isEmpty, relative.count <= 1_000, PocketRules.safeFilename(standardized.lastPathComponent) else { continue }
            candidates.append(ROMFolderGame(
                relativePath: relative,
                filename: standardized.lastPathComponent,
                title: ROMTitleRules.clean(standardized.lastPathComponent),
                fileSize: Int64(size)
            ))
        }

        let filenameCounts = Dictionary(grouping: candidates, by: { $0.filename.lowercased() }).mapValues(\.count)
        let duplicateCount = candidates.filter { filenameCounts[$0.filename.lowercased(), default: 0] > 1 }.count
        let games = candidates
            .filter { filenameCounts[$0.filename.lowercased()] == 1 }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return ROMFolderScan(games: games, duplicateFilenames: duplicateCount)
    }
}

actor ROMFolderAccess {
    private let bookmarkKey = "brumclassics-ios-rom-folder-bookmark-v1"
    private let nameKey = "brumclassics-ios-rom-folder-name-v1"
    private var activeShares: [UUID: (root: URL, accessing: Bool)] = [:]

    var configured: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }
    var displayName: String { UserDefaults.standard.string(forKey: nameKey) ?? "Downloads" }

    func configure(_ folder: URL) throws -> ROMFolderScan {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let scan = try ROMFolderScanner.scan(folder)
        let bookmark = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(folder.lastPathComponent.isEmpty ? "Downloads" : folder.lastPathComponent, forKey: nameKey)
        return scan
    }

    func scan() throws -> ROMFolderScan {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw PocketError.message("Selecione uma pasta de ROMs em Perfil → Configurações do app → CLASSICS.")
        }
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let result = try ROMFolderScanner.scan(folder)
        if stale {
            let refreshed = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return result
    }

    func beginShare(for game: ROMFolderGame) throws -> ROMShareTicket {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw PocketError.message("Selecione novamente a pasta de ROMs.")
        }
        var stale = false
        let root = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale).standardizedFileURL
        let accessing = root.startAccessingSecurityScopedResource()
        let file = root.appendingPathComponent(game.relativePath).standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard file.path.hasPrefix(prefix), file.lastPathComponent == game.filename else {
            if accessing { root.stopAccessingSecurityScopedResource() }
            throw PocketError.message("O caminho da ROM não pertence mais à pasta autorizada.")
        }
        let values: URLResourceValues
        do { values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) }
        catch {
            if accessing { root.stopAccessingSecurityScopedResource() }
            throw error
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else {
            if accessing { root.stopAccessingSecurityScopedResource() }
            throw PocketError.message("A ROM não está mais disponível na pasta escolhida.")
        }
        let ticket = ROMShareTicket(id: UUID(), url: file, title: game.title)
        activeShares[ticket.id] = (root, accessing)
        return ticket
    }

    func finishShare(_ id: UUID) {
        guard let share = activeShares.removeValue(forKey: id) else { return }
        if share.accessing { share.root.stopAccessingSecurityScopedResource() }
    }
}
