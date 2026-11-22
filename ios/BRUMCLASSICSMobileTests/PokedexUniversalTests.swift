import XCTest
@testable import BRUMCLASSICSMobile

final class PokedexUniversalTests: XCTestCase {
    func testExtensionManifestRejectsArbitraryDynamicCodeOnIOS() {
        XCTAssertNoThrow(try BrumExtensionManifest.pokedexUniversal.validate())

        let badManifest = BrumExtensionManifest(
            id: "brum.ext.pokedex",
            number: "001",
            schemaVersion: 1,
            version: "1.0.0",
            title: "Pokédex",
            shortTitle: "Pokédex",
            description: "Teste",
            category: "gamepad-extension",
            codeExecutionPolicy: "remote-downloaded-js",
            defaultEnabled: true,
            permissions: ["brum-core:events.read"],
            capabilities: [],
            platforms: ["ios"],
            uiContract: BrumExtensionManifest.pokedexUniversal.uiContract
        )
        XCTAssertThrowsError(try badManifest.validate()) { error in
            XCTAssertEqual(error as? BrumExtensionError, .dynamicCodeExecutionForbidden)
        }
    }

    func testPokedexFirstCapturePermanenceNormalAndShinyIndependenceAndRedaction() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PokedexUniversalTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let registry = BrumExtensionRegistry(storageRoot: tempRoot)
        var notifications: [PokedexDiscoveryEvent] = []
        let store = PokedexUniversalStore(registry: registry, deviceID: "iphone-test")
        store.onDiscovery = { notifications.append($0) }

