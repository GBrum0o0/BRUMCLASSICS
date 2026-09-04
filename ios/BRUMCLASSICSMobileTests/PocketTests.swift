import XCTest
@testable import BRUMCLASSICSMobile

final class PocketTests: XCTestCase {
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
}
