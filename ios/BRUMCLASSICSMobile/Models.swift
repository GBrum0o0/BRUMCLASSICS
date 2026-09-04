import Foundation

struct LibrarySnapshot: Codable, Equatable {
    var protocolVersion: Int
    var revision: Int
    var generatedAt: String
    var games: [Game]
    var collections: [GameCollection]
    var activity: [ActivityItem]
    var companion: CompanionState?
    var performance: PerformanceState?

    static let empty = LibrarySnapshot(protocolVersion: 8, revision: 0, generatedAt: "", games: [], collections: [], activity: [], companion: nil, performance: nil)
}

struct GameCollection: Codable, Identifiable, Equatable { let id: String; let name: String }

struct ActivityItem: Codable, Identifiable, Equatable {
    var id: String { "\(type ?? "activity"):\(timestamp ?? createdAt ?? ""):\(gameId ?? "")" }
    let type: String?
    let timestamp: String?
    let createdAt: String?
    let gameId: String?
    let gameTitle: String?
}

struct Game: Codable, Identifiable, Hashable {
    struct Achievement: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let description: String
        let points: Int
        let unlocked: Bool
        let hardcore: Bool?
        let unlockedAt: String
        let badgeUrl: String?
    }
    struct Notes: Codable, Hashable {
        var whereStopped: String
        var objectives: String
        var tips: String
        var commands: String
        var revision: Int
        var updatedAt: String
        static let empty = Notes(whereStopped: "", objectives: "", tips: "", commands: "", revision: 0, updatedAt: "")
        var hasContent: Bool { [whereStopped, objectives, tips, commands].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }

    let id: String
    let title: String
    let description: String
    let category: String
    let platform: String
    let store: String
    let genre: String
    let collectionId: String
    let sizeBytes: Int64
    let playtimeMinutes: Double?
    let playtimeAvailable: Bool
    let achievementsCollected: Int?
    let achievementsTotal: Int?
    let achievementsAvailable: Bool
    let achievements: [Achievement]
    let storyCompleted: Bool
    var favorite: Bool
    var wantToPlay: Bool
    let libraryStateRevision: Int
    var notes: Notes
    let installed: Bool
    let integrityStatus: String
    let lastPlayedAt: String
    let artworkPath: String

    var isClassic: Bool { category == "classic" }
    var achievementProgress: Int { guard let total = achievementsTotal, total > 0 else { return 0 }; return min(100, Int((Double(achievementsCollected ?? 0) / Double(total)) * 100)) }
    var playtimeLabel: String { guard playtimeAvailable, let raw = playtimeMinutes, raw.isFinite, raw >= 0, raw < Double(Int.max) else { return "INDISPONÍVEL" }; let value = Int(raw); return value >= 60 ? "\(value / 60) h \(value % 60) min" : "\(value) min" }
    var statusLabel: String { if storyCompleted { return "HISTÓRIA COMPLETADA" }; if wantToPlay { return "QUERO JOGAR" }; if (playtimeMinutes ?? 0) > 0 { return "JOGANDO" }; return installed ? "INSTALADO" : "NÃO INSTALADO" }
}

struct CompanionState: Codable, Equatable { let active: Bool; let gameId: String; let startedAt: String; let state: String }

struct PerformanceState: Codable, Equatable {
    struct CPU: Codable, Equatable { let available: Bool; let usagePercent: Double?; let temperatureC: Double? }
    struct GPU: Codable, Equatable { let available: Bool; let name: String; let usagePercent: Double?; let temperatureC: Double?; let memoryUsedBytes: Double?; let memoryTotalBytes: Double? }
    struct Memory: Codable, Equatable { let available: Bool; let usedBytes: Double?; let totalBytes: Double? }
    struct FPS: Codable, Equatable { let available: Bool; let value: Double? }
    struct ProcessMetrics: Codable, Equatable { let available: Bool; let cpuPercent: Double?; let ramBytes: Double? }
    let active: Bool
    let gameId: String
    let sampledAt: String
    let sessionSeconds: Double
    let cpu: CPU
    let gpu: GPU
    let memory: Memory
    let fps: FPS
    var process: ProcessMetrics?

    func isFresh(gameID: String?, connected: Bool, now: Date = Date()) -> Bool {
        guard connected, active, !gameId.isEmpty, gameId == gameID else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sampled = formatter.date(from: sampledAt) ?? ISO8601DateFormatter().date(from: sampledAt)
        guard let sampled else { return false }
        let age = now.timeIntervalSince(sampled)
        return age >= -30 && age < 20
    }
}

struct BrumMoment: Codable, Identifiable, Equatable {
    let id: UUID
    let gameID: String
    let gameTitle: String
    let capturedAt: String
    let imageFile: String
    var location: String
    var note: String
    var category: String
    var favorite: Bool
}

struct PairingPayload: Equatable {
    let host: String
    let port: Int
    let code: String
    let pin: String

    init?(url: URL) {
        guard url.scheme?.lowercased() == "brumclassics", url.host?.lowercased() == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.queryItems?.first(where: { $0.name == "host" })?.value,
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let pin = components.queryItems?.first(where: { $0.name == "pin" })?.value,
              code.range(of: #"^\d{6}$"#, options: .regularExpression) != nil else { return nil }
        self.host = host
        self.port = Int(components.queryItems?.first(where: { $0.name == "port" })?.value ?? "46991") ?? 46991
        self.code = code
        self.pin = pin
    }
}
