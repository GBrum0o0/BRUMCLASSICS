import XCTest
@testable import BRUMCLASSICSMobile

final class GraphicsResolutionPackTests: XCTestCase {
    func testCatalogCovers2DAnd3DConsolesAndResolvesMultipliersSafely() {
        let suiteName = "brum.graphics.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pack = GraphicsResolutionPack(defaults: defaults)
        XCTAssertGreaterThanOrEqual(GraphicsResolutionPack.catalog.count, 32)

        let pspHigh = pack.resolve(systemID: "psp", hardwareTier: .high)
        XCTAssertEqual(pspHigh.internalMultiplier, 3)
        XCTAssertEqual(pspHigh.coreVariables["ppsspp_internal_resolution"], "1440x816")
        XCTAssertTrue(pspHigh.preserveAspectRatio)

        let pspLow = pack.resolve(systemID: "psp", hardwareTier: .low)
        XCTAssertEqual(pspLow.internalMultiplier, 1)
        XCTAssertEqual(pspLow.coreVariables["ppsspp_internal_resolution"], "480x272")

        let gbaAuto = pack.resolve(systemID: "gba", hardwareTier: .high)
        XCTAssertFalse(gbaAuto.is3D)
        XCTAssertEqual(gbaAuto.internalMultiplier, 1)
        XCTAssertTrue(gbaAuto.integerScalingEnabled)

        var custom = GraphicsResolutionSettings(profile: .custom)
        custom.systems["snes"] = GraphicsSystemOverride(profile: .custom, multiplier: 4, scaleMode: .integer, videoFilter: .crtScanlines)
        pack.saveSettings(custom)

        let reloaded = GraphicsResolutionPack(defaults: defaults).resolve(systemID: "sfc", hardwareTier: .medium)
        XCTAssertEqual(reloaded.systemID, "snes")
        XCTAssertEqual(reloaded.internalMultiplier, 1)
        XCTAssertEqual(reloaded.videoFilterMode, "crt_scanlines")
        XCTAssertTrue(reloaded.integerScalingEnabled)

        _ = pack.resetSettings()
        let resetOrig = pack.resolve(systemID: "psp", settings: GraphicsResolutionSettings(profile: .original), hardwareTier: .high)
        XCTAssertEqual(resetOrig.internalMultiplier, 1)
        XCTAssertEqual(resetOrig.coreVariables["ppsspp_internal_resolution"], "480x272")

        for shader in [GraphicsVideoFilter.casSharpen, .sharpBilinear, .edgeUpscale2x] {
            var shaderSettings = GraphicsResolutionSettings(profile: .custom)
            shaderSettings.globalVideoFilter = shader
            let resolved2D = pack.resolve(systemID: "gba", settings: shaderSettings, hardwareTier: .high)
            XCTAssertEqual(resolved2D.videoFilterMode, shader.rawValue)
            let resolved3D = pack.resolve(systemID: "psp", settings: shaderSettings, hardwareTier: .high)
            XCTAssertEqual(resolved3D.videoFilterMode, shader.rawValue)
        }
    }
}
