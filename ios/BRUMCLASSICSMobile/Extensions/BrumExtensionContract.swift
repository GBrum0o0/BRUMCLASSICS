import Foundation

enum BrumExtensionError: LocalizedError, Equatable {
    case invalidManifest(String)
    case dynamicCodeExecutionForbidden
    case unknownPermission(String)
    case extensionNotFound(String)
    case invalidProfileID

    var errorDescription: String? {
        switch self {
        case .invalidManifest(let detail): return "Manifesto de extensão inválido: \(detail)"
        case .dynamicCodeExecutionForbidden: return "Política de segurança iOS: execução arbitrária de código baixado não é permitida."
        case .unknownPermission(let perm): return "Permissão não reconhecida na extensão: \(perm)"
        case .extensionNotFound(let id): return "Extensão não encontrada: \(id)"
        case .invalidProfileID: return "Identificador de perfil inválido."
        }
    }
}

struct BrumExtensionUIContract: Codable, Equatable {
    let section: String
    let entryPoint: String
    let initialState: String
    let openAnimation: String
    let orientation: String
    let tabs: [String]
}

struct BrumExtensionManifest: Codable, Equatable, Identifiable {
    static let allowedPermissions: Set<String> = [
        "brum-core:events.read",
        "brum-core:memory.read",
        "storage:isolated.readwrite",
        "sync:lan.readwrite",
        "gamepad:ui.extension",
        "notifications:discovery.emit"
    ]

    let id: String
    let number: String
    let schemaVersion: Int
    let version: String
    let title: String
    let shortTitle: String
    let description: String
    let category: String
    let codeExecutionPolicy: String
    let defaultEnabled: Bool
    let permissions: [String]
    let capabilities: [String]
    let platforms: [String]
    let uiContract: BrumExtensionUIContract

    func validate() throws {
        guard schemaVersion == 1 else {
            throw BrumExtensionError.invalidManifest("schemaVersion \(schemaVersion) não suportado.")
        }
        guard codeExecutionPolicy == "native-compiled-only" else {
            throw BrumExtensionError.dynamicCodeExecutionForbidden
        }
        let idPattern = #"^[a-z0-9]+(?:\.[a-z0-9_-]+){2,6}$"#
        guard id.range(of: idPattern, options: .regularExpression) != nil else {
            throw BrumExtensionError.invalidManifest("id inválido: \(id)")
        }
        let verPattern = #"^\d+\.\d+\.\d+$"#
        guard version.range(of: verPattern, options: .regularExpression) != nil else {
            throw BrumExtensionError.invalidManifest("versão inválida: \(version)")
        }
        for perm in permissions where !Self.allowedPermissions.contains(perm) {
            throw BrumExtensionError.unknownPermission(perm)
        }
    }

    static let pokedexUniversal = BrumExtensionManifest(
        id: "brum.ext.pokedex",
        number: "001",
        schemaVersion: 1,
        version: "1.0.0",
        title: "Pokédex Universal",
        shortTitle: "Pokédex",
        description: "Coleção permanente e sincronizada de Pokémon descobertos pelo jogador no ecossistema Brum Classics.",
        category: "gamepad-extension",
        codeExecutionPolicy: "native-compiled-only",
        defaultEnabled: true,
        permissions: [
            "brum-core:events.read",
            "brum-core:memory.read",
            "storage:isolated.readwrite",
            "sync:lan.readwrite",
            "gamepad:ui.extension",
            "notifications:discovery.emit"
        ],
        capabilities: [
            "universal-collection",
            "normal-and-shiny-tabs",
            "automatic-capture-detection",
            "offline-first-lan-sync",
            "verified-backup-restore",
            "discovery-notifications"
        ],
        platforms: ["windows", "ios", "android"],
        uiContract: BrumExtensionUIContract(
            section: "Extensões",
            entryPoint: "brum.ext.pokedex",
            initialState: "closed-device",
            openAnimation: "pokedex-hinge-open",
            orientation: "horizontal-split",
            tabs: ["pokemon", "shinies"]
        )
    )
}

final class BrumExtensionRegistry {
    private let storageRoot: URL
    private var registered: [String: BrumExtensionManifest] = [:]

    init(storageRoot: URL? = nil) {
        if let storageRoot {
            self.storageRoot = storageRoot
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageRoot = appSupport.appendingPathComponent("Extensions", isDirectory: true)
        }
    }

    @discardableResult
    func register(_ manifest: BrumExtensionManifest) throws -> BrumExtensionManifest {
        try manifest.validate()
        registered[manifest.id] = manifest
        return manifest
    }

    func isolatedStorageURL(for extensionID: String, profileID: String = "primary") throws -> URL {
        let trimmed = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
        let prof = trimmed.isEmpty ? "primary" : trimmed
        guard prof.range(of: #"^[a-zA-Z0-9_-]{1,100}$"#, options: .regularExpression) != nil else {
            throw BrumExtensionError.invalidProfileID
        }
        return storageRoot
            .appendingPathComponent(extensionID, isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(prof, isDirectory: true)
    }

    func isEnabled(_ extensionID: String, profileID: String = "primary") -> Bool {
        guard let manifest = registered[extensionID] else { return false }
        guard let url = try? isolatedStorageURL(for: extensionID, profileID: profileID).appendingPathComponent("enabled.json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabled = dict["enabled"] as? Bool else {
            return manifest.defaultEnabled
        }
        return enabled
    }

    func setEnabled(_ extensionID: String, enabled: Bool, profileID: String = "primary") throws {
        guard registered[extensionID] != nil else {
            throw BrumExtensionError.extensionNotFound(extensionID)
        }
        let dir = try isolatedStorageURL(for: extensionID, profileID: profileID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "extensionId": extensionID,
            "profileId": profileID,
            "enabled": enabled,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: dir.appendingPathComponent("enabled.json"), options: .atomic)
    }
}
