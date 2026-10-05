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
    case wonderSwan = "ws"
    case wonderSwanColor = "wsc"
    case nintendo64 = "n64"
    case megaDrive = "md"
    case segaCD = "segacd"
    case sega32X = "32x"
    case playStation = "psx"
    case playStationPortable = "psp"
    case dreamcast = "dreamcast"
    case saturn = "saturn"
    case arcade = "arcade"
    case atari2600 = "atari2600"
    case nintendo3DS = "3ds"
    case gameCube = "gamecube"
    case playStation2 = "ps2"
}

extension EmulatedSystemID {
    /// Numeric identifiers from the official rcheevos rc_consoles.h contract.
    var retroAchievementsConsoleID: UInt32 {
        switch self {
        case .megaDrive: return 1
        case .nintendo64: return 2
        case .superNintendo: return 3
        case .gameBoy: return 4
        case .gameBoyAdvance: return 5
        case .gameBoyColor: return 6
        case .nintendoEntertainmentSystem: return 7
        case .pcEngine: return 8
        case .segaCD: return 9
        case .sega32X: return 10
        case .masterSystem: return 11
        case .gameGear: return 15
        case .playStation: return 12
        case .playStation2: return 21
        case .gameCube: return 16
        case .nintendoDS: return 18
        case .neoGeo: return 27
        case .arcade: return 27
        case .atari2600: return 25
        case .saturn: return 39
        case .dreamcast: return 40
        case .playStationPortable: return 41
        case .wonderSwan, .wonderSwanColor: return 53
        case .nintendo3DS: return 62
        }
    }
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

    static let beetleWonderSwan = CoreDescriptor(
        id: "beetle-wswan",
        displayName: "Beetle WonderSwan",
        version: "4b01295838ea89e3f1355bbe4cb5cf98aa6108cd",
        license: "GPL-2.0-or-later",
        libraryName: "mednafen_wswan_libretro_ios.dylib",
        supportedSystems: [.wonderSwan, .wonderSwanColor]
    )

    static let mupen64PlusNext = CoreDescriptor(
        id: "mupen64plus-next", displayName: "Mupen64Plus-Next",
        version: "12edd2c74a517ff86dfa8cfc71ad75e4c10486d5", license: "GPL-2.0-or-later",
        libraryName: "mupen64plus_next_libretro_ios.dylib", supportedSystems: [.nintendo64]
    )



    static let beetlePSX = CoreDescriptor(
        id: "beetle-psx", displayName: "Beetle PSX",
        version: "5ec9909f2654fb2041315a13fac0b704c5065c0e", license: "GPL-2.0-or-later",
        libraryName: "mednafen_psx_libretro_ios.dylib", supportedSystems: [.playStation]
    )

    static let beetleSaturn = CoreDescriptor(
        id: "beetle-saturn", displayName: "Beetle Saturn",
        version: "65f05fa66f83e65e33be83aa433d883b4fd9509a", license: "GPL-2.0-or-later",
        libraryName: "mednafen_saturn_libretro_ios.dylib", supportedSystems: [.saturn]
    )


    static let stella2014 = CoreDescriptor(
        id: "stella2014", displayName: "Stella 2014",
        version: "7d1361e407e63f29e52892655069e5fb4096e691", license: "GPL-2.0-or-later",
        libraryName: "stella2014_libretro_ios.dylib", supportedSystems: [.atari2600]
    )

    static let ppsspp = CoreDescriptor(
        id: "ppsspp", displayName: "PPSSPP",
        version: "7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8", license: "GPL-2.0-or-later",
        libraryName: "ppsspp_libretro_ios.dylib", supportedSystems: [.playStationPortable]
    )

    static let flycast = CoreDescriptor(
        id: "flycast", displayName: "Flycast",
        version: "59ed35a7ea7c1940d4c8ac221a662d0e6d6dc9ea", license: "GPL-2.0-or-later",
        libraryName: "flycast_libretro_ios.dylib", supportedSystems: [.dreamcast]
    )

    static let citra = CoreDescriptor(
        id: "citra", displayName: "Citra",
        version: "a0483e9abe8134ae6b290cdca7d49cb77689f05b", license: "GPL-2.0-or-later",
        libraryName: "citra_libretro_ios.dylib", supportedSystems: [.nintendo3DS]
    )

