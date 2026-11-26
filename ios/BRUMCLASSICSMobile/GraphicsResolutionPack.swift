import Foundation

public enum GraphicsProfile: String, Codable, CaseIterable, Sendable {
    case original
    case automatic
    case enhanced
    case custom
}

public enum GraphicsScaleMode: String, Codable, CaseIterable, Sendable {
    case original
    case integer
    case stretch
}

public enum GraphicsVideoFilter: String, Codable, CaseIterable, Sendable {
    case none
    case crtScanlines = "crt_scanlines"
    case lcdGrid = "lcd_grid"
    case bilinearSubtle = "bilinear_subtle"
    case casSharpen = "cas_sharpen"
    case sharpBilinear = "sharp_bilinear"
    case edgeUpscale2x = "edge_upscale_2x"
}

public enum GraphicsHardwareTier: String, Sendable {
    case low
    case medium
    case high
}

public struct GraphicsSystemCatalogEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let is3D: Bool
    public let handheld: Bool
    public let heavy: Bool
    public let aspectRatio: String
    public let maxMultiplier: Int
    public let supportsIntegerScale: Bool
    public let supportedFilters: [GraphicsVideoFilter]

    public var supportedMultipliers: [Int] {
        Array(1...max(1, maxMultiplier))
    }
}

public struct GraphicsSystemOverride: Codable, Equatable, Sendable {
    public var profile: GraphicsProfile?
    public var multiplier: Int
    public var scaleMode: GraphicsScaleMode
    public var videoFilter: GraphicsVideoFilter

    public init(
        profile: GraphicsProfile? = nil,
        multiplier: Int = 1,
        scaleMode: GraphicsScaleMode = .original,
        videoFilter: GraphicsVideoFilter = .none
    ) {
        self.profile = profile
        self.multiplier = max(1, min(4, multiplier))
        self.scaleMode = scaleMode
        self.videoFilter = videoFilter
    }
}

public struct GraphicsResolutionSettings: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var profile: GraphicsProfile = .automatic
    public var globalMultiplier: Int = 2
    public var globalScaleMode: GraphicsScaleMode = .original
    public var globalVideoFilter: GraphicsVideoFilter = .none
    public var systems: [String: GraphicsSystemOverride] = [:]

    public init(
        profile: GraphicsProfile = .automatic,
        globalMultiplier: Int = 2,
        globalScaleMode: GraphicsScaleMode = .original,
        globalVideoFilter: GraphicsVideoFilter = .none,
        systems: [String: GraphicsSystemOverride] = [:]
    ) {
        self.profile = profile
        self.globalMultiplier = max(1, min(4, globalMultiplier))
        self.globalScaleMode = globalScaleMode
        self.globalVideoFilter = globalVideoFilter
        self.systems = systems
    }
}

public struct ResolvedGraphicsConfig: Equatable, Sendable {
    public let profile: GraphicsProfile
    public let systemID: String
    public let is3D: Bool
    public let aspectRatio: String
    public let preserveAspectRatio: Bool
    public let internalMultiplier: Int
    public let scaleMode: GraphicsScaleMode
    public let integerScalingEnabled: Bool
    public let videoFilter: GraphicsVideoFilter
    public let videoFilterMode: String
    public let coreVariables: [String: String]
    public let hardwareTier: GraphicsHardwareTier
}

public final class GraphicsResolutionPack {
    public static let shared = GraphicsResolutionPack()
    private static let storageKey = "brum.graphics.resolution.v1"

    private let defaults: UserDefaults

