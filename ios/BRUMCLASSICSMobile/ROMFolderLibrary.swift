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
    let filename: String
}

enum CoordinatedFileAccess {
    static func read<T>(_ url: URL, accessor: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else {
            throw PocketError.message("O provedor de arquivos não entregou acesso ao item selecionado.")
        }
        return try result.get()
    }
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

enum RetroArchAppStoreLaunchRules {
    private static let cores: [String: String] = [
        "gba": "mgba.libretro", "gb": "gambatte.libretro", "gbc": "gambatte.libretro",
        "nes": "mesen.libretro", "sfc": "snes9x.libretro", "smc": "snes9x.libretro",
        "n64": "mupen64plus.next.libretro", "z64": "mupen64plus.next.libretro", "v64": "mupen64plus.next.libretro",
        "nds": "melondsds.libretro", "sms": "genesis.plus.gx.libretro", "gg": "genesis.plus.gx.libretro",
        "md": "genesis.plus.gx.libretro", "gen": "genesis.plus.gx.libretro", "pce": "mednafen.pce.fast.libretro",
        "ws": "mednafen.wswan.libretro", "wsc": "mednafen.wswan.libretro"
    ]

    static func supports(filename: String) -> Bool {
        PocketRules.safeFilename(filename) && cores[(filename as NSString).pathExtension.lowercased()] != nil
    }

    static func launchURL(filename: String) -> URL? {
        guard PocketRules.safeFilename(filename), let core = cores[(filename as NSString).pathExtension.lowercased()] else { return nil }
        var components = URLComponents()
        components.scheme = "retroarch"
        components.host = "topshelf"
        components.queryItems = [
            URLQueryItem(name: "path", value: "~/Documents/RetroArch/downloads/\(filename)"),
            URLQueryItem(name: "core_path", value: ":/Frameworks/\(core).framework/\(core)")
        ]
        return components.url
    }
}

enum ROMFolderScanner {
    static let maximumFiles = 10_000
    static let firmwareFilenames: Set<String> = [
        "aes.zip", "neogeo.zip", "neocd.zip", "neocdz.zip",
        "bios_cd_e.bin", "bios_cd_u.bin", "bios_cd_j.bin",
        "scph5500.bin", "scph5501.bin", "scph5502.bin",
        "mpr-17933.bin", "sega_101.bin", "dc_boot.bin", "dc_flash.bin",
        "aes_keys.txt", "seeddb.bin"
    ]

    static func scan(_ root: URL, allowedExtensions: Set<String> = PocketRules.extensions) throws -> ROMFolderScan {
        try CoordinatedFileAccess.read(root) { coordinatedRoot in
            try scanContents(coordinatedRoot, allowedExtensions: allowedExtensions)
        }
    }

