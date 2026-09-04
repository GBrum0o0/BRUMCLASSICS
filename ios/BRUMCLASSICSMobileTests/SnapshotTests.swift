import XCTest
@testable import BRUMCLASSICSMobile

final class SnapshotTests: XCTestCase {
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
