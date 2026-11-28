import XCTest

final class NavigationTests: XCTestCase {
    func testProfileAndSettingsSeparatedAndHomeScrollReachesJourney() {
        let app = XCUIApplication(); app.launch()
        let profileLink = app.buttons["profile-home-link"]
        XCTAssertTrue(profileLink.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home-controllers"].exists)
        XCTAssertTrue(app.buttons["home-qr-control"].exists)
        XCTAssertTrue(app.buttons["home-settings"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "sync-status-indicator").firstMatch.exists)

        // Indicador sem textos visíveis, sem card de sincronização e sem central de notificações visível no Início
        XCTAssertFalse(app.staticTexts["CONECTADO"].exists)
        XCTAssertFalse(app.staticTexts["OFFLINE"].exists)
        XCTAssertFalse(app.staticTexts["SINCRONIZANDO"].exists)
        XCTAssertFalse(app.staticTexts["Tudo sincronizado"].exists)
        XCTAssertFalse(app.staticTexts["NOTIFICAÇÕES"].exists)

        // Rolar até Minha Jornada sem ficar preso atrás da barra inferior
        for _ in 0..<5 {
            if app.staticTexts["MINHA JORNADA"].exists && app.staticTexts["MINHA JORNADA"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["MINHA JORNADA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MINHA JORNADA"].isHittable)

        for _ in 0..<6 {
            if profileLink.exists && profileLink.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(profileLink.waitForExistence(timeout: 5))
        profileLink.tap()
        for _ in 0..<4 {
            if app.buttons["profile-ra-link"].exists && app.buttons["profile-ra-link"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["profile-ra-link"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile-drive-link"].exists)
        XCTAssertFalse(app.buttons["mobile-settings-link"].exists)

        // Verificar conta RetroAchievements dentro do Perfil
        app.buttons["profile-ra-link"].tap()
        XCTAssertTrue(app.textFields["gaming-mode-ra-username"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["gaming-mode-ra-key"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["profile-ra-link"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["main-tab-0"].waitForExistence(timeout: 5))

        // Abrir Configurações técnicas separadamente pelo ícone de engrenagem
        app.buttons["home-settings"].tap()
        XCTAssertTrue(app.buttons["gaming-mode-choose-rom-folder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["gaming-mode-ra-username"].exists)
        for _ in 0..<6 {
            if app.staticTexts["Ao iniciar um clássico"].exists && app.staticTexts["Ao iniciar um clássico"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Ao iniciar um clássico"].waitForExistence(timeout: 5))
        app.navigationBars["Configurações"].buttons["Fechar"].tap()
    }

    func testGamingModeExtensionsQRAndCompanionWithoutStatsChartRegression() {
        let app = XCUIApplication()
        app.launch()
        for tab in ["main-tab-0", "main-tab-1", "gaming-mode-tab", "main-tab-3", "main-tab-4"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 15), "Navegação ausente: \(tab)")
        }

        app.buttons["gaming-mode-tab"].tap()
        XCTAssertTrue(app.buttons["gaming-mode-library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gaming-mode-extensions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gaming-mode-qr-control"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["gaming-mode-profile"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gaming-mode-mybrumcontrol"].exists)
        app.buttons["gaming-mode-extensions"].tap()
        XCTAssertTrue(app.buttons["pokedex-open-device"].waitForExistence(timeout: 5))
        app.buttons["pokedex-open-device"].tap()
        XCTAssertTrue(app.buttons["pokedex-tab-pokemon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pokedex-tab-shinies"].exists)
        app.buttons["gaming-mode-recent"].tap()
        app.buttons["gaming-mode-controllers"].tap()
        XCTAssertTrue(app.navigationBars["Controles"].waitForExistence(timeout: 5))
        app.navigationBars["Controles"].buttons["Fechar"].tap()
        app.buttons["gaming-mode-settings"].tap()
        XCTAssertTrue(app.buttons["gaming-mode-choose-rom-folder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["gaming-mode-ra-username"].exists)
        app.navigationBars["Configurações"].buttons["Fechar"].tap()
        XCTAssertFalse(app.buttons["main-tab-0"].exists)

        let gamingAttachment = XCTAttachment(screenshot: app.screenshot())
        gamingAttachment.name = "Gaming Mode"
        gamingAttachment.lifetime = .keepAlways
        add(gamingAttachment)

        app.buttons["gaming-mode-exit"].tap()
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 5))
        app.buttons["main-tab-3"].tap()
        XCTAssertTrue(app.staticTexts["Conquistas"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Estatísticas"].exists)
        XCTAssertFalse(app.staticTexts["DISTRIBUIÇÃO POR PLATAFORMA"].exists)
        app.buttons["main-tab-4"].tap()
        XCTAssertTrue(app.staticTexts["Sua segunda tela."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["DESLIGAR"].exists)
        XCTAssertFalse(app.buttons["SUSPENDER"].exists)
        XCTAssertFalse(app.staticTexts["PESQUISA NO LIVING ROOM"].exists)
        XCTAssertTrue(app.staticTexts["FPS"].exists)
        for _ in 0..<4 {
            if app.buttons["companion-capture"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["companion-capture"].exists)
        XCTAssertFalse(app.buttons["companion-capture"].isEnabled)
        for _ in 0..<4 {
            if app.buttons["companion-moments-link"].exists && app.buttons["companion-moments-link"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["companion-moments-link"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["companion-moments-link"].isHittable)
    }
}
