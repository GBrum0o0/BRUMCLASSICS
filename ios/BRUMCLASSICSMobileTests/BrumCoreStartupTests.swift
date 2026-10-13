import XCTest
import UIKit
@testable import BRUMCLASSICSMobile

final class BrumCoreStartupTests: XCTestCase {
    func testDiagnosticsPreserveFailureStageThroughCleanupAndRedactLocalPaths() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("session.json")
        let diagnostics = BrumCoreDiagnostics(context: ["coreID": "probe"], reportURL: report, redactedPaths: ["/private/game.3ds"])
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
        let reloaded = BrumCoreDiagnostics(context: [:], reportURL: report, redactedPaths: [])
        let previous = try XCTUnwrap(reloaded.snapshot["previousAttempt"] as? [String: Any])
        XCTAssertEqual(previous["outcome"] as? String, "failed")
        XCTAssertEqual(previous["stage"] as? String, "load_content")
        XCTAssertNil(previous["previousAttempt"])
    }

    func testDiagnosticsBoundConcurrentLogMessagesAndKeepUnfinishedPreviousMarker() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("session.json")
        let diagnostics = BrumCoreDiagnostics(context: [:], reportURL: report, redactedPaths: [])
        diagnostics.enterStage("first_frame")
        diagnostics.recordMessage("initial fatal error", level: 3)
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            diagnostics.recordMessage("\(i):" + String(repeating: "x", count: 4096), level: 2)
        }
        let messages = try XCTUnwrap(diagnostics.snapshot["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 32)
        XCTAssertEqual(diagnostics.failureDetail, "initial fatal error")
        XCTAssertTrue(messages.allSatisfy { ($0["text"] as? String)?.count == 2048 })
        let next = BrumCoreDiagnostics(context: [:], reportURL: report, redactedPaths: [])
        let marker = try XCTUnwrap(next.snapshot["previousAttempt"] as? [String: Any])
        XCTAssertEqual(marker["outcome"] as? String, "starting")
        XCTAssertEqual(marker["stage"] as? String, "first_frame")
    }

    @MainActor
    private func withProbe(mode: UInt8, filenameExtension: String = "brumtest", body: (BrumLibretroViewController, () -> Int, () -> Int) throws -> Void) throws {
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
            systemID: "gba", contentSHA256: String(repeating: "a", count: 64), coreID: "startup-probe", coreVersion: "1",
            coreDisplayName: "Startup probe", coreLibraryName: relativeLibrary, retroAchievementsGameID: 0,
            saveIdentifier: "probe", legacySaveBasename: "probe", onReady: { ready += 1 }, onExit: { exited += 1 })
        controller.loadViewIfNeeded()
        defer { controller.stopCore() }
        try body(controller, { ready }, { exited })
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
    }

    @MainActor func testFirstFrameShutdownPreservesCoreErrorAndDoesNotSignalReady() throws {
        try withProbe(mode: 83) { controller, ready, _ in
            controller.runFrame()
            XCTAssertTrue(controller.diagnosticsReport.contains("probe: required BIOS missing"), controller.diagnosticsReport)
            XCTAssertTrue(controller.diagnosticsReport.contains("\"outcome\" : \"failed\""))
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
}
