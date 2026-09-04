import XCTest
@testable import BRUMCLASSICSMobile

final class SnapshotTests: XCTestCase {
    func testBCardLaunchPreferenceIsValidatedPerPlatform() {
        XCTAssertEqual(BCardLaunchMode.validated("continue-auto", classic: true), "continue-auto")
        XCTAssertEqual(BCardLaunchMode.validated("continue-manual", classic: true), "continue-manual")
        XCTAssertEqual(BCardLaunchMode.validated("continue-manual", classic: false), "new")
        XCTAssertEqual(BCardLaunchMode.validated("invalid", classic: true), "new")
    }

    func testReceivedPerformanceIgnoresClockSkewButExpires() throws {
        let json = #"{"active":true,"gameId":"test:1","sampledAt":"2000-01-01T00:00:00Z","sessionSeconds":30,"cpu":{"available":true,"usagePercent":5},"gpu":{"available":false,"name":""},"memory":{"available":false},"fps":{"available":false,"reason":"PRESENTMON_NOT_INSTALLED"}}"#
        let value = try JSONDecoder().decode(PerformanceState.self, from: Data(json.utf8))
        XCTAssertTrue(value.isLive(gameID: "test:1", connected: true, receivedUptime: 100, nowUptime: 105))
        XCTAssertFalse(value.isLive(gameID: "test:1", connected: true, receivedUptime: 100, nowUptime: 121))
        XCTAssertFalse(value.isLive(gameID: "test:1", connected: true, receivedUptime: nil, nowUptime: 105))
        XCTAssertFalse(value.isLive(gameID: "test:1", connected: false, receivedUptime: 100, nowUptime: 105))
        XCTAssertFalse(value.isLive(gameID: "other", connected: true, receivedUptime: 100, nowUptime: 105))
        XCTAssertTrue(PerformanceState.reasonLabel(value.fps.reason).contains("PresentMon"))
    }

    private func sampleGame(playtime: String) throws -> Game {
        let json = """
        {"id":"test:1","title":"Teste","description":"","category":"modern","platform":"pc","store":"local","genre":"","collectionId":"","sizeBytes":0,"playtimeMinutes":\(playtime),"playtimeAvailable":true,"achievementsCollected":null,"achievementsTotal":null,"achievementsAvailable":false,"achievements":[],"storyCompleted":false,"favorite":false,"wantToPlay":false,"libraryStateRevision":0,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"","artworkPath":""}
        """
        return try JSONDecoder().decode(Game.self, from: Data(json.utf8))
    }

    func testFractionalPlaytimePreservesPrecisionAndCacheRoundtrip() throws {
        let game = try sampleGame(playtime: "35.13333333333333")
        XCTAssertEqual(try XCTUnwrap(game.playtimeMinutes), 35.13333333333333, accuracy: 0.000000001)
        XCTAssertEqual(game.playtimeLabel, "35 min")
        let cached = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(cached.playtimeMinutes, game.playtimeMinutes)
    }

    func testUnavailablePlaytimeDoesNotRejectLibrary() throws {
        let game = try sampleGame(playtime: "null")
        XCTAssertNil(game.playtimeMinutes)
        XCTAssertEqual(game.playtimeLabel, "INDISPONÍVEL")
    }

    func testFractionalPlaytimeDoesNotDropOtherGames() throws {
        var snapshot = LibrarySnapshot.empty
        snapshot.games = [try sampleGame(playtime: "120"), try sampleGame(playtime: "35.13333333333333")]
        let result = try JSONDecoder().decode(LibrarySnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(result.games.count, 2)
        XCTAssertEqual(result.games[0].playtimeLabel, "2 h 0 min")
    }

    func testCompanionChecksActualNoteContentNotRevision() {
        var notes = Game.Notes.empty
        notes.revision = 8; notes.updatedAt = "2026-09-04"; notes.tips = "  \n "
        XCTAssertFalse(notes.hasContent)
        notes.commands = "Pular: X"
        XCTAssertTrue(notes.hasContent)
    }

    func testPerformanceRejectsOfflineStaleAndDifferentSession() throws {
        let json = #"{"active":true,"gameId":"test:1","sampledAt":"2026-09-04T12:00:00.000Z","sessionSeconds":30,"cpu":{"available":true,"usagePercent":5},"gpu":{"available":false,"name":""},"memory":{"available":false},"fps":{"available":false}}"#
        let value = try JSONDecoder().decode(PerformanceState.self, from: Data(json.utf8))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-04T12:00:05Z"))
        XCTAssertTrue(value.isFresh(gameID: "test:1", connected: true, now: now))
        XCTAssertFalse(value.isFresh(gameID: "test:1", connected: false, now: now))
        XCTAssertFalse(value.isFresh(gameID: "other", connected: true, now: now))
        XCTAssertFalse(value.isFresh(gameID: "test:1", connected: true, now: now.addingTimeInterval(25)))
    }

    func testPairingURLParsesSecureIdentity() throws {
        let url = try XCTUnwrap(URL(string: "brumclassics://pair?host=192.168.1.10&port=46991&code=123456&pin=AA:BB"))
        let value = try XCTUnwrap(PairingPayload(url: url))
        XCTAssertEqual(value.host, "192.168.1.10")
        XCTAssertEqual(value.port, 46991)
        XCTAssertEqual(value.code, "123456")
        XCTAssertEqual(value.pin, "AA:BB")
    }

    func testSnapshotDecodesProtocolEight() throws {
        let json = #"{"protocolVersion":8,"revision":4,"generatedAt":"2026-09-03T00:00:00Z","games":[{"id":"steam:730","title":"Counter-Strike 2","description":"","category":"modern","platform":"pc","store":"steam","genre":"Ação","collectionId":"","sizeBytes":1,"playtimeMinutes":120,"playtimeAvailable":true,"achievementsCollected":1,"achievementsTotal":2,"achievementsAvailable":true,"achievements":[],"storyCompleted":false,"favorite":true,"wantToPlay":false,"libraryStateRevision":1,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"","artworkPath":"/v1/artwork/steam%3A730/cover"}],"collections":[],"activity":[]}"#
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.games.first?.title, "Counter-Strike 2")
        XCTAssertEqual(snapshot.games.first?.achievementProgress, 50)
        XCTAssertEqual(snapshot.games.first?.playtimeLabel, "2 h 0 min")
    }

    func testInvalidPairingCodeIsRejected() {
        let url = URL(string: "brumclassics://pair?host=192.168.1.10&code=123&pin=AA")!
        XCTAssertNil(PairingPayload(url: url))
    }

    func testPersonalUpdateUsesSemanticVersionAndBuild() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/GBrum0o0/BRUMCLASSICS/actions"))
        let newerVersion = PersonalUpdateManifest(version: "0.2.0", build: 1, minimumIOS: "16.0", buildURL: url, notes: [])
        let newerBuild = PersonalUpdateManifest(version: "0.1.1", build: 3, minimumIOS: "16.0", buildURL: url, notes: [])
        let sameBuild = PersonalUpdateManifest(version: "0.1.1", build: 2, minimumIOS: "16.0", buildURL: url, notes: [])

        XCTAssertTrue(PersonalUpdateService.isNewer(newerVersion, thanVersion: "0.1.1", build: 2))
        XCTAssertTrue(PersonalUpdateService.isNewer(newerBuild, thanVersion: "0.1.1", build: 2))
        XCTAssertFalse(PersonalUpdateService.isNewer(sameBuild, thanVersion: "0.1.1", build: 2))
    }
}
