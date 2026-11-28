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

    func testGamingModeCatalogSurfacesDriveOnlyGamesAndDeduplicatesLocalCopies() throws {
        let localROM = ROMFolderGame(
            relativePath: "GBA/Pokemon FireRed (USA).gba",
            filename: "Pokemon FireRed (USA).gba",
            title: "Pokemon FireRed",
            fileSize: 1024,
            detectedSystem: .gameBoyAdvance
        )
        let pcJSON = """
        [
          {"id":"pc-smc","title":"Super Mario Kart","description":"","category":"classic","platform":"Super Nintendo","store":"local","genre":"","collectionId":"","sizeBytes":0,"playtimeMinutes":15,"playtimeAvailable":true,"achievementsCollected":null,"achievementsTotal":null,"achievementsAvailable":false,"achievements":[],"storyCompleted":false,"favorite":false,"wantToPlay":false,"libraryStateRevision":0,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"","artworkPath":""}
        ]
        """.data(using: .utf8)!
        let pcGames = try JSONDecoder().decode([Game].self, from: pcJSON)
        let cloudItems = [
            ClassicDriveGameItem(id: "drv-local", name: "Pokemon FireRed (USA).gba", title: "Pokemon FireRed", relativePath: "GBA/Pokemon FireRed (USA).gba", folderID: "f1", parentRelativePath: "GBA", systemHint: "gba", downloadURL: "https://drive.google.com/uc?id=drv-local&export=download"),
            ClassicDriveGameItem(id: "drv-pc", name: "Super Mario Kart (USA).sfc", title: "Super Mario Kart", relativePath: "SNES/Super Mario Kart (USA).sfc", folderID: "f2", parentRelativePath: "SNES", systemHint: "sfc", downloadURL: "https://drive.google.com/uc?id=drv-pc&export=download"),
            ClassicDriveGameItem(id: "drv-psp", name: "God of War.iso", title: "God of War", relativePath: "PSP/God of War.iso", folderID: "f3", parentRelativePath: "PSP", systemHint: "psp", downloadURL: "https://drive.google.com/uc?id=drv-psp&export=download")
        ]

        let snapshot = GamingModeCatalog.buildSnapshot(
            local: [localROM],
            records: [],
            computer: pcGames,
            cloud: cloudItems
        )

        XCTAssertEqual(snapshot.library.count, 3)
        XCTAssertTrue(snapshot.library.contains { $0.id == "drive:drv-psp" })
        XCTAssertFalse(snapshot.library.contains { $0.id == "drive:drv-local" })
        XCTAssertFalse(snapshot.library.contains { $0.id == "drive:drv-pc" })
        XCTAssertEqual(snapshot.matchedDriveByPCID["pc-smc"]?.id, "drv-pc")

        let filteredPSP = GamingModeCatalog.filter(snapshot.library, query: "god", consoleKey: "psp")
        XCTAssertEqual(filteredPSP.map(\.id), ["drive:drv-psp"])
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

    func testGamingModeSearchAndConsoleFilterPreserveVariantsAndUnidentified() throws {
        let popPSP = ROMFolderGame(relativePath: "PSP/Prince of Persia.iso", filename: "Prince of Persia.iso", title: "Prince of Persia", fileSize: 1024, detectedSystem: .playStationPortable)
        let gbTetris = ROMFolderGame(relativePath: "GB/Tetris.gb", filename: "Tetris.gb", title: "Tetris", fileSize: 512, detectedSystem: .gameBoy)
        let gbaPkmn = ROMFolderGame(relativePath: "GBA/Pokemon.gba", filename: "Pokemon.gba", title: "Pokémon FireRed", fileSize: 512, detectedSystem: .gameBoyAdvance)
        let unknownROM = ROMFolderGame(relativePath: "Outros/Homebrew.bin", filename: "Homebrew.bin", title: "Homebrew Demo", fileSize: 256, detectedSystem: nil)
        let entries: [GamingCatalogEntry] = [
            .local(popPSP, nil),
            .local(gbTetris, nil),
            .local(gbaPkmn, nil),
            .local(unknownROM, nil)
        ]

        let consoles = GamingModeCatalog.availableConsoles(in: entries)
        XCTAssertEqual(consoles.first?.id, "all")
        XCTAssertEqual(consoles.first?.label, "Todos os consoles")
        XCTAssertEqual(consoles.last?.id, "unidentified")
        XCTAssertTrue(consoles.contains { $0.id == "gb" })
        XCTAssertTrue(consoles.contains { $0.id == "gba" })
        XCTAssertTrue(consoles.contains { $0.id == "psp" })

        let accentSearch = GamingModeCatalog.filter(entries, query: "pokemon firered", consoleKey: "all")
        XCTAssertEqual(accentSearch.map(\.title), ["Pokémon FireRed"])

        let pspFiltered = GamingModeCatalog.filter(entries, query: "prince", consoleKey: "psp")
        XCTAssertEqual(pspFiltered.map(\.title), ["Prince of Persia"])

        let emptyResult = GamingModeCatalog.filter(entries, query: "zelda", consoleKey: "psp")
        XCTAssertTrue(emptyResult.isEmpty)
    }

    func testMyBrumControlPairingCodeRoundTripAndStrictValidation() throws {
        let code = try XCTUnwrap(MurbControlPairingCode.encode(host: "192.168.15.42", port: 8089, token: "AB34CD"))
        XCTAssertTrue(code.hasPrefix("MBC-"))
        let decoded = try XCTUnwrap(MurbControlPairingCode.decode(code.lowercased()))
        XCTAssertEqual(decoded.host, "192.168.15.42")
        XCTAssertEqual(decoded.port, 8089)
        XCTAssertEqual(decoded.token, "AB34CD")

        // Corrupting a payload/CRC character must fail CRC-8 check
        var chars = Array(code)
        chars[chars.count - 2] = chars[chars.count - 2] == "Z" ? "A" : "Z"
        XCTAssertNil(MurbControlPairingCode.decode(String(chars)))

        // Strict user input validator accepts MBC and murb:// only
        let fromCode = try XCTUnwrap(MurbPairingPayload.parseUserInput(code))
        XCTAssertEqual(fromCode.host, "192.168.15.42")
        XCTAssertTrue(fromCode.isExternalControl)

        let fromUri = try XCTUnwrap(MurbPairingPayload.parseUserInput("murb://3ds?ip=192.168.15.42&port=8089&token=AB34CD&pc=SALA"))
        XCTAssertEqual(fromUri.system, "3ds")
        XCTAssertEqual(fromUri.pcName, "SALA")

        XCTAssertNil(MurbPairingPayload.parseUserInput("https://evil.example/?ip=192.168.1.5&token=ABCDEF"))
        XCTAssertNil(MurbPairingPayload.parseUserInput("brumclassics://pair?host=192.168.1.5&code=123456"))
        XCTAssertNil(MurbPairingPayload.parseUserInput("murb://ds?ip=127.0.0.1&port=8089&token=AB34CD"))
    }

    private func makeClassicGame(id: String, title: String, platform: String, lastPlayedAt: String = "") throws -> Game {
        let json = """
        {"id":"\(id)","title":"\(title)","description":"","category":"classic","platform":"\(platform)","store":"local","genre":"","collectionId":"","sizeBytes":0,"playtimeMinutes":42,"playtimeAvailable":true,"achievementsCollected":null,"achievementsTotal":null,"achievementsAvailable":false,"achievements":[],"storyCompleted":false,"favorite":false,"wantToPlay":false,"libraryStateRevision":0,"notes":{"whereStopped":"","objectives":"","tips":"","commands":"","revision":0,"updatedAt":""},"installed":true,"integrityStatus":"verified","lastPlayedAt":"\(lastPlayedAt)","artworkPath":""}
        """.data(using: .utf8)!
        return try JSONDecoder().decode(Game.self, from: json)
    }

    func testGamingModeCanonicalUnificationAllTenScenarios() throws {
        // Check Drive root folder hint normalization (e.g. PS1/Resident Evil 2.chd)
        XCTAssertEqual(ClassicDriveLinkParser.detectSystemHint(relativePath: "PS1/Resident Evil 2 (USA).chd", filename: "Resident Evil 2 (USA).chd"), "psx")
        XCTAssertEqual(ClassicDriveLinkParser.detectSystemHint(relativePath: "N64/Resident Evil 2 (USA).z64", filename: "Resident Evil 2 (USA).z64"), "n64")

        let pcOnly = try makeClassicGame(id: "pc-sotn", title: "Castlevania: Symphony of the Night", platform: "PlayStation 1")
        let driveOnly = ClassicDriveGameItem(
            id: "drv-ff7-1", name: "Final Fantasy VII (USA) (Disc 1).chd", title: "Final Fantasy VII",
            relativePath: "PS1/Final Fantasy VII (USA) (Disc 1).chd", folderID: "f-ps1", parentRelativePath: "PS1",
            systemHint: "psx", downloadURL: "https://drive.google.com/uc?id=drv-ff7-1&export=download"
        )
        let driveOnlyDisc2 = ClassicDriveGameItem(
            id: "drv-ff7-2", name: "Final Fantasy VII (USA) (Disc 2).chd", title: "Final Fantasy VII",
            relativePath: "PS1/Final Fantasy VII (USA) (Disc 2).chd", folderID: "f-ps1", parentRelativePath: "PS1",
            systemHint: "ps1", downloadURL: "https://drive.google.com/uc?id=drv-ff7-2&export=download"
        )
        let localOnly = ROMFolderGame(
            relativePath: "GBA/Metroid Fusion (USA).gba", filename: "Metroid Fusion (USA).gba",
            title: "Metroid Fusion", fileSize: 8_388_608, detectedSystem: .gameBoyAdvance
        )

        // Scenario 4: Same game on PC + Google Drive (Resident Evil 2 — PS1 multi-disc) -> 1 unified entry
        let pcRE2PS1 = try makeClassicGame(id: "pc-re2-ps1", title: "Resident Evil 2 [SLUS-00748]", platform: "PlayStation")
        let driveRE2D1 = ClassicDriveGameItem(
            id: "drv-re2-d1", name: "Resident Evil 2 (USA) (Disc 1) [SLUS-00748].chd", title: "Resident Evil 2",
            relativePath: "PS1/Resident Evil 2 (USA) (Disc 1) [SLUS-00748].chd", folderID: "f-ps1", parentRelativePath: "PS1",
            systemHint: "psx", downloadURL: "https://drive.google.com/uc?id=drv-re2-d1&export=download"
        )
        let driveRE2D2 = ClassicDriveGameItem(
            id: "drv-re2-d2", name: "Resident Evil 2 (USA) (Disc 2) [SLUS-00756].chd", title: "Resident Evil 2",
            relativePath: "PS1/Resident Evil 2 (USA) (Disc 2) [SLUS-00756].chd", folderID: "f-ps1", parentRelativePath: "PS1",
            systemHint: "psx", downloadURL: "https://drive.google.com/uc?id=drv-re2-d2&export=download"
        )

        // Scenario 10: Same title on different console (Resident Evil 2 — Nintendo 64) -> separate entry!
        let pcRE2N64 = try makeClassicGame(id: "pc-re2-n64", title: "Resident Evil 2", platform: "Nintendo 64")

        // Scenario 5: Same game in all 3 sources (Local + PC + Drive) -> 1 local entry
        let localSMW = ROMFolderGame(relativePath: "SNES/Super Mario World (USA).sfc", filename: "Super Mario World (USA).sfc", title: "Super Mario World", fileSize: 524_288, detectedSystem: .superNintendo)
        let pcSMW = try makeClassicGame(id: "pc-smw", title: "Super Mario World (Rev 1)", platform: "Super Nintendo")
        let driveSMW = ClassicDriveGameItem(
            id: "drv-smw", name: "Super Mario World (Europe) (Rev A).sfc", title: "Super Mario World",
            relativePath: "SNES/Super Mario World (Europe) (Rev A).sfc", folderID: "f-snes", parentRelativePath: "SNES",
            systemHint: "sfc", downloadURL: "https://drive.google.com/uc?id=drv-smw&export=download"
        )

        let snapBeforeDownload = GamingModeCatalog.buildSnapshot(
            local: [localOnly, localSMW],
            records: [],
            computer: [pcOnly, pcRE2PS1, pcRE2N64, pcSMW],
            cloud: [driveOnly, driveOnlyDisc2, driveRE2D1, driveRE2D2, driveSMW],
            favorites: ["canon:psx|residentevil2"]
        )

        // Expected 6 unique entries: Castlevania SOTN (PC), FF7 (Cloud multi-disc), Metroid Fusion (Local), RE2 N64 (PC), RE2 PS1 (PC+Drive), SMW (Local+PC+Drive)
        XCTAssertEqual(snapBeforeDownload.library.count, 6)
        XCTAssertTrue(snapBeforeDownload.library.contains { $0.id == "pc:pc-sotn" })
        XCTAssertTrue(snapBeforeDownload.library.contains { $0.id == "drive:drv-ff7-1" })
        XCTAssertFalse(snapBeforeDownload.library.contains { $0.id == "drive:drv-ff7-2" })
        XCTAssertEqual(snapBeforeDownload.sourcesByEntryID["drive:drv-ff7-1"]?.isMultiDisc, true)
        XCTAssertEqual(snapBeforeDownload.sourcesByEntryID["pc:pc-re2-ps1"]?.hasCloud, true)
        XCTAssertEqual(snapBeforeDownload.sourcesByEntryID["pc:pc-re2-ps1"]?.driveItems.count, 2)
        XCTAssertTrue(snapBeforeDownload.library.contains { $0.id == "pc:pc-re2-n64" })
        XCTAssertEqual(snapBeforeDownload.sourcesByEntryID["local:\(localSMW.id)"]?.hasComputer, true)
        XCTAssertEqual(snapBeforeDownload.sourcesByEntryID["local:\(localSMW.id)"]?.hasCloud, true)
        XCTAssertTrue(snapBeforeDownload.recent.contains { $0.id == "pc:pc-re2-ps1" })

        // Scenarios 6 & 9: Download RE2 Disc 1 & Disc 2 locally -> stays 6 entries, upgrades RE2 PS1 to .local, keeps favorite pinned!
        let localRE2D1 = ROMFolderGame(relativePath: "PS1/Resident Evil 2 (USA) (Disc 1) [SLUS-00748].chd", filename: "Resident Evil 2 (USA) (Disc 1) [SLUS-00748].chd", title: "Resident Evil 2", fileSize: 400_000_000, detectedSystem: .playStation)
        let localRE2D2 = ROMFolderGame(relativePath: "PS1/Resident Evil 2 (USA) (Disc 2) [SLUS-00756].chd", filename: "Resident Evil 2 (USA) (Disc 2) [SLUS-00756].chd", title: "Resident Evil 2", fileSize: 420_000_000, detectedSystem: .playStation)
        let snapAfterDownload = GamingModeCatalog.buildSnapshot(
            local: [localOnly, localSMW, localRE2D1, localRE2D2],
            records: [],
            computer: [pcOnly, pcRE2PS1, pcRE2N64, pcSMW],
            cloud: [driveOnly, driveOnlyDisc2, driveRE2D1, driveRE2D2, driveSMW],
            favorites: ["canon:psx|residentevil2"]
        )
        XCTAssertEqual(snapAfterDownload.library.count, 6)
        XCTAssertTrue(snapAfterDownload.library.contains { $0.id == "local:\(localRE2D1.id)" })
        XCTAssertFalse(snapAfterDownload.library.contains { $0.id == "local:\(localRE2D2.id)" })
        XCTAssertFalse(snapAfterDownload.library.contains { $0.id == "pc:pc-re2-ps1" })
        XCTAssertEqual(snapAfterDownload.sourcesByEntryID["local:\(localRE2D1.id)"]?.localROMs.count, 2)
        XCTAssertEqual(snapAfterDownload.sourcesByEntryID["local:\(localRE2D1.id)"]?.isMultiDisc, true)
        XCTAssertEqual(snapAfterDownload.sourcesByEntryID["local:\(localRE2D1.id)"]?.computerGame?.id, "pc-re2-ps1")
        XCTAssertTrue(snapAfterDownload.recent.contains { $0.id == "local:\(localRE2D1.id)" })

        // Scenarios 7 & 8: Delete local copies of FF7/RE2 while keeping Drive copies -> no duplication, cloud copy restored cleanly
        let downloadedFF7 = ROMFolderGame(relativePath: "__drive__/psx/Final Fantasy VII (USA) (Disc 1).chd", filename: "Final Fantasy VII (USA) (Disc 1).chd", title: "Final Fantasy VII", fileSize: 500_000_000, detectedSystem: .playStation)
        let snapFF7Local = GamingModeCatalog.buildSnapshot(local: [downloadedFF7], records: [], computer: [], cloud: [driveOnly, driveOnlyDisc2])
        XCTAssertEqual(snapFF7Local.library.map(\.id), ["local:\(downloadedFF7.id)"])
        let snapFF7DeletedLocal = GamingModeCatalog.buildSnapshot(local: [], records: [], computer: [], cloud: [driveOnly, driveOnlyDisc2])
        XCTAssertEqual(snapFF7DeletedLocal.library.map(\.id), ["drive:drv-ff7-1"])
    }

    func testSyncIndicatorStateReflectsRealSyncGreenOrangeRed() {
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        // Verde: pareado, online, sem pendências, sem conflitos, sem falha e última sincronização concluída
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .online,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .synced
        )

        // Laranja: sincronizando / conectando / fila pendente aguardando envio online
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .connecting,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .syncing
        )
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .online,
                isSyncing: true,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .syncing
        )
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .online,
                isSyncing: false,
                pendingCount: 2,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .syncing
        )

        // Vermelho: não pareado, offline, erro, conflito ou falha de sincronização (mesmo com rede conectada)
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: false,
                connection: .offline,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: nil,
                lastSyncFailed: false
            ),
            .unsynced
        )
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .offline,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .unsynced
        )
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .online,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 1,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: false
            ),
            .unsynced
        )
        XCTAssertEqual(
            AppStore.resolveSyncIndicatorState(
                isPaired: true,
                connection: .online,
                isSyncing: false,
                pendingCount: 0,
                conflictCount: 0,
                lastSuccessfulSyncAt: syncedAt,
                lastSyncFailed: true
            ),
            .unsynced
        )
    }
}
