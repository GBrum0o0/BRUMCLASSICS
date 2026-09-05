import Foundation
import CryptoKit
import ImageIO

enum ROMArtworkRules {
    static func repository(filename: String) -> String? {
        switch (filename as NSString).pathExtension.lowercased() {
        case "gba": return "Nintendo_-_Game_Boy_Advance"
        case "gb": return "Nintendo_-_Game_Boy"
        case "gbc": return "Nintendo_-_Game_Boy_Color"
        case "nes": return "Nintendo_-_Nintendo_Entertainment_System"
        case "sfc", "smc": return "Nintendo_-_Super_Nintendo_Entertainment_System"
        case "n64", "z64", "v64": return "Nintendo_-_Nintendo_64"
        case "nds": return "Nintendo_-_Nintendo_DS"
        case "md", "gen": return "Sega_-_Mega_Drive_-_Genesis"
        case "sms": return "Sega_-_Master_System_-_Mark_III"
        case "gg": return "Sega_-_Game_Gear"
        case "pce": return "NEC_-_PC_Engine_-_TurboGrafx_16"
        default: return nil
        }
    }

    static func match(filename: String, paths: [String]) -> String? {
        let wanted = RetroArchLibraryRules.normalizedTitle(ROMTitleRules.clean(filename))
        guard !wanted.isEmpty else { return nil }
        // Boxart identity is cosmetic only; it never establishes an achievement or PC ownership link.
        let candidates = paths.filter {
            $0.hasPrefix("Named_Boxarts/") && $0.hasSuffix(".png") &&
            $0.split(separator: "/").count == 2 &&
            RetroArchLibraryRules.normalizedTitle(ROMTitleRules.clean(($0 as NSString).lastPathComponent)) == wanted
        }
        let region: String? = filename.range(of: #"\((?:U|USA)(?:\)|,)"#, options: .regularExpression) != nil ? "USA" :
            filename.range(of: #"\((?:E|Europe)(?:\)|,)"#, options: .regularExpression) != nil ? "Europe" :
            filename.range(of: #"\((?:J|Japan)(?:\)|,)"#, options: .regularExpression) != nil ? "Japan" : nil
        let sorted = candidates.sorted()
        if let region, let regional = sorted.first(where: { $0.contains(region) }) { return regional }
        return sorted.first
    }
}

struct ROMArtwork: Codable {
    let title: String
    let imageURL: URL
}

actor ROMArtworkCache {
    static let shared = ROMArtworkCache()
    private struct Index: Codable { let date: Date; let paths: [String] }
    private struct Tree: Decodable {
        struct Entry: Decodable { let path: String; let type: String }
        let tree: [Entry]
        let truncated: Bool
    }
    private let root: URL
    private let session: URLSession
    private var indexes: [String: Index] = [:]
    private var pendingIndexes: [String: Task<Index, Error>] = [:]
    private var lastAttempt: [String: Date] = [:]

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassicsEverywhere/artwork", isDirectory: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration)
    }

    private func index(repository: String) async throws -> Index {
        let file = root.appendingPathComponent(repository + ".json")
        if indexes[repository] == nil, let bytes = try? Data(contentsOf: file) {
            indexes[repository] = try? JSONDecoder().decode(Index.self, from: bytes)
        }
        if let cached = indexes[repository], Date().timeIntervalSince(cached.date) < 7 * 86_400 { return cached }
        if let pending = pendingIndexes[repository] { return try await pending.value }
        if let attempted = lastAttempt[repository], Date().timeIntervalSince(attempted) < 300 {
            if let cached = indexes[repository] { return cached }
            throw URLError(.resourceUnavailable)
        }
        lastAttempt[repository] = Date()
        let session = session
        let task = Task<Index, Error> {
            let url = URL(string: "https://api.github.com/repos/libretro-thumbnails/\(repository)/git/trees/master?recursive=1")!
            var request = URLRequest(url: url)
            request.setValue("BRUMCLASSICS-iOS/0.7.3", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 12_000_000 else { throw URLError(.badServerResponse) }
            let tree = try JSONDecoder().decode(Tree.self, from: data)
            guard !tree.truncated else { throw URLError(.cannotParseResponse) }
            return Index(date: Date(), paths: tree.tree.filter { $0.type == "blob" && $0.path.hasPrefix("Named_Boxarts/") && $0.path.hasSuffix(".png") }.map(\.path))
        }
        pendingIndexes[repository] = task
        defer { pendingIndexes[repository] = nil }
        do {
            let result = try await task.value
            indexes[repository] = result
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try? JSONEncoder().encode(result).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
            return result
        } catch {
            if let cached = indexes[repository] { return cached }
            throw error
        }
    }

    func artwork(for rom: ROMFolderGame) async -> ROMArtwork? {
        guard let repository = ROMArtworkRules.repository(filename: rom.filename) else { return nil }
        let key = SHA256.hash(data: Data((repository + ":" + rom.filename).utf8)).map { String(format: "%02x", $0) }.joined()
        let metadataFile = root.appendingPathComponent(key + ".json")
        let imageFile = root.appendingPathComponent(key + ".png")
        if let data = try? Data(contentsOf: metadataFile), let cached = try? JSONDecoder().decode(ROMArtwork.self, from: data),
           FileManager.default.fileExists(atPath: imageFile.path) {
            return ROMArtwork(title: cached.title, imageURL: imageFile)
        }
        do {
            let catalog = try await index(repository: repository)
            guard let path = ROMArtworkRules.match(filename: rom.filename, paths: catalog.paths) else { return nil }
            let url = URL(string: "https://raw.githubusercontent.com/libretro-thumbnails/\(repository)/master/")!.appendingPathComponent(path)
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 8_000_000,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024] as CFDictionary) else { return nil }
            let resized = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(resized, "public.png" as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try (resized as Data).write(to: imageFile, options: [.atomic, .completeFileProtectionUnlessOpen])
            let metadata = ROMArtwork(title: ROMTitleRules.clean((path as NSString).lastPathComponent), imageURL: imageFile)
            try JSONEncoder().encode(metadata).write(to: metadataFile, options: [.atomic, .completeFileProtectionUnlessOpen])
            return metadata
        } catch { return nil }
    }
}
