import XCTest
@testable import BRUMCLASSICSMobile

final class PokedexUniversalTests: XCTestCase {
    func testBackupRejectsForeignProfileAndAtomicInvalidBatch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PokedexUniversalStore(registry: BrumExtensionRegistry(storageRoot: root))
        let capture = try store.recordCapture(ownerProfileId: "other", nationalDexNumber: 25, isShiny: false,
            gameTitle: "FireRed", gameId: "fr", systemId: "gba", capturedAt: "2026-11-22T10:00:00Z")
        let backup = try store.exportBackup(profileID: "other")
        XCTAssertThrowsError(try store.restoreBackup(profileID: "primary", bundle: backup))
        XCTAssertEqual(try store.loadSyncState(profileID: "primary").records.count, 0)
        var validJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(capture.record)) as? [String: Any])
        validJSON["ownerProfileId"] = "primary"
        let valid = try JSONDecoder().decode(PokedexCaptureRecord.self, from: JSONSerialization.data(withJSONObject: validJSON))
        XCTAssertThrowsError(try store.mergeCollection(profileID: "primary", incomingRecords: [valid, capture.record]))
        XCTAssertEqual(try store.loadSyncState(profileID: "primary").records.count, 0)
    }

    func testRawTimestampBackupRoundTripsAndDelimiterRejected() throws {
        let whole = try XCTUnwrap(PokedexUniversalStore.parseIsoEpochMillis("2026-11-22T10:00:00Z"))
        XCTAssertEqual(PokedexUniversalStore.parseIsoEpochMillis("2026-11-22T10:00:00.123456789Z"), whole + 123)
        XCTAssertEqual(PokedexUniversalStore.parseIsoEpochMillis("2026-11-22T10:00:00.999999999Z"), whole + 999)
        XCTAssertEqual(PokedexUniversalStore.parseIsoEpochMillis("2026-11-22T07:00:00-03:00"), whole)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PokedexUniversalStore(registry: BrumExtensionRegistry(storageRoot: root))
        for (index, timestamp) in ["2026-11-22T10:00:00Z", "2026-11-22T10:00:00.000Z",
                                   "2026-11-22T07:00:00-03:00", "2026-11-22T10:00:00.123456789Z"].enumerated() {
            let profile = "timestamp_\(index)"
            let result = try store.recordCapture(ownerProfileId: profile, nationalDexNumber: 25, isShiny: false,
                gameTitle: "FireRed", capturedAt: timestamp)
            XCTAssertEqual(result.record.capturedAt, timestamp)
            let backup = try store.exportBackup(profileID: profile)
            XCTAssertNoThrow(try store.restoreBackup(profileID: profile, bundle: backup))
            XCTAssertEqual(try store.loadSyncState(profileID: profile).contentSha256, backup.contentSha256)
        }
        XCTAssertThrowsError(try store.recordCapture(nationalDexNumber: 25, isShiny: false, gameTitle: "a|b"))
        let existing = try store.recordCapture(nationalDexNumber: 25, isShiny: false, gameTitle: "FireRed", capturedAt: "2026-11-22T10:00:00.000Z")
        var incomingJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(existing.record)) as? [String: Any])
        incomingJSON["captureId"] = "000-earlier-id"
        incomingJSON["capturedAt"] = "2026-11-22T10:00:00Z"
        let incoming = try JSONDecoder().decode(PokedexCaptureRecord.self, from: JSONSerialization.data(withJSONObject: incomingJSON))
        let merged = try store.mergeCollection(incomingRecords: [incoming])
        XCTAssertEqual(merged.replacedWithEarlierCount, 1)
        XCTAssertEqual(try store.loadSyncState().records.first?.captureId, "000-earlier-id")
    }

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

        // 6. Verify full 809-species offline catalog (Gen 1..7 #001..#809) and fractional timestamp ordering
        let allView = try cleanStore.projectedView(profileID: "gusta", platform: "ios", scope: "all")
        XCTAssertEqual(allView.tabs.pokemon.count, 809)
        XCTAssertEqual(allView.tabs.pokemon.last?.formattedNumber, "809")
        XCTAssertEqual(allView.summary.totalCatalogSpecies, 809)
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

    @MainActor
    func testPokedexFrontendCoordinatorSpriteAndDiscoveryPopupContract() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PokedexFrontendTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let registry = BrumExtensionRegistry(storageRoot: tempRoot)
        _ = try registry.register(.pokedexUniversal)
        let store = PokedexUniversalStore(registry: registry, deviceID: "iphone-ui-test")
        let coordinator = PokedexUniversalCoordinator(store: store, profileID: "gusta")

        // 1. Initial state must be closed Pokédex device
        XCTAssertFalse(coordinator.isDeviceOpen)
        XCTAssertEqual(coordinator.selectedTab, .pokemon)
        XCTAssertEqual(coordinator.displayedEntries.count, 151)

        // 2. Undiscovered species (#001 Bulbasaur) must NOT match search by hidden name "bulbasaur"
        coordinator.searchQuery = "bulbasaur"
        XCTAssertEqual(coordinator.displayedEntries.count, 0)

        // Searching by visible National Dex number (#001) MUST match
        coordinator.searchQuery = "001"
        XCTAssertEqual(coordinator.displayedEntries.count, 1)
        XCTAssertEqual(coordinator.displayedEntries.first?.name, "???")
        coordinator.searchQuery = ""

        // 3. Record capture of Pikachu (#25) and verify discovery popup payload
        coordinator.handleDetectedCapture(
            nationalDexNumber: 25,
            isShiny: false,
            gameTitle: "Pokémon FireRed Version",
            gameID: "firered-1",
            systemID: "gba",
            captureLocation: "Viridian Forest"
        )
        XCTAssertEqual(coordinator.projectedView.summary.normalDiscovered, 1)
        XCTAssertEqual(coordinator.selectedDexNumber, 25)

        // Discovered species (#025 Pikachu) CAN now be found by name
        coordinator.searchQuery = "pikachu"
        XCTAssertEqual(coordinator.displayedEntries.count, 1)
        XCTAssertEqual(coordinator.displayedEntries.first?.name, "Pikachu")
        coordinator.searchQuery = ""

        // 4. Normal and hidden species use exactly the same sprite alpha source.
        XCTAssertEqual(PokedexPixelSprite.url(for: 25, mode: .normal), PokedexPixelSprite.url(for: 25, mode: .silhouette))
        XCTAssertEqual(PokedexPixelSprite.url(for: 25, mode: .normal).lastPathComponent, "25.png")
        XCTAssertTrue(PokedexPixelSprite.url(for: 25, mode: .shiny).path.contains("/shiny/25.png"))

        // 5. Verify Bridge Event -> Discovery Overlay Payload
        let bridgeEvent: [String: Any] = [
            "type": "pokedex_discovery",
            "eventId": "pokedex-discovery:gusta:25:shiny",
            "discovery": [
                "nationalDexNumber": 25,
                "formattedNumber": "025",
                "speciesName": "Pikachu",
                "category": "shiny",
                "isShiny": true,
                "headline": "025 — Pikachu",
                "gameTitle": "Pokémon FireRed Version",
                "subtitle": "Registrado na Pokédex Universal"
            ]
        ]
        let overlayPayload = try XCTUnwrap(BrumAchievementOverlayPayload.fromPokedexBridgeEvent(bridgeEvent))
        XCTAssertEqual(overlayPayload.eyebrow, "✦ NOVO POKÉMON SHINY DESCOBERTO!")
        XCTAssertEqual(overlayPayload.title, "025 — Pikachu")
        XCTAssertEqual(overlayPayload.pillText, "✦ SHINY")
        XCTAssertEqual(overlayPayload.pokedexNationalDexNumber, 25)
        XCTAssertTrue(overlayPayload.isShinyDiscovery)
    }
}
