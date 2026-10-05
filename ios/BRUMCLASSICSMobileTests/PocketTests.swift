import XCTest
@testable import BRUMCLASSICSMobile

final class PocketTests: XCTestCase {
    func testEmulationIdentityUsesHeaderAndContentInsteadOfFilename() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        let logo: [UInt8] = [
            0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
            0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
            0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E
        ]
        bytes.replaceSubrange(0x104...0x133, with: logo)
        bytes[0x143] = 0x80
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("renamed-one.gb")
        let second = root.appendingPathComponent("another-name.gba")
        try Data(bytes).write(to: first); try Data(bytes).write(to: second)

        let a = try ROMContentInspector.inspect(url: first, filename: first.lastPathComponent)
        let b = try ROMContentInspector.inspect(url: second, filename: second.lastPathComponent)
        XCTAssertEqual(a.systemID, .gameBoyColor)
        XCTAssertEqual(a.detectionSource, .header)
        XCTAssertEqual(a.canonicalGameID, b.canonicalGameID)
        let hinted = try ROMContentInspector.inspect(url: first, filename: "wrong.gba", expectedSystem: .playStation)
        XCTAssertEqual(hinted.systemID, .gameBoyColor)
        XCTAssertEqual(hinted.detectionSource, .header)
    }

    func testEmulationIdentityFallsBackToExtensionForSyntheticGBA() throws {
        let detected = ROMContentInspector.detectSystem(header: Data([1, 2, 3]), filename: "sample.gba")
        XCTAssertEqual(detected?.system, .gameBoyAdvance)
        XCTAssertEqual(detected?.source, .extensionFallback)
        XCTAssertEqual(CoreRegistry.core(for: .gameBoyAdvance)?.id, "mgba")
        XCTAssertEqual(CoreRegistry.core(for: .gameBoyAdvance)?.libraryName, "mgba_libretro_ios.dylib")
        XCTAssertEqual(CoreRegistry.core(for: .gameBoyAdvance)?.license, "MPL-2.0")
        XCTAssertEqual(CoreRegistry.core(for: .nintendoDS)?.id, "skyemu")
        XCTAssertEqual(CoreRegistry.core(for: .nintendoDS)?.libraryName, "skyemu_libretro_ios.dylib")
        XCTAssertEqual(CoreRegistry.core(for: .neoGeo)?.id, "geolith")
        XCTAssertEqual(CoreRegistry.core(for: .neoGeo)?.libraryName, "geolith_libretro_ios.dylib")
        XCTAssertEqual(CoreRegistry.core(for: .neoGeo)?.license, "BSD-3-Clause")
        XCTAssertEqual(ROMContentInspector.detectSystem(header: Data([1]), filename: "Metal Slug.neo")?.system, .neoGeo)
        XCTAssertEqual(CoreRegistry.core(for: .masterSystem)?.id, "gearsystem")
        XCTAssertEqual(CoreRegistry.core(for: .gameGear)?.libraryName, "gearsystem_libretro_ios.dylib")
        XCTAssertEqual(CoreRegistry.core(for: .gameGear)?.license, "GPL-3.0-or-later")
        XCTAssertEqual(ROMContentInspector.detectSystem(header: Data([1]), filename: "Sonic.gg")?.system, .gameGear)
        XCTAssertEqual(CoreRegistry.core(for: .nintendoEntertainmentSystem)?.id, "nestopia")
        XCTAssertEqual(CoreRegistry.core(for: .nintendoEntertainmentSystem)?.license, "GPL-2.0-or-later")
        XCTAssertEqual(CoreRegistry.core(for: .pcEngine)?.id, "beetle-pce-fast")
        XCTAssertEqual(CoreRegistry.core(for: .pcEngine)?.libraryName, "mednafen_pce_fast_libretro_ios.dylib")
        XCTAssertEqual(CoreRegistry.core(for: .superNintendo)?.id, "bsnes-mercury-performance")
        XCTAssertEqual(CoreRegistry.core(for: .superNintendo)?.license, "GPL-3.0")
        XCTAssertEqual(EmulatedSystemID.gameBoyAdvance.retroAchievementsConsoleID, 5)
        XCTAssertEqual(EmulatedSystemID.neoGeo.retroAchievementsConsoleID, 27)
        XCTAssertEqual(CoreRegistry.core(for: .wonderSwanColor)?.id, "beetle-wswan")
        XCTAssertEqual(ROMContentInspector.detectSystem(header: Data([1]), filename: "Judgment Silversword.wsc")?.system, .wonderSwanColor)
        XCTAssertEqual(EmulatedSystemID.wonderSwan.retroAchievementsConsoleID, 53)
        XCTAssertEqual(CoreRegistry.candidate(for: .nintendo64)?.id, "mupen64plus-next")
        XCTAssertEqual(CoreRegistry.candidate(for: .playStation)?.id, "beetle-psx")
        XCTAssertEqual(CoreRegistry.candidate(for: .saturn)?.id, "beetle-saturn")
        XCTAssertEqual(CoreRegistry.candidate(for: .atari2600)?.id, "stella2014")
        XCTAssertEqual(CoreRegistry.candidate(for: .playStationPortable)?.id, "ppsspp")
        XCTAssertEqual(CoreRegistry.candidate(for: .dreamcast)?.id, "flycast")
        XCTAssertEqual(CoreRegistry.candidate(for: .megaDrive)?.id, "blastem")
        XCTAssertEqual(CoreRegistry.candidate(for: .segaCD)?.id, "blastem")
        XCTAssertEqual(CoreRegistry.candidate(for: .sega32X)?.id, "blastem")
        XCTAssertEqual(CoreRegistry.candidate(for: .nintendo3DS)?.id, "citra")
        XCTAssertEqual(CoreRegistry.candidate(for: .gameCube)?.id, "dolphin")
        XCTAssertEqual(CoreRegistry.candidate(for: .playStation2)?.id, "play")
        for candidate in CoreRegistry.candidates {
            for system in candidate.supportedSystems { XCTAssertNil(CoreRegistry.core(for: system, includeExperimental: false)) }
        }
        XCTAssertEqual(CoreRegistry.core(for: .playStation, includeExperimental: true)?.id, "beetle-psx")
        XCTAssertEqual(CoreRegistry.core(for: .atari2600, includeExperimental: true)?.id, "stella2014")
        XCTAssertEqual(CoreRegistry.core(for: .nintendo64, includeExperimental: true)?.id, "mupen64plus-next")
        XCTAssertEqual(CoreRegistry.core(for: .saturn, includeExperimental: true)?.id, "beetle-saturn")
        XCTAssertEqual(CoreRegistry.core(for: .playStationPortable, includeExperimental: true)?.id, "ppsspp")
        XCTAssertEqual(CoreRegistry.core(for: .dreamcast, includeExperimental: true)?.id, "flycast")
        XCTAssertEqual(CoreRegistry.core(for: .megaDrive, includeExperimental: true)?.id, "blastem")
        XCTAssertEqual(CoreRegistry.core(for: .segaCD, includeExperimental: true)?.id, "blastem")
        XCTAssertEqual(CoreRegistry.core(for: .sega32X, includeExperimental: true)?.id, "blastem")
        XCTAssertNil(CoreRegistry.core(for: .nintendo3DS, includeExperimental: true))
        XCTAssertNil(CoreRegistry.core(for: .gameCube, includeExperimental: true))
        XCTAssertEqual(EmulatedSystemID.nintendo64.retroAchievementsConsoleID, 2)
        XCTAssertEqual(EmulatedSystemID.playStation.retroAchievementsConsoleID, 12)
        XCTAssertEqual(EmulatedSystemID.playStationPortable.retroAchievementsConsoleID, 41)
        XCTAssertEqual(EmulatedSystemID.dreamcast.retroAchievementsConsoleID, 40)
        XCTAssertEqual(EmulatedSystemID.nintendo3DS.retroAchievementsConsoleID, 62)
        XCTAssertEqual(EmulatedSystemID.gameCube.retroAchievementsConsoleID, 16)
    }

    func testSaveManifestOnlyAdvancesGenerationWhenPayloadChanges() {
        let identity = CanonicalGameIdentity(systemID: .gameBoyAdvance, contentSHA256: String(repeating: "a", count: 64), detectionSource: .header)
        let first = SaveManifest.next(previous: nil, identity: identity, coreID: "mgba", payloadSHA256: "one", sizeBytes: 32, deviceID: "phone")
        let unchanged = SaveManifest.next(previous: first, identity: identity, coreID: "mgba", payloadSHA256: "one", sizeBytes: 32, deviceID: "phone")
        let changed = SaveManifest.next(previous: unchanged, identity: identity, coreID: "mgba", payloadSHA256: "two", sizeBytes: 32, deviceID: "phone")
        XCTAssertEqual(first.generation, 1)
        XCTAssertEqual(unchanged.generation, 1)
        XCTAssertEqual(changed.generation, 2)
        XCTAssertEqual(first.canonicalGameID, identity.canonicalGameID)
    }

    func testOlderPocketCatalogWithoutLastPlayedDateStillDecodes() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","title":"Game","filename":"game.gba","retroAchievementID":"","launcherGameID":"","importedIntoRetroArch":true}"#
        let game = try JSONDecoder().decode(PocketClassic.self, from: Data(json.utf8))
        XCTAssertNil(game.lastPlayedAt)
        XCTAssertTrue(game.importedIntoRetroArch)
    }
    func testROMIdentityAndURLNeverInterpretFilenameAsPathOrQuery() {
        XCTAssertNil(PocketRules.launchURL("../escape.gba"))
        XCTAssertNil(PocketRules.launchURL("folder\\escape.gba"))
        let url = PocketRules.launchURL("Pokémon #1 & test.gba")!
        XCTAssertEqual(url.scheme, "retroarch")
        XCTAssertEqual(url.host, "game")
        XCTAssertNil(url.query); XCTAssertNil(url.fragment)
        XCTAssertEqual(url.path, "/Pokémon #1 & test.gba")
    }
    func testCloudProgressUsesActualEarnedDatesAndChecksIdentity() throws {
        let json = #"{"ID":123,"Title":"Game","Achievements":{"1":{"Title":"Locked","Points":5},"2":{"Title":"Earned","DateEarned":"2026-09-04"},"3":{"Title":"Hardcore","DateEarnedHardcore":"2026-09-04"}}}"#
        let result = try PocketProgress.decode(Data(json.utf8), username: "test", expectedID: 123)
        XCTAssertEqual(result.unlocked, 2)
        XCTAssertEqual(result.achievements.count, 3)
        XCTAssertThrowsError(try PocketProgress.decode(Data(json.utf8), username: "test", expectedID: 124))
        XCTAssertThrowsError(try PocketProgress.decode(Data("{}".utf8), username: "test", expectedID: 123))
    }
    func testLocalImportPreservesOriginalAndPersistsCatalog() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("sample.gba")
        let bytes = Data("synthetic test ROM; not a game".utf8)
        try bytes.write(to: source)
        let files = PocketFiles(root: root.appendingPathComponent("catalog"))
        let game = try await files.importROM(source)
        try await files.save([game])
        let loaded = try await files.load()
        XCTAssertEqual(loaded, [game])
        let copied = try await files.file(game)
        XCTAssertEqual(try Data(contentsOf: copied), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
    func testRetroArchLibraryCallbackUsesExactSafeIdentity() throws {
        let rows: [[String: Any]] = [
            ["titleId": "Pokemon.gba", "titleName": "Pokémon FireRed", "filename": "Pokemon.gba", "gameId": "gba:1", "system": "Nintendo - Game Boy Advance"],
            ["titleId": "../escape.gba", "titleName": "Unsafe", "filename": "../escape.gba", "gameId": "gba:2"],
            ["titleId": "wrong.nes", "titleName": "Mismatch", "filename": "other.nes", "gameId": "nes:3"]
        ]
        let data = try JSONSerialization.data(withJSONObject: rows)
        var encoded = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        var components = URLComponents(); components.scheme = "brumclassics"; components.host = "retroarch"; components.queryItems = [.init(name: "games", value: encoded)]
        let decoded = try RetroArchLibraryRules.decode(components.url!)
        XCTAssertEqual(decoded.map(\.titleId), ["Pokemon.gba"])
        XCTAssertEqual(RetroArchLibraryRules.launchURL(titleId: decoded[0].titleId)?.absoluteString, "retroarch://game/Pokemon.gba")
        encoded = "invalid***"; components.queryItems = [.init(name: "games", value: encoded)]
        XCTAssertThrowsError(try RetroArchLibraryRules.decode(components.url!))
    }
    func testRetroArchDuplicateFilenamesAreNotOfferedAsWrongGame() throws {
        let rows = [
            ["titleId": "game.zip", "titleName": "One", "filename": "game.zip", "gameId": "a"],
            ["titleId": "game.zip", "titleName": "Two", "filename": "game.zip", "gameId": "b"]
        ]
        let data = try JSONSerialization.data(withJSONObject: rows)
        let encoded = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let url = URL(string: "brumclassics://retroarch?games=\(encoded)")!
        XCTAssertTrue(try RetroArchLibraryRules.decode(url).isEmpty)
    }
    func testOldRetroArchLinkCacheIsNotReusedAfterPermissionMigration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stale = [RetroArchLibraryGame(titleId: "Pokemon.gba", titleName: "Pokemon", filename: "Pokemon.gba", gameId: "gba:1", developer: nil, version: nil, system: nil, coreName: nil)]
        try JSONEncoder().encode(stale).write(to: root.appendingPathComponent("retroarch-library.json"))
        let files = RetroArchLibraryFiles(root: root)
        let loaded = try await files.load()
        XCTAssertTrue(loaded.isEmpty)
    }
    func testROMFolderShowsOnlyRealSupportedFilesAndOmitsAmbiguousDuplicates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([1]).write(to: root.appendingPathComponent("Pokemon.gba"))
        try Data([2]).write(to: root.appendingPathComponent("notes.txt"))
        try Data([3]).write(to: root.appendingPathComponent("duplicate.nes"))
        try Data([4]).write(to: root.appendingPathComponent("nested/duplicate.nes"))
        try Data([5]).write(to: root.appendingPathComponent("neogeo.zip"))
        let result = try ROMFolderScanner.scan(root)
        XCTAssertEqual(result.games.map(\.filename), ["Pokemon.gba"])
        XCTAssertEqual(result.duplicateFilenames, 2)
    }
    func testRetroArchShareStagesReadablePrivateCopyAndPreservesOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let exportRoot = root.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = sourceRoot.appendingPathComponent("Pokemon Fire Red.gba")
        let bytes = Data("synthetic test ROM; not a game".utf8)
        try bytes.write(to: source)
        let staged = try ROMExportStager.stage(source: source, filename: source.lastPathComponent, root: exportRoot, id: UUID())
        XCTAssertTrue(staged.path.hasPrefix(exportRoot.path + "/"))
        XCTAssertNotEqual(staged.standardizedFileURL, source.standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: staged), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
    func testAppStoreDirectLaunchUsesRetroArchInternalCopyAndKnownCore() throws {
        let url = try XCTUnwrap(RetroArchAppStoreLaunchRules.launchURL(filename: "Pokemon Fire Red.gba"))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(url.scheme, "retroarch")
        XCTAssertEqual(url.host, "topshelf")
        XCTAssertEqual(query.first(where: { $0.name == "path" })?.value, "~/Documents/RetroArch/downloads/Pokemon Fire Red.gba")
        XCTAssertEqual(query.first(where: { $0.name == "core_path" })?.value, ":/Frameworks/mgba.libretro.framework/mgba.libretro")
        XCTAssertNil(RetroArchAppStoreLaunchRules.launchURL(filename: "../escape.gba"))
        XCTAssertNil(RetroArchAppStoreLaunchRules.launchURL(filename: "ambiguous.iso"))
    }
    func testSceneROMNameBecomesAReadableLibraryTitle() {
        XCTAssertEqual(ROMTitleRules.clean("1636 - Pokemon Fire Red (U)(Squirrels).gba"), "Pokemon Fire Red")
        XCTAssertEqual(ROMTitleRules.clean("Pokemon_FireRed_Version.gba"), "Pokemon Fire Red")
    }
    func testIntegratedCoreSupportsValidatedSystemsOnly() {
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Pokemon.gba", filename: "Pokemon.gba", title: "Pokemon", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Tetris.gb", filename: "Tetris.gb", title: "Tetris", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Zelda.gbc", filename: "Zelda.gbc", title: "Zelda", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Metal Slug.neo", filename: "Metal Slug.neo", title: "Metal Slug", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Sonic.sms", filename: "Sonic.sms", title: "Sonic", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Sonic.gg", filename: "Sonic.gg", title: "Sonic", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Mario.nes", filename: "Mario.nes", title: "Mario", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Bonk.pce", filename: "Bonk.pce", title: "Bonk", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Mario.sfc", filename: "Mario.sfc", title: "Mario", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "N64/Mario.z64", filename: "Mario.z64", title: "Mario", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "MegaDrive/Sonic.md", filename: "Sonic.md", title: "Sonic", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "32X/Knuckles.32x", filename: "Knuckles.32x", title: "Knuckles", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "PS1/Ridge Racer.cue", filename: "Ridge Racer.cue", title: "Ridge Racer", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "Saturn/Nights.chd", filename: "Nights.chd", title: "Nights", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "Arcade/mslug.zip", filename: "mslug.zip", title: "Metal Slug", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "Atari/Pitfall.a26", filename: "Pitfall.a26", title: "Pitfall", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "PSP/Game.cso", filename: "Game.cso", title: "Game", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "Dreamcast/Sonic.gdi", filename: "Sonic.gdi", title: "Sonic", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "3DS/Mario.3ds", filename: "Mario.3ds", title: "Mario", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "GameCube/Melee.rvz", filename: "Melee.rvz", title: "Melee", fileSize: 1)))
        XCTAssertEqual(IntegratedEmulatorSupport.routeLabel(.init(relativePath: "Pokemon.gba", filename: "Pokemon.gba", title: "Pokemon", fileSize: 1)), "JOGAR · BRUM CORE")
    }
    func testAmbiguousDiscRoutingRequiresFolderAndMatchingFormat() {
        func system(_ path: String) -> EmulatedSystemID? {
            IntegratedEmulatorSupport.system(for: .init(relativePath: path, filename: (path as NSString).lastPathComponent, title: "test", fileSize: 1))
        }
        XCTAssertNil(system("game.iso"))
        XCTAssertNil(system("PS1/readme.txt"))
        XCTAssertNil(system("Arcade/game.iso"))
        XCTAssertEqual(system("Dreamcast/game.cdi"), .dreamcast)
        XCTAssertEqual(system("PSP/game.iso"), .playStationPortable)
        XCTAssertEqual(system("Sega CD/game.cue"), .segaCD)
        XCTAssertNil(system("Sega CD/game.m3u"))
        XCTAssertEqual(ROMFolderScanner.firmwareDestinationNames["bios_cd_u.bin"], "bios_CD_U.bin")
        XCTAssertEqual(ROMFolderScanner.firmwareDestinationNames["32x_m_bios.bin"], "32X_M_BIOS.bin")
        XCTAssertEqual(system("PS1/game.cue"), .playStation)
        XCTAssertEqual(system("PS2/game.iso"), .playStation2)
        XCTAssertEqual(system("Sega CD/game.chd"), .segaCD)
        XCTAssertEqual(system("nested/PSP/game.iso"), .playStationPortable)
        XCTAssertEqual(system("PS1/PS2/game.iso"), .playStation2)
    }
    func testDiscStagingCopiesTracksAndRemovesOnlyFailedPrivateCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        let output = root.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cue = source.appendingPathComponent("disc.cue")
        let track = source.appendingPathComponent("track 01.bin")
        try Data("FILE \"track 01.bin\" BINARY\n TRACK 01 MODE2/2352\n".utf8).write(to: cue)
        try Data([1, 2, 3]).write(to: track)
        let playlist = source.appendingPathComponent("game.m3u")
        try Data("disc.cue\n".utf8).write(to: playlist)
        let staged = try ROMExportStager.stageDiscSet(source: playlist, filename: "game.m3u", root: output, id: UUID())
        XCTAssertEqual(try Data(contentsOf: staged.deletingLastPathComponent().appendingPathComponent("track 01.bin")), Data([1, 2, 3]))
        let firstIdentity = try ROMContentInspector.inspect(url: playlist, filename: "game.m3u", expectedSystem: .playStation)
        try Data([4, 5, 6]).write(to: track)
        let secondIdentity = try ROMContentInspector.inspect(url: playlist, filename: "game.m3u", expectedSystem: .playStation)
        XCTAssertNotEqual(firstIdentity.contentSHA256, secondIdentity.contentSHA256)
        try Data("game.m3u\n".utf8).write(to: playlist)
        XCTAssertThrowsError(try ROMExportStager.contentFiles(for: playlist))
        for reference in ["../outside.bin", "missing.bin"] {
            try Data("FILE \"\(reference)\" BINARY\n".utf8).write(to: cue)
            let id = UUID()
            XCTAssertThrowsError(try ROMExportStager.stageDiscSet(source: cue, filename: "disc.cue", root: output, id: id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.appendingPathComponent(id.uuidString).path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: cue.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: track.path))
        }
    }
    func testROMArtworkMatchesSceneNameWithinPlatformAndKeepsOtherGamesOut() {
        let paths = ["Named_Boxarts/Pokemon - FireRed Version (USA, Europe).png", "Named_Boxarts/Pokemon - LeafGreen Version (USA).png", "Named_Snaps/Pokemon - FireRed Version (USA, Europe).png"]
        XCTAssertEqual(ROMArtworkRules.match(filename: "1636 - Pokemon Fire Red (U)(Squirrels).gba", paths: paths), paths[0])
        XCTAssertNil(ROMArtworkRules.match(filename: "Pokemon Emerald.gba", paths: paths))
        XCTAssertNil(ROMArtworkRules.repository(filename: "game.iso"))
        XCTAssertEqual(ROMArtworkRules.repository(filename: "Metal Slug.neo"), "SNK_-_Neo_Geo")
        XCTAssertNotEqual(ROMArtworkRules.repository(filename: "game.gba"), ROMArtworkRules.repository(filename: "game.gb"))
    }
}
