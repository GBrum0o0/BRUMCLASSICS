import XCTest
@testable import BRUMCLASSICSMobile

private final class MockDriveTransport: ClassicDriveHTTPTransport, @unchecked Sendable {
    var failSecondFolder = false
    var downloadPayload = Data("GBA_ROM_BYTES".utf8)

    func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data) {
        if folderID == "rootFolder_123456" {
            // Mix real nested Google Drive embeddedfolderview flip-entry HTML with HTML entities,
            // resourcekey params, PC executables, and >100 subfolders to cover real-world responses.
            var html = "<title>Minha Biblioteca - Google Drive</title>"
            html += """
            <div class="flip-entry" id="entry-gameFile_1234567890">
              <div class="flip-entry-info">
                <a href="https://drive.google.com/file/d/gameFile_1234567890/view?usp=drive_web" target="_blank">
                  <div class="flip-entry-thumb"><img src="https://ssl.gstatic.com/docs/doclist/images/icon.png" alt=""></div>
                  <div class="flip-entry-title">Minish Cap &amp; Link (U).gba</div>
                </a>
              </div>
            </div>
            """
            html += "<a href=\"https://drive.google.com/file/d/setupExe_1234567890/view\">Installer.exe</a>"
            for i in 0..<105 {
                let rk = i == 0 ? "?resourcekey=0-RkTest123" : ""
                html += "<a href=\"https://drive.google.com/drive/folders/subFolder_\(i)\(rk)\"><div class=\"flip-entry-thumb\"></div><div class=\"flip-entry-title\">Sub &#x23;\(i)</div></a>"
            }
            return (200, Data(html.utf8))
        }
        if folderID == "subFolder_1" && failSecondFolder {
            throw ClassicDriveError.networkFailure("Conexão perdida")
        }
        let subHtml = "<a href=\"https://drive.google.com/drive/folders/rootFolder_123456\"><div class=\"flip-entry-title\">BackLoop</div></a>"
            + "<a href=\"https://drive.google.com/file/d/subGame_\(folderID)/view\"><div>Game_\(folderID).nes</div></a>"
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
        XCTAssertEqual(ClassicDriveLinkParser.parseFolderID(from: "https://drive.google.com/folderview?id=1AbCdEfGhIjKlMnOpQrStUv&resourcekey=0-Abc"), "1AbCdEfGhIjKlMnOpQrStUv")
        XCTAssertNil(ClassicDriveLinkParser.parseFolderID(from: "http://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv"))
        XCTAssertNil(ClassicDriveLinkParser.parseFolderID(from: "https://evil.example.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv"))
        XCTAssertTrue(ClassicDriveLinkParser.isExcludedPCFile("Installer.exe"))
        XCTAssertTrue(ClassicDriveLinkParser.isAcceptedClassicROM("Minish Cap (U).gba"))

        let parsedNested = ClassicDriveHtmlParser.parseFolderHTML("""
        <title>PSP - Google Drive</title>
        <div class="flip-entry">
          <a href="https://drive.google.com/file/d/pspFile_1234567890/view?usp=drive_web&amp;resourcekey=0-Key1">
            <div class="flip-entry-thumb"></div>
            <div class="flip-entry-title">Crisis Core &amp; Final Fantasy &#x28;USA&#x29;.cso</div>
          </a>
        </div>
        <a href="https://drive.google.com/drive/folders/subPsp_1234567890?usp=drive_web">
          <div class="flip-entry-title">PSP</div>
        </a>
        """)
        XCTAssertEqual(parsedNested.files.first?.id, "pspFile_1234567890")
        XCTAssertEqual(parsedNested.files.first?.name, "Crisis Core & Final Fantasy (USA).cso")
        XCTAssertEqual(parsedNested.subfolders.first?.id, "subPsp_1234567890")
        XCTAssertEqual(parsedNested.subfolders.first?.name, "PSP")

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
