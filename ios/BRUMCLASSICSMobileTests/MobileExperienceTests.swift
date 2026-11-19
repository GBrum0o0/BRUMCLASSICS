import XCTest
@testable import BRUMCLASSICSMobile

final class MobileExperienceTests: XCTestCase {
    func testOfflineStateExplainsCacheAndPendingChanges() {
        let value = MobileSyncSummary.make(connection: .offline, paired: true, cachedGames: 42, pending: 3, lastSuccess: Date())
        XCTAssertEqual(value.title, "Dados salvos no aparelho")
        XCTAssertTrue(value.detail.contains("3 alterações"))
        XCTAssertEqual(value.action, "Reconexão automática ativa")
    }

    func testConnectedStateCannotBeMisread() {
        let value = MobileSyncSummary.make(connection: .online, paired: true, cachedGames: 12, pending: 0, lastSuccess: Date())
        XCTAssertEqual(value.title, "Tudo sincronizado")
        XCTAssertTrue(value.isHealthy)
    }

    func testMurbProtocolNormalizeSystemAndLutRgb565Decode() throws {
        XCTAssertEqual(MurbProtocol.normalizeSystem("N3DS"), "3ds")
        XCTAssertEqual(MurbProtocol.normalizeSystem("Azahar"), "3ds")
        XCTAssertEqual(MurbProtocol.normalizeSystem("nintendo_ds"), "ds")
        XCTAssertEqual(MurbProtocol.normalizeSystem("cemu"), "wiiu")
        XCTAssertEqual(MurbProtocol.normalizeSystem(" "), "gamepad")

        // Header (16 bytes) + 4 RGB565 pixels (LE): Red 0xF800, Green 0x07E0, Blue 0x001F, White 0xFFFF
        var frameData = Data(count: 16 + 4 * 2)
        frameData[0] = 0x42; frameData[1] = 0x52; frameData[2] = 0x55; frameData[3] = 0x4D
        frameData[4] = 9 // sequence LE = 9
        frameData[8] = 4 // width = 4
        frameData[10] = 1 // height = 1
        frameData[16] = 0x00; frameData[17] = 0xF8 // Red
        frameData[18] = 0xE0; frameData[19] = 0x07 // Green
        frameData[20] = 0x1F; frameData[21] = 0x00 // Blue
        frameData[22] = 0xFF; frameData[23] = 0xFF // White

        let decoded = try XCTUnwrap(MurbProtocol.decodeVideoFrame(frameData))
        XCTAssertEqual(decoded.sequence, 9)
        XCTAssertEqual(decoded.width, 4)
        XCTAssertEqual(decoded.height, 1)
        let rgba = try XCTUnwrap(decoded.image.dataProvider?.data as Data?)
        XCTAssertEqual([UInt8](rgba.prefix(16)), [
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255
        ])

        XCTAssertNil(MurbProtocol.decodeVideoFrame(frameData.dropLast()))
    }

    func testGamingModeCatalogBuildSnapshotIndexesMatchesAndOrdersRecents() throws {
        let localROM = ROMFolderGame(
            relativePath: "DS/Pokemon Platinum (USA).nds",
            filename: "Pokemon Platinum (USA).nds",
            title: "Pokemon Platinum",
            fileSize: 2048
        )
        let record = PocketClassic(
            id: UUID(),
            title: "Pokemon Platinum",
            filename: "Pokemon Platinum (USA).nds",
            launcherGameID: "pc-linked",
            lastPlayedAt: Date(timeIntervalSince1970: 5_000)
        )
        let json = """
        [
          {"id":"pc-linked","title":"Pokémon Platinum Version","description":"","category":"classic","platform":"Nintendo DS","store":"local","genre":"","collectionId":"","sizeBytes":0,"playtimeMinutes":120,"playtimeAvailable":true,"achievementsCollected":null,"achievementsTotal":null,"achievementsAvailable":false,"achievements":[],"storyCompleted":false,"favorite":false,"wantToPlay":false,"libraryStateRevision":0,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"2026-10-10T12:00:00.250Z","artworkPath":""},
          {"id":"pc-wiiu","title":"Mario Kart 8","description":"","category":"classic","platform":"Wii U","store":"local","genre":"","collectionId":"","sizeBytes":0,"playtimeMinutes":30,"playtimeAvailable":true,"achievementsCollected":null,"achievementsTotal":null,"achievementsAvailable":false,"achievements":[],"storyCompleted":false,"favorite":false,"wantToPlay":false,"libraryStateRevision":0,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"2026-10-08T08:00:00Z","artworkPath":""}
        ]
        """.data(using: .utf8)!
        let pcGames = try JSONDecoder().decode([Game].self, from: json)
        let snapshot = GamingModeCatalog.buildSnapshot(
            local: [localROM],
            records: [record],
            computer: pcGames,
            favorites: ["pc:pc-wiiu"],
            recentLimit: 12
        )

        XCTAssertEqual(snapshot.library.count, 2)
        XCTAssertEqual(snapshot.matchedByROMID[localROM.id]?.id, "pc-linked")
        XCTAssertEqual(snapshot.recent.map(\.id), ["pc:pc-wiiu", "local:\(localROM.id)"])
        XCTAssertNotNil(GamingModeCatalog.date("2026-10-10T12:00:00.250Z"))
        XCTAssertNotNil(GamingModeCatalog.date("2026-10-08T08:00:00Z"))
    }

    func testNativeSaveTransferClassifySyncAndRevisionTracking() throws {
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: nil, remoteRevision: nil, baseRevision: nil), .inSync)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-1", remoteRevision: "rev-1", baseRevision: nil), .inSync)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "", remoteRevision: "rev-2", baseRevision: nil), .download)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-1", remoteRevision: nil, baseRevision: nil), .upload)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-1", remoteRevision: "rev-2", baseRevision: "rev-1"), .download)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-2", remoteRevision: "rev-1", baseRevision: "rev-1"), .upload)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-2", remoteRevision: "rev-3", baseRevision: "rev-1"), .conflict)
        XCTAssertEqual(NativeSaveTransfer.classifySync(localRevision: "rev-a", remoteRevision: "rev-b", baseRevision: nil), .conflict)

        let identity = CanonicalGameIdentity(systemID: .gameBoyAdvance,
                                             contentSHA256: String(repeating: "c", count: 64),
                                             detectionSource: .header)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(NativeSaveTransfer.readLastSyncedRevision(for: identity, bindingsRoot: root))

        let revision = "native:v2:\(String(repeating: "d", count: 64))"
        let fingerprint = String(repeating: "a1b2c3d4", count: 8)
        try NativeSaveTransfer.recordSyncedRevision(revision, for: identity, profileID: "primary",
                                                    launcherFingerprint: fingerprint, bindingsRoot: root)
        XCTAssertEqual(NativeSaveTransfer.readLastSyncedRevision(for: identity, bindingsRoot: root), revision)
    }
}
