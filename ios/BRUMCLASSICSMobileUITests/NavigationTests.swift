import XCTest

final class NavigationTests: XCTestCase {
    func testProfileMovedInsideHome() {
        let app = XCUIApplication(); app.launch()
        let link = app.buttons["profile-home-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        if !link.isHittable { app.swipeUp() }
        link.tap()
        XCTAssertTrue(app.buttons["mobile-settings-link"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["main-tab-0"].exists)
    }
    func testGamingModeAndCompanionWithoutRemoteControls() {
        let app = XCUIApplication()
        app.launch()
        for tab in ["main-tab-0", "main-tab-1", "gaming-mode-tab", "main-tab-3", "main-tab-4"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 15), "Navegação ausente: \(tab)")
        }

        app.buttons["gaming-mode-tab"].tap()
        XCTAssertTrue(app.staticTexts["BIBLIOTECA"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["main-tab-0"].exists)

        let gamingAttachment = XCTAttachment(screenshot: app.screenshot())
        gamingAttachment.name = "Gaming Mode"
        gamingAttachment.lifetime = .keepAlways
        add(gamingAttachment)

        app.buttons["gaming-mode-exit"].tap()
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 5))
        app.buttons["main-tab-3"].tap()
        XCTAssertTrue(app.staticTexts["Estatísticas"].waitForExistence(timeout: 5))
        app.buttons["main-tab-4"].tap()
        XCTAssertTrue(app.staticTexts["Sua segunda tela."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["DESLIGAR"].exists)
        XCTAssertFalse(app.buttons["SUSPENDER"].exists)
        XCTAssertFalse(app.staticTexts["PESQUISA NO LIVING ROOM"].exists)
        XCTAssertTrue(app.staticTexts["FPS"].exists)
        if !app.buttons["companion-capture"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["companion-capture"].exists)
        XCTAssertFalse(app.buttons["companion-capture"].isEnabled)
        app.buttons["main-tab-0"].tap()
        let profile = app.buttons["profile-home-link"]
        if !profile.isHittable { app.swipeUp() }
        profile.tap()
        app.buttons["mobile-settings-link"].tap()
        if !app.staticTexts["Ao iniciar um clássico"].waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Ao iniciar um clássico"].waitForExistence(timeout: 5))
    }
}
