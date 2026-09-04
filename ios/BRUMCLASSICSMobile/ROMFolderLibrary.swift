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
                title: standardized.deletingPathExtension().lastPathComponent,
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
            throw PocketError.message("Selecione a pasta Downloads em Perfil → Configurações do app → CLASSICS.")
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
}
