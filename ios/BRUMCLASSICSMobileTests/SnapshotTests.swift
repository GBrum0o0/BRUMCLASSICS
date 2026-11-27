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
        let url = try XCTUnwrap(URL(string: "brumclassics://pair?host=192.168.1.10&alt=100.64.1.5&port=46991&code=123456&pin=AA:BB"))
        let value = try XCTUnwrap(PairingPayload(url: url))
        XCTAssertEqual(value.host, "192.168.1.10")
        XCTAssertEqual(value.alternateHosts, ["100.64.1.5"])
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
        XCTAssertNil(snapshot.notifications)
    }

    func testSnapshotDecodesSafeNotificationCenter() throws {
        let json = #"{"protocolVersion":9,"revision":5,"generatedAt":"2026-09-12T12:00:00Z","games":[],"collections":[],"activity":[],"notifications":{"entries":[{"id":"notice-1","category":"achievement","title":"Conquista desbloqueada","message":"Primeiros passos","gameId":"classic:1","gameTitle":"Jogo","createdAt":"2026-09-12T11:59:00Z","readAt":"","action":"game","severity":"success"}],"unread":1,"total":1}}"#
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(json.utf8))
        let center = try XCTUnwrap(snapshot.notifications)
        XCTAssertEqual(center.unread, 1)
        XCTAssertEqual(center.entries.first?.title, "Conquista desbloqueada")
        XCTAssertFalse(try XCTUnwrap(center.entries.first).isRead)
    }

    func testInvalidPairingCodeIsRejected() {
        let url = URL(string: "brumclassics://pair?host=192.168.1.10&code=123&pin=AA")!
        XCTAssertNil(PairingPayload(url: url))
    }

    func testAchievementGameSearchIgnoresCaseAccentsAndWordOrder() {
        let fields = ["Pokémon Emerald", "Game Boy Advance", "RetroAchievements"]
        XCTAssertTrue(AchievementGameSearch.matches("pokemon", fields: fields))
        XCTAssertTrue(AchievementGameSearch.matches("advance emerald", fields: fields))
        XCTAssertTrue(AchievementGameSearch.matches("RETROACHIEVEMENTS", fields: fields))
        XCTAssertFalse(AchievementGameSearch.matches("metroid", fields: fields))
        XCTAssertTrue(AchievementGameSearch.matches("   ", fields: fields))
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

    func testPersonalUpdateManifestDecodingAndOfficialURLValidation() throws {
        let json = """
        {
          "version": "0.34.0",
          "build": 67,
          "minimumIos": "16.0",
          "buildUrl": "https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v0.34.0",
          "notes": [
            "Download direto do Google Drive no Gaming Mode",
            "Instalação exclusiva via Brum iOS Bridge"
          ]
        }
        """
        let manifest = try JSONDecoder().decode(PersonalUpdateManifest.self, from: Data(json.utf8))
        XCTAssertEqual(manifest.version, "0.34.0")
        XCTAssertEqual(manifest.build, 67)
        XCTAssertEqual(manifest.minimumIOS, "16.0")
        XCTAssertEqual(manifest.notes, [
            "Download direto do Google Drive no Gaming Mode",
            "Instalação exclusiva via Brum iOS Bridge"
        ])
        XCTAssertEqual(manifest.buildURL.absoluteString, "https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v0.34.0")
        XCTAssertTrue(PersonalUpdateService.isValidOfficialIOSReleaseURL(manifest.buildURL))

        let ipaURL = try XCTUnwrap(URL(string: "https://github.com/GBrum0o0/BRUMCLASSICS/releases/download/ios-v0.34.0/BRUMCLASSICS-MOVEL-IOS-0.34.0.ipa"))
        XCTAssertTrue(PersonalUpdateService.isValidOfficialIOSReleaseURL(ipaURL))

        let latestURL = try XCTUnwrap(URL(string: "https://github.com/GBrum0o0/BRUMCLASSICS/releases/latest/download/BRUMCLASSICS-OFICIAL.exe"))
        XCTAssertFalse(PersonalUpdateService.isValidOfficialIOSReleaseURL(latestURL))

        let externalURL = try XCTUnwrap(URL(string: "https://example.com/BRUMCLASSICS-MOVEL-IOS-0.34.0.ipa"))
        XCTAssertFalse(PersonalUpdateService.isValidOfficialIOSReleaseURL(externalURL))
    }

    func testSaveMigrationBackupExportVerifyAndRestorePreservesData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brum-backup-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let support = root.appendingPathComponent("AppSupport", isDirectory: true)
        let exports = root.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: support.appendingPathComponent("IntegratedEmulator/Saves/gba", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support.appendingPathComponent("ClassicsEverywhere", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)

        let saveURL = support.appendingPathComponent("IntegratedEmulator/Saves/gba/firered.srm")
        let originalSave = Data("SRAM-FIRERED-PIKACHU".utf8)
        try originalSave.write(to: saveURL)
        try Data("[]".utf8).write(to: support.appendingPathComponent("ClassicsEverywhere/games.json"))

        let exported = try SaveMigrationBackupService.exportBackup(
            from: support,
            to: exports,
            appVersion: "0.25.0",
            appBuild: 58
        )
        XCTAssertEqual(exported.manifest.files.count, 2)

        // Sobrescreve save local, restaura do backup e garante preservação anterior em PreRestoreBackups.
        try Data("CORRUPTED".utf8).write(to: saveURL)
        let restored = try SaveMigrationBackupService.restoreBackup(from: exported.folder, into: support)
        XCTAssertEqual(restored.restoredCount, 2)
        XCTAssertEqual(try Data(contentsOf: saveURL), originalSave)
        XCTAssertNotNil(restored.snapshotFolder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.snapshotFolder!.appendingPathComponent("IntegratedEmulator/Saves/gba/firered.srm").path))

        // Adulterar arquivo dentro do backup deve impedir restauração.
        let backedSave = exported.folder.appendingPathComponent("files/IntegratedEmulator/Saves/gba/firered.srm")
        try Data("TAMPERED".utf8).write(to: backedSave)
        XCTAssertThrowsError(try SaveMigrationBackupService.restoreBackup(from: exported.folder, into: support))
        XCTAssertEqual(try Data(contentsOf: saveURL), originalSave)
    }
}