    public static let catalog: [GraphicsSystemCatalogEntry] = [
        entry2D("atari2600", "Atari 2600", "4:3"),
        entry2D("atari5200", "Atari 5200", "4:3"),
        entry2D("atari7800", "Atari 7800", "4:3"),
        entry2D("lynx", "Atari Lynx", "160:102", handheld: true),
        entry2D("nes", "Nintendo (NES)", "4:3"),
        entry2D("snes", "Super Nintendo (SNES)", "4:3"),
        entry2D("gb", "Game Boy", "10:9", handheld: true),
        entry2D("gbc", "Game Boy Color", "10:9", handheld: true),
        entry2D("gba", "Game Boy Advance", "3:2", handheld: true),
        entry2D("sms", "Master System", "4:3"),
        entry2D("gg", "Game Gear", "10:9", handheld: true),
        entry2D("genesis", "Mega Drive / Genesis", "4:3"),
        entry2D("segacd", "Sega CD", "4:3"),
        entry2D("32x", "Sega 32X", "4:3"),
        entry2D("sg1000", "SG-1000", "4:3"),
        entry2D("pce", "PC Engine", "4:3"),
        entry2D("pcecd", "PC Engine CD", "4:3"),
        entry2D("neogeo", "Neo Geo AES / MVS", "4:3"),
        entry2D("ngp", "Neo Geo Pocket", "20:19", handheld: true),
        entry2D("ws", "WonderSwan", "14:9", handheld: true),
        entry2D("wsc", "WonderSwan Color", "14:9", handheld: true),
        entry2D("msx", "MSX / MSX2", "4:3"),
        entry2D("arcade", "Arcade (MAME)", "4:3"),
        entry2D("fbneo", "Arcade (FBNeo)", "4:3"),
        entry2D("virtualboy", "Virtual Boy", "16:9", handheld: true),
        entry3D("3do", "3DO", "4:3", maxMultiplier: 2, heavy: false),
        entry3D("jaguar", "Atari Jaguar", "4:3", maxMultiplier: 1, heavy: false),
        entry3D("ps1", "PlayStation 1", "4:3", maxMultiplier: 4, heavy: false),
        entry3D("n64", "Nintendo 64", "4:3", maxMultiplier: 4, heavy: false),
        entry3D("saturn", "Sega Saturn", "4:3", maxMultiplier: 3, heavy: true),
        entry3D("dreamcast", "Dreamcast", "4:3", maxMultiplier: 4, heavy: false),
        entry3D("nds", "Nintendo DS", "4:3 (Dual)", handheld: true, maxMultiplier: 4, heavy: false),
        entry3D("psp", "PlayStation Portable (PSP)", "16:9", handheld: true, maxMultiplier: 4, heavy: false),
        entry3D("n3ds", "Nintendo 3DS", "5:3 / 4:3", handheld: true, maxMultiplier: 3, heavy: true),
        entry3D("gamecube", "GameCube", "4:3", maxMultiplier: 3, heavy: true),
        entry3D("wii", "Nintendo Wii", "16:9", maxMultiplier: 3, heavy: true),
        entry3D("ps2", "PlayStation 2", "4:3", maxMultiplier: 3, heavy: true)
    ]

    private static let catalogByID: [String: GraphicsSystemCatalogEntry] = Dictionary(
        uniqueKeysWithValues: catalog.map { ($0.id, $0) }
    )

