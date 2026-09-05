import XCTest
@testable import BRUMCLASSICSMobile

final class PocketRuntimeTests: XCTestCase {
    func testFallbackSessionRequiresRealBackgroundTransitionAndPersistsIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = PocketClassic(id: UUID(), title: "Test", filename: "test.gba")
        let sessions = PocketPlaySessionFiles(root: root)
        try await sessions.begin(game, now: Date(timeIntervalSince1970: 100))
        let premature = try await sessions.finish(returnedAt: Date(timeIntervalSince1970: 110))
        XCTAssertNil(premature)
        try await sessions.markBackgrounded(now: Date(timeIntervalSince1970: 120))
        let finished = try await sessions.finish(returnedAt: Date(timeIntervalSince1970: 245))
        XCTAssertEqual(finished?.session.gameID, game.id)
        XCTAssertEqual(finished?.seconds, 125)
        let repeated = try await sessions.finish(returnedAt: Date(timeIntervalSince1970: 300))
        XCTAssertNil(repeated)
    }
    func testFallbackCreditsTimeWhenRetroArchLogFolderIsNotAuthorized() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = PocketClassic(id: UUID(), title: "Test", filename: "test.gba")
        let runtime = PocketRuntimeFiles(root: root)
        try await runtime.prepare(game, allGames: [game])
        let credited = try await runtime.creditEstimated(game.id, filename: game.filename, seconds: 125)
        XCTAssertTrue(credited)
        let errors = try await runtime.collect()
        XCTAssertTrue(errors.isEmpty)
        let records = try await runtime.load()
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.creditedSeconds, 125)
        XCTAssertEqual(record.lastObservedSeconds, 0)
    }
    func testParsesActualRetroArchRuntimeAndRejectsMalformedValues() throws {
        XCTAssertEqual(try PocketRuntimeRules.seconds(Data(#"{"runtime":"123:45:06","last_played":"2026-09-04 12:00:00"}"#.utf8)), 445506)
        for runtime in ["1:60:00", "-1:00:00", "1:00", "1:00:99", "9999999999999999999:00:00"] {
            let data = try JSONSerialization.data(withJSONObject: ["runtime": runtime])
            XCTAssertThrowsError(try PocketRuntimeRules.seconds(data))
        }
        XCTAssertThrowsError(try PocketRuntimeRules.seconds(Data("{}".utf8)))
        XCTAssertEqual(try PocketRuntimeRules.logName("Pokemon.gba"), "Pokemon.lrtl")
        XCTAssertThrowsError(try PocketRuntimeRules.logName("../other.gba"))
    }
    func testCumulativeLogCountsOnlyDeltaAndSurvivesSerialization() throws {
        var record = PocketRuntimeRecord(id: UUID(), filename: "test.gba", lastObservedSeconds: 36000)
        try record.observe(46800)
        try record.observe(46800)
        XCTAssertEqual(record.creditedSeconds, 10800)
        var restored = try JSONDecoder().decode(PocketRuntimeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored.streamID, record.streamID)
        try restored.observe(50400)
        XCTAssertEqual(restored.creditedSeconds, 14400)
        XCTAssertThrowsError(try restored.observe(0))
        XCTAssertTrue(restored.counterReset)
        XCTAssertEqual(restored.creditedSeconds, 14400)
        XCTAssertThrowsError(try restored.observe(60000))
    }
    func testCorruptLedgerNeverBecomesEmptyHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("runtime-ledger.json")
        let original = Data("{broken".utf8); try original.write(to: file)
        let store = PocketRuntimeFiles(root: root)
        do { _ = try await store.load(); XCTFail("Corrupt ledger must fail") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testFolderCheckpointOutboxAndLostAcknowledgment() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let logs = root.appendingPathComponent("logs")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PocketRuntimeFiles(root: root.appendingPathComponent("ledger"))
        try await store.configure(logs)
        let game = PocketClassic(id: UUID(), title: "Test", filename: "test.gba")
        try await store.prepare(game, allGames: [game])
        let baseline = try await store.load()
        XCTAssertEqual(baseline.first?.lastObservedSeconds, 0)
        let bound = try await store.bind(game.id, gameID: "classic:1", fingerprint: "pc-test")
        try await store.acknowledge(game.id, sentSeconds: 0, receipt: PocketTimeReceipt(ok: true, acceptedSeconds: 0))
        try Data(#"{"runtime":"3:00:00"}"#.utf8).write(to: logs.appendingPathComponent("test.lrtl"))
        let errors = try await store.collect(); XCTAssertTrue(errors.isEmpty)
        let restarted = PocketRuntimeFiles(root: root.appendingPathComponent("ledger"))
        let records = try await restarted.load()
        XCTAssertEqual(records.first?.streamID, bound.streamID)
        XCTAssertEqual(records.first?.creditedSeconds, 10800)
        XCTAssertEqual(records.first?.acknowledgedSeconds, 0)
        _ = try await restarted.collect()
        try await restarted.acknowledge(game.id, sentSeconds: 10800, receipt: PocketTimeReceipt(ok: true, acceptedSeconds: 10800))
        let confirmed = try await restarted.load()
        XCTAssertEqual(confirmed.first?.creditedSeconds, 10800)
        XCTAssertEqual(confirmed.first?.acknowledgedSeconds, 10800)
        do { _ = try await restarted.bind(game.id, gameID: "other", fingerprint: "pc-test"); XCTFail("Must not rebind history") } catch {}
    }
}