    private static func scanContents(_ root: URL, allowedExtensions: Set<String>) throws -> ROMFolderScan {
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
                  !firmwareFilenames.contains(file.lastPathComponent.lowercased()),
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

enum ROMExportStager {
    static func stage(source: URL, filename: String, root: URL, id: UUID) throws -> URL {
        let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        var destination = directory.appendingPathComponent(filename, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try CoordinatedFileAccess.read(source) { coordinatedSource in
                let values = try coordinatedSource.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else {
                    throw PocketError.message("A ROM não está mais disponível na pasta escolhida.")
                }
                try FileManager.default.copyItem(at: coordinatedSource, to: destination)
            }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? destination.setResourceValues(values)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    static func stageDiscSet(source: URL, filename: String, root: URL, id: UUID) throws -> URL {
        let main = try stage(source: source, filename: filename, root: root, id: id)
        var visited: Set<String> = [filename.lowercased()]
        do {
            try copyReferences(from: source, to: main.deletingLastPathComponent(), visited: &visited)
            return main
        } catch {
            // Remove only this invocation's private staging directory, never the source.
            try? FileManager.default.removeItem(at: main.deletingLastPathComponent())
            throw error
        }
    }

    private static func copyReferences(from descriptor: URL, to destination: URL, visited: inout Set<String>) throws {
        let ext = descriptor.pathExtension.lowercased()
        guard ["cue", "m3u", "gdi"].contains(ext) else { return }
        let text = try CoordinatedFileAccess.read(descriptor) { url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0, size <= 1_048_576 else {
                throw PocketError.message("O descritor de disco é inválido ou grande demais.")
            }
            return String(decoding: try Data(contentsOf: url), as: UTF8.self)
        }
        let references: [String]
        if ext == "m3u" {
            references = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        } else {
            let pattern = ext == "cue"
                ? #"(?im)^\s*FILE\s+(?:\"([^\"]+)\"|(\S+))"#
                : #"(?m)^\s*\d+\s+\d+\s+\d+\s+\d+\s+(?:\"([^\"]+)\"|(\S+))"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            references = regex.matches(in: text, range: range).compactMap { match in
                for index in 1..<match.numberOfRanges where match.range(at: index).location != NSNotFound {
                    if let range = Range(match.range(at: index), in: text) { return String(text[range]) }
                }
                return nil
            }
        }
        for reference in references {
            let name = (reference as NSString).lastPathComponent
            guard name == reference, PocketRules.safeFilename(name) else {
                throw PocketError.message("O descritor de disco contém um caminho externo não permitido: \(reference)")
            }
            let key = name.lowercased()
            if !visited.insert(key).inserted { continue }
            let source = descriptor.deletingLastPathComponent().appendingPathComponent(name)
            let target = destination.appendingPathComponent(name)
            try CoordinatedFileAccess.read(source) { url in
                let sourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard sourceValues.isRegularFile == true, sourceValues.isSymbolicLink != true, (sourceValues.fileSize ?? 0) > 0 else {
                    throw PocketError.message("Faixa ou disco referenciado não encontrado: \(name)")
                }
                try FileManager.default.copyItem(at: url, to: target)
            }
            try copyReferences(from: source, to: destination, visited: &visited)
        }
    }
}

actor ROMFolderAccess {
    private let bookmarkKey = "brumclassics-ios-rom-folder-bookmark-v1"
    private let nameKey = "brumclassics-ios-rom-folder-name-v1"
    private var activeShares: [UUID: (root: URL, accessing: Bool)] = [:]

    private var exportRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RetroArchExports", isDirectory: true)
    }

    private var integratedRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IntegratedPlay", isDirectory: true)
    }

    private var systemRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IntegratedEmulator/System", isDirectory: true)
    }

    var configured: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }
    var displayName: String { UserDefaults.standard.string(forKey: nameKey) ?? "Downloads" }