    private static let aliases: [String: String] = [
        "fc": "nes", "famicom": "nes",
        "sfc": "snes", "superfamicom": "snes",
        "md": "genesis", "megadrive": "genesis",
        "megacd": "segacd", "sega32x": "32x",
        "tg16": "pce", "turbografx": "pce",
        "psx": "ps1", "psone": "ps1",
        "ds": "nds", "3ds": "n3ds", "gc": "gamecube",
        "ngpc": "ngp", "a2600": "atari2600",
        "a5200": "atari5200", "a7800": "atari7800",
        "mame": "arcade", "fba": "fbneo"
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static func entry2D(_ id: String, _ label: String, _ aspect: String, handheld: Bool = false) -> GraphicsSystemCatalogEntry {
        GraphicsSystemCatalogEntry(
            id: id,
            label: label,
            is3D: false,
            handheld: handheld,
            heavy: false,
            aspectRatio: aspect,
            maxMultiplier: 1,
            supportsIntegerScale: true,
            supportedFilters: handheld
                ? [.none, .lcdGrid, .sharpBilinear, .edgeUpscale2x, .casSharpen, .bilinearSubtle]
                : [.none, .crtScanlines, .sharpBilinear, .edgeUpscale2x, .casSharpen, .bilinearSubtle]
        )
    }

    private static func entry3D(_ id: String, _ label: String, _ aspect: String, handheld: Bool = false, maxMultiplier: Int = 4, heavy: Bool = false) -> GraphicsSystemCatalogEntry {
        GraphicsSystemCatalogEntry(
            id: id,
            label: label,
            is3D: true,
            handheld: handheld,
            heavy: heavy,
            aspectRatio: aspect,
            maxMultiplier: maxMultiplier,
            supportsIntegerScale: true,
            supportedFilters: [.none, .crtScanlines, .lcdGrid, .sharpBilinear, .edgeUpscale2x, .casSharpen, .bilinearSubtle]
        )
    }

    public static func canonicalSystemID(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aliases[lower] ?? (lower.isEmpty ? "snes" : lower)
    }

    public static func detectHardwareTier(
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        processorCount: Int = ProcessInfo.processInfo.processorCount
    ) -> GraphicsHardwareTier {
        let ramGB = Double(physicalMemoryBytes) / Double(1024 * 1024 * 1024)
        if ramGB >= 5.5 && processorCount >= 6 {
            return .high
        }
        if ramGB >= 3.5 && processorCount >= 4 {
            return .medium
        }
        return .low
    }

    public func loadSettings() -> GraphicsResolutionSettings {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(GraphicsResolutionSettings.self, from: data) else {
            return GraphicsResolutionSettings()
        }
        return decoded
    }

    public func saveSettings(_ settings: GraphicsResolutionSettings) {
        var sanitized = settings
        sanitized.globalMultiplier = max(1, min(4, sanitized.globalMultiplier))
        if let encoded = try? JSONEncoder().encode(sanitized) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }

    public func resetSettings(systemID: String? = nil) -> GraphicsResolutionSettings {
        if let systemID, !systemID.isEmpty {
            var current = loadSettings()
            current.systems.removeValue(forKey: Self.canonicalSystemID(systemID))
            saveSettings(current)
            return current
        }
        let fresh = GraphicsResolutionSettings()
        saveSettings(fresh)
        return fresh
    }

    public func resolve(
        systemID: String,
        settings: GraphicsResolutionSettings? = nil,
        hardwareTier: GraphicsHardwareTier? = nil
    ) -> ResolvedGraphicsConfig {
        let activeSettings = settings ?? loadSettings()
        let canonical = Self.canonicalSystemID(systemID)
        let entry = Self.catalogByID[canonical] ?? Self.entry2D(canonical, canonical.uppercased(), "4:3")
        let tier = hardwareTier ?? Self.detectHardwareTier()
        let sysOverride = activeSettings.systems[canonical]
        let effectiveProfile = sysOverride?.profile ?? activeSettings.profile

        let multiplier: Int
        let scaleMode: GraphicsScaleMode
        var filter: GraphicsVideoFilter

        switch effectiveProfile {
        case .original:
            multiplier = 1
            scaleMode = .original
            filter = .none
        case .automatic:
            if entry.is3D {
                switch tier {
                case .low: multiplier = 1
                case .medium: multiplier = entry.heavy ? 1 : min(entry.maxMultiplier, 2)
                case .high: multiplier = entry.heavy ? min(entry.maxMultiplier, 2) : min(entry.maxMultiplier, 3)
                }
                scaleMode = .original
            } else {
                multiplier = 1
                scaleMode = .integer
            }
            filter = .none
        case .enhanced:
            if entry.is3D {
                multiplier = entry.heavy ? min(entry.maxMultiplier, 2) : min(entry.maxMultiplier, 3)
                scaleMode = .original
                filter = .none
            } else {
                multiplier = 1
                scaleMode = .integer
                filter = entry.handheld ? .lcdGrid : .crtScanlines
            }
        case .custom:
            let rawMult = sysOverride?.multiplier ?? activeSettings.globalMultiplier
            multiplier = entry.is3D ? max(1, min(entry.maxMultiplier, rawMult)) : 1
            scaleMode = sysOverride?.scaleMode ?? activeSettings.globalScaleMode
            filter = sysOverride?.videoFilter ?? activeSettings.globalVideoFilter
            if !entry.supportedFilters.contains(filter) {
                filter = .none
            }
        }

        let coreVars = Self.coreVariables(systemID: canonical, multiplier: multiplier)
        return ResolvedGraphicsConfig(
            profile: effectiveProfile,
            systemID: canonical,
            is3D: entry.is3D,
            aspectRatio: entry.aspectRatio,
            preserveAspectRatio: scaleMode != .stretch,
            internalMultiplier: multiplier,
            scaleMode: scaleMode,
            integerScalingEnabled: scaleMode == .integer,
            videoFilter: filter,
            videoFilterMode: filter.rawValue,
            coreVariables: coreVars,
            hardwareTier: tier
        )
    }

    public static func coreVariables(systemID: String, multiplier: Int) -> [String: String] {
        let m = max(1, min(4, multiplier))
        switch systemID {
        case "psp":
            return ["ppsspp_internal_resolution": "\(480 * m)x\(272 * m)"]
        case "n3ds":
            return [
                "citra_resolution_factor": "\(m)x Native",
                "citra2018_resolution_factor": "\(m)x Native"
            ]
        case "nds":
            return [
                "melonds_opengl_resolution": "\(m)x native (\(256 * m)x\(192 * m))",
                "desmume_internal_resolution": "\(256 * m)x\(192 * m)"
            ]
        case "ps1":
            return [
                "beetle_psx_hw_internal_resolution": "\(m)x",
                "swanstation_GPU_ResolutionScale": "\(m)x",
                "pcsx_rearmed_neon_enhancement_enable": m >= 2 ? "enabled" : "disabled"
            ]
        case "n64":
            return [
                "mupen64plus-43screensize": "\(320 * m)x\(240 * m)",
                "parallel-n64-screensize": "\(320 * m)x\(240 * m)"
            ]
        case "dreamcast":
            return [
                "reicast_internal_resolution": "\(640 * m)x\(480 * m)",
                "flycast_internal_resolution": "\(640 * m)x\(480 * m)"
            ]
        case "saturn":
            return [
                "yabasanshiro_resolution_mode": m == 1 ? "original" : "\(m)x",
                "kronos_resolution_mode": m == 1 ? "original" : "\(m)x"
            ]
        case "gamecube", "wii":
            return ["dolphin_efb_scale": "\(m)x (\(640 * m)x\(528 * m))"]
        default:
            return [:]
        }
    }
}