    static let dolphin = CoreDescriptor(
        id: "dolphin", displayName: "Dolphin",
        version: "4d23cf151640eb810cb1b8e9d9fc922cf59c0b87", license: "GPL-2.0-or-later",
        libraryName: "dolphin_libretro_ios.dylib", supportedSystems: [.gameCube]
    )

    static let play = CoreDescriptor(
        id: "play", displayName: "Play!",
        version: "83700b2c31e593bc94e845b4b31b797be84dda59", license: "BSD-2-Clause",
        libraryName: "play_libretro_ios.dylib", supportedSystems: [.playStation2]
    )

    // A descriptor alone does not enable a backend. Preserve the existing release
    // while new engines pass independent builds and device acceptance tests.
    static let all = [mgba, skyEmu, geolith, gearsystem, nestopia, beetlePCEFast, bsnesMercury, beetleWonderSwan]
    static let candidates = [mupen64PlusNext, beetlePSX, beetleSaturn, stella2014, ppsspp, flycast, citra, dolphin, play]
    static let experimental = [mupen64PlusNext, beetlePSX, beetleSaturn, stella2014, ppsspp, flycast]
    static var experimentalBuild: Bool {
        Bundle.main.object(forInfoDictionaryKey: "BRUMExperimentalBackends") as? Bool == true
    }

    static func candidate(for system: EmulatedSystemID) -> CoreDescriptor? {
        candidates.first { $0.supportedSystems.contains(system) }
    }

    static func core(for system: EmulatedSystemID, includeExperimental: Bool = experimentalBuild) -> CoreDescriptor? {
        (all + (includeExperimental ? experimental : [])).first { $0.supportedSystems.contains(system) }
    }
}

struct EmulationLaunchDescriptor: Equatable, Sendable {
    let romURL: URL
    let title: String
    let identity: CanonicalGameIdentity
    let core: CoreDescriptor
    let legacySaveBasename: String
    let retroAchievementsGameID: Int

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

    static func inspect(url: URL, filename: String, expectedSystem: EmulatedSystemID? = nil) throws -> CanonicalGameIdentity {
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

        if ["cue", "m3u", "gdi"].contains(url.pathExtension.lowercased()) {
            // Versioned disc-set hash; cartridge identities remain unchanged.
            var discHasher = SHA256()
            discHasher.update(data: Data("BRUM-DISC-SET-v1\0".utf8))
            for file in try ROMExportStager.contentFiles(for: url) {
                let input = try FileHandle(forReadingFrom: file)
                defer { try? input.close() }
                var fileHasher = SHA256()
                while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty { fileHasher.update(data: chunk) }
                discHasher.update(data: Data(fileHasher.finalize()))
            }
            hasher = discHasher
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        // A folder hint must not override a ROM header or an unambiguous format.
        let detected = detectSystem(header: header, filename: filename)
            ?? expectedSystem.map { (system: $0, source: ROMDetectionSource.extensionFallback) }
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
        case "ws": return (.wonderSwan, .extensionFallback)
        case "wsc": return (.wonderSwanColor, .extensionFallback)
        case "n64", "z64", "v64": return (.nintendo64, .extensionFallback)
        case "md", "gen", "smd": return (.megaDrive, .extensionFallback)
        case "32x": return (.sega32X, .extensionFallback)
        case "a26": return (.atari2600, .extensionFallback)
        case "gdi": return (.dreamcast, .extensionFallback)
        case "cso": return (.playStationPortable, .extensionFallback)
        case "3ds", "3dsx", "cci", "cxi": return (.nintendo3DS, .extensionFallback)
        case "rvz", "gcz": return (.gameCube, .extensionFallback)
        default: return nil
        }
    }
}

enum EmulationLaunchBuilder {
    static func prepare(romURL: URL, title: String, originalFilename: String, expectedSystem: EmulatedSystemID? = nil, retroAchievementsGameID: Int = 0) throws -> EmulationLaunchDescriptor {
        let identity = try ROMContentInspector.inspect(url: romURL, filename: originalFilename, expectedSystem: expectedSystem)
        guard let core = CoreRegistry.core(for: identity.systemID) else {
            throw PocketError.message("Nenhum núcleo compatível está instalado para este sistema.")
        }
        return EmulationLaunchDescriptor(
            romURL: romURL,
            title: title,
            identity: identity,
            core: core,
            legacySaveBasename: (originalFilename as NSString).deletingPathExtension,
            retroAchievementsGameID: max(0, retroAchievementsGameID)
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
