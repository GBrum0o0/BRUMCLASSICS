import XCTest

final class NavigationTests: XCTestCase {
    func testClassicsEverywhereOpensFromHomeAndReturns() {
        let app = XCUIApplication(); app.launch()
        let link = app.buttons["classics-everywhere-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        if !link.isHittable { app.swipeUp() }
        link.tap()
        XCTAssertTrue(app.buttons["rom-folder-refresh"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Início"].exists)
    }
    func testAndroidAlignedTabsAndCompanionWithoutRemoteControls() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Companion"].waitForExistence(timeout: 15))
        for tab in ["Início", "Biblioteca", "Estatísticas", "Companion", "Perfil"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.exists)
            button.tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = tab
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.tabBars.buttons["Companion"].tap()
        XCTAssertTrue(app.staticTexts["Sua segunda tela."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["DESLIGAR"].exists)
        XCTAssertFalse(app.buttons["SUSPENDER"].exists)
        XCTAssertFalse(app.staticTexts["PESQUISA NO LIVING ROOM"].exists)
        XCTAssertTrue(app.staticTexts["FPS"].exists)
        if !app.buttons["companion-capture"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["companion-capture"].exists)
        XCTAssertFalse(app.buttons["companion-capture"].isEnabled)
        app.tabBars.buttons["Perfil"].tap()
        app.buttons["mobile-settings-link"].tap()
        XCTAssertTrue(app.staticTexts["Ao iniciar um clássico"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continuar no auto save"].exists || app.staticTexts["Continuar no auto save"].exists)
    }
}
