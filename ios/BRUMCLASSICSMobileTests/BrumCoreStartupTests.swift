import XCTest
import UIKit
@testable import BRUMCLASSICSMobile

final class BrumCoreStartupTests: XCTestCase {
    func testDiagnosticsPreserveFailureStageThroughCleanupAndRedactLocalPaths() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("session.json")
        let diagnostics = BrumCoreDiagnostics(context: ["coreID": "probe"], report: report, redactedPaths: ["/private/game.3ds"])
        diagnostics.enterStage("load_content")
        diagnostics.recordMessage("bad key for /private/game.3ds", level: 3)
        diagnostics.recordMessage("later warning", level: 2)
        diagnostics.recordFailure("rejected /private/game.3ds")
        diagnostics.markStopped()
        diagnostics.markRunning()
        diagnostics.enterStage("cleanup")
        XCTAssertEqual(diagnostics.snapshot["stage"] as? String, "load_content")
        XCTAssertEqual(diagnostics.snapshot["outcome"] as? String, "failed")
        XCTAssertEqual(diagnostics.failureDetail, "bad key for <local>")
        XCTAssertFalse(diagnostics.reportText.contains("/private/game.3ds"))
        let reloaded = BrumCoreDiagnostics(context: [:], report: report, redactedPaths: [])
        let previous = try XCTUnwrap(reloaded.snapshot["previousAttempt"] as? [String: Any])
        XCTAssertEqual(previous["outcome"] as? String, "failed")
        XCTAssertEqual(previous["stage"] as? String, "load_content")
        XCTAssertNil(previous["previousAttempt"])
    }

    func testDiagnosticsBoundConcurrentLogMessagesAndKeepUnfinishedPreviousMarker() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("session.json")
        let diagnostics = BrumCoreDiagnostics(context: [:], report: report, redactedPaths: [])
        diagnostics.enterStage("first_frame")
        diagnostics.recordMessage("initial fatal error", level: 3)
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            diagnostics.recordMessage("\(i):" + String(repeating: "x", count: 4096), level: 2)
        }
        let messages = try XCTUnwrap(diagnostics.snapshot["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 32)
        XCTAssertEqual(diagnostics.failureDetail, "initial fatal error")
        XCTAssertTrue(messages.allSatisfy { ($0["text"] as? String)?.count == 2048 })
        let next = BrumCoreDiagnostics(context: [:], report: report, redactedPaths: [])
        let marker = try XCTUnwrap(next.snapshot["previousAttempt"] as? [String: Any])
        XCTAssertEqual(marker["outcome"] as? String, "starting")
        XCTAssertEqual(marker["stage"] as? String, "first_frame")
    }

    func testAudioFailureCheckpointPersistsEvidenceWithoutStoppingVideoSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        let diagnostics = BrumCoreDiagnostics(context: [:], report: url, redactedPaths: [])
        diagnostics.markRunning()
        diagnostics.setMetrics(["audioQueueActive": false, "audioSamplesProduced": 8])
        diagnostics.recordMessage("Host de áudio: queue restart failed", level: 3)
        diagnostics.checkpoint()
        let data = try Data(contentsOf: url)
        let persisted = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(persisted["outcome"] as? String, "running")
        XCTAssertEqual(persisted["lastCoreError"] as? String, "Host de áudio: queue restart failed")
        let metrics = try XCTUnwrap(persisted["metrics"] as? [String: Any])
        XCTAssertEqual(metrics["audioQueueActive"] as? Bool, false)
    }

    @MainActor
    private func withProbe(mode: UInt8, filenameExtension: String = "brumtest", systemID: String = "gba", body: (BrumLibretroViewController, () -> Int, () -> Int) throws -> Void) throws {
        let rom = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(filenameExtension)
        try Data([mode]).write(to: rom)
        defer { try? FileManager.default.removeItem(at: rom) }
        let library = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BrumTestCore", withExtension: "dylib"))
        let frameworks = URL(fileURLWithPath: Bundle.main.privateFrameworksPath ?? (Bundle.main.bundlePath as NSString).appendingPathComponent("Frameworks"))
        let source = frameworks.pathComponents
        let destination = library.pathComponents
        let common = zip(source, destination).prefix(while: { $0.0 == $0.1 }).count
        let relativeLibrary = (Array(repeating: "..", count: source.count - common) + destination.dropFirst(common)).joined(separator: "/")
        var ready = 0
        var exited = 0
        let controller = BrumLibretroViewController(romurl: rom, title: "probe", canonicalGameID: "probe",
            systemID: systemID, contentSHA256: String(repeating: "a", count: 64), coreID: "startup-probe", coreVersion: "1",
            coreDisplayName: "Startup probe", coreLibraryName: relativeLibrary, retroAchievementsGameID: 0,
            saveIdentifier: "probe", legacySaveBasename: "probe", onReady: { ready += 1 }, onExit: { exited += 1 })
        controller.loadViewIfNeeded()
        defer { controller.stopCore() }
        try body(controller, { ready }, { exited })
    }

    @MainActor func testPSPCoreReceivesExactInterpreterOptionBeforeContentLoad() throws {
        try withProbe(mode: 73) { controller, ready, _ in
            controller.runFrame()
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
        }
    }

    @MainActor func testRejectedContentCanStillExitAndNeverSignalsReady() throws {
        try withProbe(mode: 82) { controller, ready, exited in
            let report = controller.diagnosticsReport
            XCTAssertTrue(report.contains("probe: rejected content"), report)
            XCTAssertTrue(report.contains("load_content"))
            XCTAssertEqual(ready(), 0)
            let close = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "brum-core-exit" })
            close.sendActions(for: .touchUpInside)
            close.sendActions(for: .touchUpInside)
            XCTAssertEqual(exited(), 1)
        }
    }

    @MainActor func testCoreExtensionAndAVTimingAreValidatedBeforeRunning() throws {
        try withProbe(mode: 86, filenameExtension: "wrong") { controller, ready, _ in
            XCTAssertTrue(controller.diagnosticsReport.contains("inspect_content"))
            XCTAssertTrue(controller.diagnosticsReport.contains("não aceita"))
            controller.runFrame()
            XCTAssertEqual(ready(), 0)
        }
        try withProbe(mode: 84) { controller, ready, _ in
            XCTAssertTrue(controller.diagnosticsReport.contains("cadência"))
            controller.runFrame()
            XCTAssertEqual(ready(), 0)
        }
        try withProbe(mode: 71) { controller, ready, _ in
            controller.runFrame()
            XCTAssertEqual(ready(), 0)
            XCTAssertTrue(controller.diagnosticsReport.contains("geometria"))
        }
    }

    @MainActor func testFirstFrameShutdownPreservesCoreErrorAndDoesNotSignalReady() throws {
        try withProbe(mode: 83) { controller, ready, _ in
            controller.runFrame()
            XCTAssertTrue(controller.diagnosticsReport.contains("probe: required BIOS missing"), controller.diagnosticsReport)
            let data = try XCTUnwrap(controller.diagnosticsReport.data(using: .utf8))
            let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(report["outcome"] as? String, "failed")
            XCTAssertEqual(ready(), 0)
        }
    }

    @MainActor func testReadyIsDeliveredAfterVideoOnlyOnceAndAudioProductionIsMeasured() throws {
        try withProbe(mode: 86) { controller, ready, _ in
            XCTAssertEqual(ready(), 0)
            controller.runFrame()
            controller.runFrame()
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
            let report = try XCTUnwrap(controller.diagnosticsReport.data(using: .utf8))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: report) as? [String: Any])
            let metrics = try XCTUnwrap(json["metrics"] as? [String: Any])
            XCTAssertGreaterThan((metrics["audioSamplesProduced"] as? NSNumber)?.intValue ?? 0, 0)
            XCTAssertEqual(json["outcome"] as? String, "running")
            controller.stopCore()
            controller.runFrame()
            XCTAssertEqual(ready(), 1)
        }
    }
    @MainActor func testLargeAdvertisedCapacityDoesNotRejectSmallValidFrames() throws {
        // Like Azahar, this probe reserves 7200x4800 while rendering a small
        // native frame. The host must not confuse a capacity hint with a limit.
        try withProbe(mode: 77) { controller, ready, _ in
            controller.runFrame()
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
        }
    }

    @MainActor func testPreFirstFrameSerializeSizeIsNotCalledAndJitIsDisabled() throws {
        // Mode 'P' (80) traps inside retro_serialize_size if invoked before frame 1
        // and verifies GET_JIT_CAPABLE == false and citra_use_cpu_jit == "disabled".
        try withProbe(mode: 80) { controller, ready, _ in
            controller.runFrame()
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
        }
    }

    func testPSPFolderHintAndIdentityCacheInvalidateOnContentChange() throws {
        XCTAssertEqual(ROMFolderScanner.folderSystemHint(folderName: "psp", extension: "iso"), .playStationPortable)
        XCTAssertEqual(ROMFolderScanner.folderSystemHint(folderName: "playstation portable", extension: "cso"), .playStationPortable)
        XCTAssertEqual(ROMFolderScanner.folderSystemHint(folderName: "sony psp", extension: "pbp"), .playStationPortable)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let csoURL = directory.appendingPathComponent("demo.cso")
        try Data([0x43, 0x49, 0x53, 0x4F, 0x01, 0x02]).write(to: csoURL)
        let first = try ROMContentInspector.inspect(url: csoURL, filename: "demo.cso")
        let cached = try ROMContentInspector.inspect(url: csoURL, filename: "demo.cso")
        XCTAssertEqual(first.systemID, .playStationPortable)
        XCTAssertEqual(first.contentSHA256, cached.contentSHA256)

        try Data([0x43, 0x49, 0x53, 0x4F, 0x09, 0x0A, 0x0B]).write(to: csoURL)
        let modified = try ROMContentInspector.inspect(url: csoURL, filename: "demo.cso")
        XCTAssertNotEqual(first.contentSHA256, modified.contentSHA256)
    }

    @MainActor func testPSPVirtualControlsExposeBothDPadAndStickAndLatchQuickTaps() throws {
        try withProbe(mode: 73, systemID: "psp") { controller, _, _ in
            let allControls = controller.view.subviews.compactMap { $0 as? UIControl }
            let dpad = allControls.first { $0.accessibilityLabel == "Direcional virtual" }
            let stick = allControls.first { $0.accessibilityLabel == "Controle analógico" }
            let modeButton = controller.view.subviews.compactMap { $0 as? UIButton }
                .first { $0.accessibilityLabel == "Alternar analógico e direcional digital" }
            XCTAssertNotNil(dpad)
            XCTAssertNotNil(stick)
            XCTAssertFalse(try XCTUnwrap(dpad).isHidden)
            XCTAssertFalse(try XCTUnwrap(stick).isHidden)
            XCTAssertNil(modeButton)
        }

        func findButton(titled title: String, in root: UIView) -> UIButton? {
            for subview in root.subviews {
                if let button = subview as? UIButton, button.title(for: .normal) == title {
                    return button
                }
                if let nested = findButton(titled: title, in: subview) {
                    return nested
                }
            }
            return nil
        }

        try withProbe(mode: 75, systemID: "psx") { controller, ready, _ in
            let cross = try XCTUnwrap(findButton(titled: "×", in: controller.view))
            cross.sendActions(for: .touchDown)
            cross.sendActions(for: .touchUpInside)
            for _ in 0..<8 {
                controller.runFrame()
                if ready() == 1 { break }
                Thread.sleep(forTimeInterval: 0.02)
            }
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
        }
    }

    @MainActor func testTouchAndRepeatedCapabilityQueriesDoNotRepeatedlyProbeSerializeSize() throws {
        try withProbe(mode: 67, systemID: "psx") { controller, ready, _ in
            controller.runFrame()
            XCTAssertEqual(ready(), 1, controller.diagnosticsReport)
            controller.perform(Selector(("toggleDisplayMode")))
            let firstCaps = controller.capabilities
            let secondCaps = controller.capabilities
            XCTAssertTrue(firstCaps.contains(.saveState))
            XCTAssertEqual(firstCaps, secondCaps)
            controller.perform(Selector(("toggleDisplayMode")))
            Thread.sleep(forTimeInterval: 0.02)
            controller.runFrame()
        }
    }
}
