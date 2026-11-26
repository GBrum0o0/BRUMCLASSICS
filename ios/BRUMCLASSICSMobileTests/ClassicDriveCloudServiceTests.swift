import XCTest
@testable import BRUMCLASSICSMobile

private final class MockDriveTransport: ClassicDriveHTTPTransport, @unchecked Sendable {
    var failSecondFolder = false
    var downloadPayload = Data("GBA_ROM_BYTES".utf8)

    func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data) {
        if folderID == "rootFolder_123456" {
            var html = "<a href=\"https://drive.google.com/file/d/gameFile_1234567890/view\">Minish Cap (U).gba</a>"
            html += "<a href=\"https://drive.google.com/file/d/setupExe_1234567890/view\">Installer.exe</a>"
            for i in 0..<105 {
                html += "<a href=\"https://drive.google.com/drive/folders/subFolder_\(i)\">Sub \(i)</a>"
            }
            return (200, Data(html.utf8))
        }
        if folderID == "subFolder_1" && failSecondFolder {
            throw ClassicDriveError.networkFailure("Conexão perdida")
        }
        let subHtml = "<a href=\"https://drive.google.com/drive/folders/rootFolder_123456\">BackLoop</a>"
            + "<a href=\"https://drive.google.com/file/d/subGame_\(folderID)/view\">Game_\(folderID).nes</a>"
        return (200, Data(subHtml.utf8))
    }

    func downloadFile(url: URL, to destination: URL, bearerToken: String?, progress: @Sendable (Int64, Int64?) -> Void) async throws -> Int64 {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try downloadPayload.write(to: destination)
        progress(Int64(downloadPayload.count), Int64(downloadPayload.count))
        return Int64(downloadPayload.count)
    }
}

final class ClassicDriveCloudServiceTests: XCTestCase {
    func testLinkValidationBatchedScanAndOfflineDownload() async throws {
        XCTAssertEqual(ClassicDriveLinkParser.parseFolderID(from: "https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv"), "1AbCdEfGhIjKlMnOpQrStUv")
        XCTAssertNil(ClassicDriveLinkParser.parseFolderID(from: "http://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv"))
        XCTAssertNil(ClassicDriveLinkParser.parseFolderID(from: "https://evil.example.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv"))
        XCTAssertTrue(ClassicDriveLinkParser.isExcludedPCFile("Installer.exe"))
        XCTAssertTrue(ClassicDriveLinkParser.isAcceptedClassicROM("Minish Cap (U).gba"))

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("brum-drive-ios-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let transport = MockDriveTransport()
        transport.failSecondFolder = true
        let service = ClassicDriveCloudService(
            stateDirectory: tempDir.appendingPathComponent("state", isDirectory: true),
            defaultDownloadRoot: tempDir.appendingPathComponent("downloads", isDirectory: true),
            transport: transport
        )

        do {
            _ = try await service.startOrRefreshScan(folderURL: "https://drive.google.com/drive/folders/rootFolder_123456")
            XCTFail("Expected simulated network interruption")
        } catch {
            // Expected
        }

        transport.failSecondFolder = false
        let batch1 = try await service.continueScan()
        XCTAssertFalse(batch1.completed)

        let batch2 = try await service.continueScan()
        XCTAssertTrue(batch2.completed)
        XCTAssertEqual(batch2.items.count, 106)
        XCTAssertFalse(batch2.items.contains { $0.name == "Installer.exe" })

        let cloudItem = try XCTUnwrap(batch2.items.first { $0.id == "gameFile_1234567890" })
        let beforeDownload = await service.availabilityState(for: cloudItem)
        XCTAssertEqual(beforeDownload, .inCloud)

        let downloadedURL = try await service.downloadGame(fileID: "gameFile_1234567890")
        XCTAssertTrue(FileManager.default.fileExists(atPath: downloadedURL.path))
        let afterCp = await service.currentCheckpoint()
        let updatedItem = try XCTUnwrap(afterCp.items.first { $0.id == "gameFile_1234567890" })
        let afterState = await service.availabilityState(for: updatedItem)
        XCTAssertEqual(afterState, .available)
        XCTAssertEqual(ClassicAvailabilityState.resolve(isClassic: true, installedLocally: false, availableInCloud: false, isDownloading: false), .onComputer)
    }
}
