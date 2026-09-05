import Foundation
import UIKit

struct RetroArchLibraryGame: Codable, Equatable, Identifiable {
    var titleId: String
    var titleName: String
    var filename: String
    var gameId: String
    var developer: String?
    var version: String?
    var system: String?
    var coreName: String?
    var id: String { titleId }
}

enum RetroArchLibraryRules {
    static let maximumCallbackCharacters = 8_000_000
    static let maximumGames = 10_000

    static func queryURL() -> URL {
        var components = URLComponents()
        components.scheme = "retroarch"
        components.host = "library"
        components.queryItems = [URLQueryItem(name: "scheme", value: "brumclassics")]
        return components.url!
    }

    static func decode(_ url: URL) throws -> [RetroArchLibraryGame] {
        guard url.scheme?.lowercased() == "brumclassics", url.host?.lowercased() == "retroarch",
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "games" })?.value,
              !encoded.isEmpty, encoded.count <= maximumCallbackCharacters else {
            throw PocketError.message("Resposta da biblioteca do RetroArch inválida.")
        }
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), data.count <= 6_000_000 else { throw PocketError.message("Biblioteca do RetroArch grande demais ou corrompida.") }
        let decoded = try JSONDecoder().decode([RetroArchLibraryGame].self, from: data)
        guard decoded.count <= maximumGames else { throw PocketError.message("A biblioteca excede o limite de segurança.") }
        let counts = Dictionary(grouping: decoded, by: { $0.titleId.lowercased() }).mapValues(\.count)
        return decoded.compactMap { game in
            let titleId = game.titleId.trimmingCharacters(in: .whitespacesAndNewlines)
            let filename = game.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = game.titleName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard titleId == filename, PocketRules.safeFilename(titleId), !title.isEmpty,
                  titleId.count <= 500, title.count <= 500, counts[titleId.lowercased()] == 1 else { return nil }
            var clean = game; clean.titleId = titleId; clean.filename = filename; clean.titleName = title
            clean.gameId = String(game.gameId.prefix(300)); clean.system = game.system.map { String($0.prefix(120)) }; clean.coreName = game.coreName.map { String($0.prefix(120)) }
            return clean
        }
    }

    static func launchURL(titleId: String) -> URL? { PocketRules.launchURL(titleId) }

    static func normalizedTitle(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }
}

actor RetroArchLibraryFiles {
    private let file: URL
    init(root: URL? = nil) {
        let directory = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClassicsEverywhere", isDirectory: true)
        // v2 intentionally invalidates links recorded before ROMs were staged in
        // our sandbox. Those stale links survive a RetroArch reinstall and can
        // make the App Store build receive the old inaccessible path again.
        file = directory.appendingPathComponent("retroarch-library-v2.json")
    }
    func load() throws -> [RetroArchLibraryGame] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([RetroArchLibraryGame].self, from: Data(contentsOf: file))
    }
    func save(_ games: [RetroArchLibraryGame]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(games).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