        // 1. Capture normal Pikachu (#25) in FireRed
        let first = try store.recordCapture(
            ownerProfileId: "gusta",
            nationalDexNumber: 25,
            isShiny: false,
            gameTitle: "Pokémon FireRed Version",
            gameId: "firered-1",
            systemId: "gba",
            capturedAt: "2026-11-22T10:00:00Z",
            captureLocation: "Viridian Forest"
        )
        XCTAssertTrue(first.recorded)
        XCTAssertFalse(first.duplicate)
        XCTAssertEqual(first.record.speciesName, "Pikachu")
        XCTAssertEqual(first.record.category, "normal")
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications[0].headline, "025 — Pikachu")

        // 2. Capture another normal Pikachu in Platinum -> must NOT overwrite or emit second notification
        let duplicate = try store.recordCapture(
            ownerProfileId: "gusta",
            nationalDexNumber: 25,
            isShiny: false,
            gameTitle: "Pokémon Platinum Version",
            gameId: "plat-1",
            systemId: "nds",
            capturedAt: "2026-11-22T11:00:00Z",
            captureLocation: "Trophy Garden"
        )
        XCTAssertFalse(duplicate.recorded)
        XCTAssertTrue(duplicate.duplicate)
        XCTAssertEqual(duplicate.record.firstCapturedGame, "Pokémon FireRed Version")
        XCTAssertEqual(duplicate.record.captureLocation, "Viridian Forest")
        XCTAssertEqual(notifications.count, 1)

        // 3. Capture SHINY Pikachu -> independent record in Shinies tab, must NOT overwrite normal Pikachu
        let shiny = try store.recordCapture(
            ownerProfileId: "gusta",
            nationalDexNumber: 25,
            isShiny: true,
            gameTitle: "Pokémon FireRed Version",
            gameId: "firered-1",
            systemId: "gba",
            capturedAt: "2026-11-22T12:00:00Z",
            captureLocation: ""
        )
        XCTAssertTrue(shiny.recorded)
        XCTAssertEqual(shiny.record.category, "shiny")
        XCTAssertEqual(shiny.record.captureLocation, PokedexUniversalStore.unknownLocation)
        XCTAssertEqual(notifications.count, 2)
        XCTAssertTrue(notifications[1].isShiny)

        // 4. Check view projection & redaction of undiscovered species (#1 Bulbasaur)
        let view = try store.projectedView(profileID: "gusta", platform: "ios")
        XCTAssertEqual(view.summary.normalDiscovered, 1)
        XCTAssertEqual(view.summary.normalAvailableTotal, 151)
        XCTAssertEqual(view.summary.shinyDiscovered, 1)

        let bulbasaur = try XCTUnwrap(view.tabs.pokemon.first(where: { $0.nationalDexNumber == 1 }))
        XCTAssertEqual(bulbasaur.formattedNumber, "001")
        XCTAssertFalse(bulbasaur.discovered)
        XCTAssertTrue(bulbasaur.silhouetteOnly)
        XCTAssertEqual(bulbasaur.name, "???")
        XCTAssertEqual(bulbasaur.description, "???")
        XCTAssertNil(bulbasaur.capture)
        XCTAssertNil(bulbasaur.spriteAsset.normalKey)
        XCTAssertEqual(bulbasaur.spriteAsset.activeKey, "pokedex/silhouette/001")

        let pikachuNormal = try XCTUnwrap(view.tabs.pokemon.first(where: { $0.nationalDexNumber == 25 }))
        XCTAssertTrue(pikachuNormal.discovered)
        XCTAssertEqual(pikachuNormal.name, "Pikachu")
        XCTAssertEqual(pikachuNormal.capture?.firstCapturedGame, "Pokémon FireRed Version")

        XCTAssertEqual(view.tabs.shinies.count, 1)
        XCTAssertEqual(view.tabs.shinies[0].nationalDexNumber, 25)
        XCTAssertTrue(view.tabs.shinies[0].isShiny)

        // 5. Backup & restore verification with SHA-256
        let backup = try store.exportBackup(profileID: "gusta")
        XCTAssertEqual(backup.recordCount, 2)

        let cleanRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PokedexRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cleanRoot) }

        let cleanStore = PokedexUniversalStore(registry: BrumExtensionRegistry(storageRoot: cleanRoot))
        let restored = try cleanStore.restoreBackup(profileID: "gusta", bundle: backup)
        XCTAssertEqual(restored.totalRecords, 2)
        XCTAssertEqual(restored.contentSha256, backup.contentSha256)

        // 6. Verify full 802-species offline catalog (including #016 Pidgey) and fractional timestamp ordering
        let pidgey = try cleanStore.recordCapture(
            ownerProfileId: "gusta",
            nationalDexNumber: 16,
            isShiny: false,
            gameTitle: "Pokémon FireRed Version",
            gameId: "firered-1",
            systemId: "gba",
            capturedAt: "2026-11-22T10:00:00Z",
            captureLocation: "Route 1"
        )
        XCTAssertTrue(pidgey.recorded)
        XCTAssertEqual(pidgey.record.speciesName, "Pidgey")

        // A later timestamp with fractional seconds (.999Z) must NOT overwrite an earlier timestamp without fractional seconds (Z)
        var laterPidgey = pidgey.record
        laterPidgey = PokedexCaptureRecord(
            captureId: "later-pidgey-id",
            ownerProfileId: "gusta",
            nationalDexNumber: 16,
            formattedNumber: "016",
            generation: 1,
            speciesName: "Pidgey",
            speciesDescription: pidgey.record.speciesDescription,
            genus: pidgey.record.genus,
            spriteAsset: pidgey.record.spriteAsset,
            category: "normal",
            isShiny: false,
            firstCapturedGame: "Pokémon Platinum Version",
            firstCapturedGameId: "plat-1",
            systemId: "nds",
            capturedAt: "2026-11-22T10:00:00.999Z",
            captureLocation: "Route 229",
            sourceDeviceId: "pc-windows"
        )
        let mergeOutcome = try cleanStore.mergeCollection(profileID: "gusta", incomingRecords: [laterPidgey], incomingOwnerProfileId: "gusta")
        XCTAssertEqual(mergeOutcome.replacedWithEarlierCount, 0)
        XCTAssertEqual(mergeOutcome.preservedCount, 1)
    }
}
