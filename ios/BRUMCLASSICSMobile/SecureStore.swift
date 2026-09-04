import Foundation
import Security

enum SecureStore {
    private static let service = "com.brumclassics.mobile.ios"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) throws {
        let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(key as CFDictionary)
        var item = key
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    static func remove(_ account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

struct PairingConfiguration: Codable, Equatable {
    var host: String
    var port: Int
    var fingerprint: String
    var deviceID: String
    var deviceName: String
}

actor OfflineStore {
    private let root: URL
    private let snapshotURL: URL
    private let outboxURL: URL
    private let artworkDirectory: URL
    private let momentsDirectory: URL
    private let momentsURL: URL

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rootURL = support.appendingPathComponent("BRUMCLASSICS", isDirectory: true)
        root = rootURL
        snapshotURL = rootURL.appendingPathComponent("library.json")
        outboxURL = rootURL.appendingPathComponent("outbox.json")
        artworkDirectory = rootURL.appendingPathComponent("artwork", isDirectory: true)
        momentsDirectory = rootURL.appendingPathComponent("moments", isDirectory: true)
        momentsURL = momentsDirectory.appendingPathComponent("index.json")
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: momentsDirectory, withIntermediateDirectories: true)
    }

    func loadSnapshot() -> LibrarySnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(LibrarySnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: LibrarySnapshot) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func loadOutbox() -> [PendingMutation] {
        guard let data = try? Data(contentsOf: outboxURL) else { return [] }
        return (try? JSONDecoder().decode([PendingMutation].self, from: data)) ?? []
    }

    func saveOutbox(_ mutations: [PendingMutation]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(mutations)
        try data.write(to: outboxURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func artworkURL(for game: Game) -> URL {
        artworkDirectory.appendingPathComponent(Self.stableKey(game.id + "|" + game.artworkPath) + ".img")
    }

    func cachedArtwork(for game: Game) -> Data? { try? Data(contentsOf: artworkURL(for: game)) }

    func saveArtwork(_ data: Data, for game: Game) throws {
        guard data.count <= 20 * 1024 * 1024 else { throw BridgeError.invalidResponse("A capa excede o limite permitido.") }
        try data.write(to: artworkURL(for: game), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func pruneArtwork(keeping games: [Game]) {
        let retained = Set(games.filter { !$0.artworkPath.isEmpty }.map { Self.stableKey($0.id + "|" + $0.artworkPath) + ".img" })
        let files = (try? FileManager.default.contentsOfDirectory(at: artworkDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !retained.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
    }

    func loadMoments() -> [BrumMoment] {
        guard let data = try? Data(contentsOf: momentsURL) else { return [] }
        return (try? JSONDecoder().decode([BrumMoment].self, from: data)) ?? []
    }

    func momentImage(_ moment: BrumMoment) -> Data? { try? Data(contentsOf: momentsDirectory.appendingPathComponent(moment.imageFile)) }

    func saveMoment(data: Data, gameID: String, gameTitle: String, capturedAt: String) throws -> BrumMoment {
        guard data.count >= 8, data.count <= 40 * 1024 * 1024 else { throw BridgeError.invalidResponse("A captura recebida é inválida.") }
        var moments = loadMoments()
        let id = UUID(); let file = id.uuidString + ".png"
        try data.write(to: momentsDirectory.appendingPathComponent(file), options: [.atomic, .completeFileProtectionUnlessOpen])
        let moment = BrumMoment(id: id, gameID: gameID, gameTitle: gameTitle, capturedAt: capturedAt, imageFile: file, location: "", note: "", category: "MOMENTO", favorite: false)
        moments.insert(moment, at: 0); try saveMoments(moments); return moment
    }

    func updateMoment(_ moment: BrumMoment) throws {
        var moments = loadMoments(); guard let index = moments.firstIndex(where: { $0.id == moment.id }) else { return }
        moments[index] = moment; try saveMoments(moments)
    }

    func removeMoment(_ moment: BrumMoment) throws {
        var moments = loadMoments(); moments.removeAll { $0.id == moment.id }
        try? FileManager.default.removeItem(at: momentsDirectory.appendingPathComponent(moment.imageFile)); try saveMoments(moments)
    }

    private func saveMoments(_ moments: [BrumMoment]) throws {
        try JSONEncoder().encode(moments).write(to: momentsURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private static func stableKey(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}

enum MutationKind: String, Codable { case notes, libraryState }

struct PendingMutation: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: MutationKind
    let gameID: String
    let revision: Int
    let force: Bool
    let notes: Game.Notes?
    let favorite: Bool?
    let wantToPlay: Bool?
    let queuedAt: Date
    var baseNotes: Game.Notes?
}
