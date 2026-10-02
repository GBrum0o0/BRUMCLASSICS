import CryptoKit
import Foundation

enum EmulatedSystemID: String, Codable, CaseIterable, Sendable {
    case gameBoy = "gb"
    case gameBoyColor = "gbc"
    case gameBoyAdvance = "gba"
    case nintendoDS = "nds"
    case neoGeo = "neogeo"
    case masterSystem = "sms"
    case gameGear = "gg"
    case nintendoEntertainmentSystem = "nes"
    case pcEngine = "pce"
    case superNintendo = "sfc"
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
    let libraryName: String
    let supportedSystems: Set<EmulatedSystemID>
}

enum CoreRegistry {
    static let mgba = CoreDescriptor(
        id: "mgba",
        displayName: "mGBA",
        version: "7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6",
        license: "MPL-2.0",
        libraryName: "mgba_libretro_ios.dylib",
        supportedSystems: [.gameBoy, .gameBoyColor, .gameBoyAdvance]
    )

    static let skyEmu = CoreDescriptor(
        id: "skyemu",
        displayName: "SkyEmu",
        version: "36771a16bfde7eb5c1c0315877b5e465e6f38858",
        license: "MIT",
        libraryName: "skyemu_libretro_ios.dylib",
        supportedSystems: [.nintendoDS]
    )

    static let geolith = CoreDescriptor(
        id: "geolith",
        displayName: "Geolith",
        version: "194024931935eff2092e36fc4f8e53e62ed11097",
        license: "BSD-3-Clause",
        libraryName: "geolith_libretro_ios.dylib",
        supportedSystems: [.neoGeo]
    )

    static let gearsystem = CoreDescriptor(
        id: "gearsystem",
        displayName: "Gearsystem",
        version: "2d9106f2063d1a6e0661cc8938bb7f8eb737bcae",
        license: "GPL-3.0-or-later",
        libraryName: "gearsystem_libretro_ios.dylib",
        supportedSystems: [.masterSystem, .gameGear]
    )

    static let nestopia = CoreDescriptor(
        id: "nestopia",
        displayName: "Nestopia UE",
        version: "8f00f500912a847062de432e38765c7285483e62",
        license: "GPL-2.0-or-later",
        libraryName: "nestopia_libretro_ios.dylib",
        supportedSystems: [.nintendoEntertainmentSystem]
    )

    static let beetlePCEFast = CoreDescriptor(
        id: "beetle-pce-fast",
        displayName: "Beetle PCE Fast",
        version: "3f946f277aef3aa99a95551618bbcd1dd2bda0d9",
        license: "GPL-2.0-or-later",
        libraryName: "mednafen_pce_fast_libretro_ios.dylib",
        supportedSystems: [.pcEngine]
    )

    static let bsnesMercury = CoreDescriptor(
        id: "bsnes-mercury-performance",
        displayName: "bsnes-mercury Performance",
        version: "79d7f9de218b6ffa65a80bbdc5828532bc239232",
        license: "GPL-3.0",
        libraryName: "bsnes_mercury_performance_libretro_ios.dylib",
        supportedSystems: [.superNintendo]
    )

    static let all = [mgba, skyEmu, geolith, gearsystem, nestopia, beetlePCEFast, bsnesMercury]

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
        case "nds": return (.nintendoDS, .extensionFallback)
        case "neo": return (.neoGeo, .extensionFallback)
        case "sms": return (.masterSystem, .extensionFallback)
        case "gg": return (.gameGear, .extensionFallback)
        case "nes": return (.nintendoEntertainmentSystem, .extensionFallback)
        case "pce": return (.pcEngine, .extensionFallback)
        case "sfc", "smc": return (.superNintendo, .extensionFallback)
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