    func configure(_ folder: URL) throws -> ROMFolderScan {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        try installNeoGeoFirmware(in: folder)
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
        try installNeoGeoFirmware(in: folder)
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
        // A security-scoped permission belongs only to BRUMCLASSICS. Passing the
        // provider URL directly makes another app receive a path it cannot read.
        // Stage a private copy first so UIActivityViewController can vend a normal
        // document URL to RetroArch, including the App Store build.
        let shareID = UUID()
        let exportDirectory = exportRoot.appendingPathComponent(shareID.uuidString, isDirectory: true)
        let exportedFile: URL
        do {
            if stale {
                let refreshed = try root.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
            try removeExpiredExports()
            exportedFile = try ROMExportStager.stage(source: file, filename: game.filename, root: exportRoot, id: shareID)
        } catch {
            try? FileManager.default.removeItem(at: exportDirectory)
            if accessing { root.stopAccessingSecurityScopedResource() }
            throw PocketError.message("Não foi possível preparar uma cópia autorizada da ROM. Se ela estiver no iCloud, baixe o arquivo no iPhone e tente novamente.")
        }
        let ticket = ROMShareTicket(id: shareID, url: exportedFile, title: game.title, filename: game.filename)
        activeShares[ticket.id] = (root, accessing)
        return ticket
    }

    func stageForIntegratedPlay(_ game: ROMFolderGame) throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw PocketError.message("Selecione novamente a pasta de ROMs.")
        }
        var stale = false
        let root = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale).standardizedFileURL
        let accessing = root.startAccessingSecurityScopedResource()
        defer { if accessing { root.stopAccessingSecurityScopedResource() } }
        let source = root.appendingPathComponent(game.relativePath).standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard source.path.hasPrefix(prefix), source.lastPathComponent == game.filename else {
            throw PocketError.message("O caminho da ROM não pertence mais à pasta autorizada.")
        }
        try installNeoGeoFirmware(in: root)
        let system = IntegratedEmulatorSupport.system(for: game)
        if system == .neoGeo && !hasFirmware(["aes.zip", "neogeo.zip"]) {
            throw PocketError.message("Para iniciar Neo Geo, coloque aes.zip ou neogeo.zip na pasta de jogos. O BRUM Core copia somente a BIOS fornecida por você e não distribui arquivos protegidos.")
        }
        if system == .segaCD && !hasFirmware(["bios_cd_e.bin", "bios_cd_u.bin", "bios_cd_j.bin"]) {
            throw PocketError.message("Para iniciar Sega CD, coloque a BIOS da sua região (bios_CD_E.bin, bios_CD_U.bin ou bios_CD_J.bin) na pasta de jogos.")
        }
        if system == .playStation && !hasFirmware(["scph5500.bin", "scph5501.bin", "scph5502.bin"]) {
            throw PocketError.message("Para iniciar PS1, coloque uma BIOS válida (scph5500.bin, scph5501.bin ou scph5502.bin) na pasta de jogos.")
        }
        if system == .saturn && !hasFirmware(["mpr-17933.bin", "sega_101.bin"]) {
            throw PocketError.message("Para iniciar Saturn, coloque mpr-17933.bin ou sega_101.bin na pasta de jogos.")
        }
        try removeExpiredFiles(in: integratedRoot)
        do {
            if stale {
                let refreshed = try root.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
            return try ROMExportStager.stageDiscSet(source: source, filename: game.filename, root: integratedRoot, id: UUID())
        } catch {
            throw PocketError.message("Não foi possível preparar a ROM: \(error.localizedDescription). Se estiver no iCloud, baixe todos os arquivos do jogo; se necessário, reautorize a pasta em Configurações → CLASSICS.")
        }
    }

    func finishShare(_ id: UUID) {
        guard let share = activeShares.removeValue(forKey: id) else { return }
        if share.accessing { share.root.stopAccessingSecurityScopedResource() }
    }

    private func hasNeoGeoCartridgeFirmware() -> Bool {
        hasFirmware(["aes.zip", "neogeo.zip"])
    }

    private func hasFirmware(_ names: [String]) -> Bool {
        names.contains { FileManager.default.fileExists(atPath: systemRoot.appendingPathComponent($0).path) }
    }

    private func installNeoGeoFirmware(in root: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: systemRoot, withIntermediateDirectories: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        var inspected = 0
        for case let source as URL in enumerator {
            inspected += 1
            if inspected > ROMFolderScanner.maximumFiles { break }
            let filename = source.lastPathComponent.lowercased()
            guard ROMFolderScanner.firmwareFilenames.contains(filename) else { continue }
            let values = try source.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size > 0, size <= 64 * 1_024 * 1_024 else { continue }
            var destination = systemRoot.appendingPathComponent(filename)
            if let installedSize = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               installedSize == size { continue }
            let data = try CoordinatedFileAccess.read(source) { try Data(contentsOf: $0, options: .mappedIfSafe) }
            guard data.count == size else { continue }
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
            var destinationValues = URLResourceValues()
            destinationValues.isExcludedFromBackup = true
            try? destination.setResourceValues(destinationValues)
        }
    }

    private func removeExpiredExports(now: Date = Date()) throws {
        try removeExpiredFiles(in: exportRoot, now: now)
    }

    private func removeExpiredFiles(in directory: URL, now: Date = Date()) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let children = try manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let expiration = now.addingTimeInterval(-24 * 60 * 60)
        for child in children {
            let date = try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            guard let date else { try? manager.removeItem(at: child); continue }
            if date < expiration { try? manager.removeItem(at: child) }
        }
    }
}
