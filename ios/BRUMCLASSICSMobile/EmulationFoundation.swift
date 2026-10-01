import CryptoKit
import Foundation

enum EmulatedSystemID: String, Codable, CaseIterable, Sendable {
    case gameBoy = "gb"
    case gameBoyColor = "gbc"
    case gameBoyAdvance = "gba"
}

enum ROMDetectionSource: String, Codable, Sendable {
    case header
    case extensionFallback = "extension"
}

struct CanonicalGameIdentity: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let systemID: EmulatedSystemID
    let contentSHA256: String
    let detectionSource: ROMDetectionSource

    var canonicalGameID: String {
        "classic:\(systemID.rawValue):sha256:\(contentSHA256)"
    }
}

struct CoreDescriptor: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let version: String
    let license: String
    let supportedSystems: Set<EmulatedSystemID>
}

enum CoreRegistry {
    static let mgba = CoreDescriptor(
        id: "mgba",
        displayName: "mGBA",
        version: "7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6",
        license: "MPL-2.0",
        supportedSystems: [.gameBoy, .gameBoyColor, .gameBoyAdvance]
    )

    static let all = [mgba]

    static func core(for system: EmulatedSystemID) -> CoreDescriptor? {
        all.first { $0.supportedSystems.contains(system) }
    }
}

struct EmulationLaunchDescriptor: Equatable, Sendable {
    let romURL: URL
    let title: String
    let identity: CanonicalGameIdentity
    let core: CoreDescriptor
    let legacySaveBasename: String

    var saveIdentifier: String {
        "\(identity.systemID.rawValue)-\(identity.contentSHA256)"
    }
}

enum ROMContentInspector {
    private static let gameBoyLogo: [UInt8] = [
        0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
        0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
        0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E
    ]

    static func inspect(url: URL, filename: String) throws -> CanonicalGameIdentity {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        var header = Data()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            if header.count < 512 {
                header.append(chunk.prefix(512 - header.count))
            }
            hasher.update(data: chunk)
        }
        guard !header.isEmpty else {
            throw PocketError.message("A ROM está vazia e não pode ser identificada.")
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let detected = detectSystem(header: header, filename: filename)
        guard let detected else {
            throw PocketError.message("O formato desta ROM ainda não é reconhecido pelo BRUM Core.")
        }
        return CanonicalGameIdentity(systemID: detected.system, contentSHA256: digest, detectionSource: detected.source)
    }

    static func detectSystem(header: Data, filename: String) -> (system: EmulatedSystemID, source: ROMDetectionSource)? {
        let bytes = [UInt8](header)
        if bytes.count > 0x143,
           Array(bytes[0x104...0x133]) == gameBoyLogo {
            let colorFlag = bytes[0x143]
            let system: EmulatedSystemID = colorFlag == 0x80 || colorFlag == 0xC0 ? .gameBoyColor : .gameBoy
            return (system, .header)
        }
        if bytes.count > 0xB2, bytes[0xB2] == 0x96 {
            return (.gameBoyAdvance, .header)
        }

        switch (filename as NSString).pathExtension.lowercased() {
        case "gb": return (.gameBoy, .extensionFallback)
        case "gbc": return (.gameBoyColor, .extensionFallback)
        case "gba": return (.gameBoyAdvance, .extensionFallback)
        default: return nil
        }
    }
}

enum EmulationLaunchBuilder {
    static func prepare(romURL: URL, title: String, originalFilename: String) throws -> EmulationLaunchDescriptor {
        let identity = try ROMContentInspector.inspect(url: romURL, filename: originalFilename)
        guard let core = CoreRegistry.core(for: identity.systemID) else {
            throw PocketError.message("Nenhum núcleo compatível está instalado para este sistema.")
        }
        return EmulationLaunchDescriptor(
            romURL: romURL,
            title: title,
            identity: identity,
            core: core,
            legacySaveBasename: (originalFilename as NSString).deletingPathExtension
        )
    }
}

struct SaveManifest: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let canonicalGameID: String
    let systemID: String
    let coreID: String
    let slot: String
    let generation: Int
    let payloadSHA256: String
    let sizeBytes: Int
    let updatedAt: Date
    let deviceID: String
    let formatVersion: Int

    static func next(
        previous: SaveManifest?,
        identity: CanonicalGameIdentity,
        coreID: String,
        payloadSHA256: String,
        sizeBytes: Int,
        deviceID: String,
        updatedAt: Date = Date()
    ) -> SaveManifest {
        let unchanged = previous?.payloadSHA256 == payloadSHA256
        return SaveManifest(
            schemaVersion: schemaVersion,
            canonicalGameID: identity.canonicalGameID,
            systemID: identity.systemID.rawValue,
            coreID: coreID,
            slot: "battery",
            generation: unchanged ? (previous?.generation ?? 1) : (previous?.generation ?? 0) + 1,
            payloadSHA256: payloadSHA256,
            sizeBytes: sizeBytes,
            updatedAt: unchanged ? (previous?.updatedAt ?? updatedAt) : updatedAt,
            deviceID: deviceID,
            formatVersion: 1
        )
    }
}
