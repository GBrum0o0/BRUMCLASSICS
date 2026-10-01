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
    }

    func testEmulationIdentityFallsBackToExtensionForSyntheticGBA() throws {
        let detected = ROMContentInspector.detectSystem(header: Data([1, 2, 3]), filename: "sample.gba")
        XCTAssertEqual(detected?.system, .gameBoyAdvance)
        XCTAssertEqual(detected?.source, .extensionFallback)
        XCTAssertEqual(CoreRegistry.core(for: .gameBoyAdvance)?.id, "mgba")
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
    func testIntegratedCoreSupportsOnlyFirstValidatedSystems() {
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Pokemon.gba", filename: "Pokemon.gba", title: "Pokemon", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Tetris.gb", filename: "Tetris.gb", title: "Tetris", fileSize: 1)))
        XCTAssertTrue(IntegratedEmulatorSupport.supports(.init(relativePath: "Zelda.gbc", filename: "Zelda.gbc", title: "Zelda", fileSize: 1)))
        XCTAssertFalse(IntegratedEmulatorSupport.supports(.init(relativePath: "Mario.sfc", filename: "Mario.sfc", title: "Mario", fileSize: 1)))
    }
    func testROMArtworkMatchesSceneNameWithinPlatformAndKeepsOtherGamesOut() {
        let paths = ["Named_Boxarts/Pokemon - FireRed Version (USA, Europe).png", "Named_Boxarts/Pokemon - LeafGreen Version (USA).png", "Named_Snaps/Pokemon - FireRed Version (USA, Europe).png"]
        XCTAssertEqual(ROMArtworkRules.match(filename: "1636 - Pokemon Fire Red (U)(Squirrels).gba", paths: paths), paths[0])
        XCTAssertNil(ROMArtworkRules.match(filename: "Pokemon Emerald.gba", paths: paths))
        XCTAssertNil(ROMArtworkRules.repository(filename: "game.iso"))
        XCTAssertNotEqual(ROMArtworkRules.repository(filename: "game.gba"), ROMArtworkRules.repository(filename: "game.gb"))
    }
}
