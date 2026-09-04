import XCTest

final class NavigationTests: XCTestCase {
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
    }
}
