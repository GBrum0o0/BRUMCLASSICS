import Foundation
import CryptoKit

struct PokedexSpriteAsset: Codable, Equatable {
    let activeKey: String?
    let normalKey: String?
    let shinyKey: String?
    let silhouetteKey: String?
}

struct PokedexSpeciesDefinition: Codable, Equatable, Identifiable {
    var id: Int { nationalDexNumber }
    let nationalDexNumber: Int
    let generation: Int
    let slug: String
    let name: String
    let genus: String
    let description: String
    let spriteAsset: PokedexSpriteAsset

    var formattedNumber: String {
        String(format: "%03d", nationalDexNumber)
    }
}

struct PokedexCaptureRecord: Codable, Equatable, Identifiable {
    var id: String { "\(nationalDexNumber):\(category)" }
    let captureId: String
    let ownerProfileId: String
    let nationalDexNumber: Int
    let formattedNumber: String
    let generation: Int
    let speciesName: String
    let speciesDescription: String
    let genus: String
    let spriteAsset: PokedexSpriteAsset
    let category: String // "normal" | "shiny"
    let isShiny: Bool
    let firstCapturedGame: String
    let firstCapturedGameId: String
    let systemId: String
    let capturedAt: String
    let captureLocation: String
    let sourceDeviceId: String
}

struct PokedexCaptureDetail: Codable, Equatable {
    let captureId: String
    let firstCapturedGame: String
    let firstCapturedGameId: String
    let systemId: String
    let capturedAt: String
    let captureLocation: String
    let ownerProfileId: String
}

struct PokedexProjectedEntry: Codable, Equatable, Identifiable {
    var id: String { "\(category):\(nationalDexNumber)" }
    let nationalDexNumber: Int
    let formattedNumber: String
    let generation: Int
    let discovered: Bool
    let silhouetteOnly: Bool
    let category: String
    let isShiny: Bool
    let name: String
    let genus: String
    let description: String
    let spriteAsset: PokedexSpriteAsset
    let capture: PokedexCaptureDetail?
}

struct PokedexViewSummary: Codable, Equatable {
    let normalDiscovered: Int
    let normalAvailableTotal: Int
    let shinyDiscovered: Int
    let totalCatalogSpecies: Int
}

struct PokedexViewTabs: Codable, Equatable {
    let pokemon: [PokedexProjectedEntry]
    let shinies: [PokedexProjectedEntry]
}

struct PokedexProjectedView: Codable, Equatable {
    let schemaVersion: Int
    let extensionId: String
    let catalogVersion: String
    let ownerProfileId: String
    let platform: String
    let syncRevision: Int
    let updatedAt: String
    let contentSha256: String
    let enabledGenerations: [Int]
    let summary: PokedexViewSummary
    let tabs: PokedexViewTabs
}

struct PokedexDiscoveryEvent: Codable, Equatable {
    let eventId: String
    let type: String
    let extensionId: String
    let ownerProfileId: String
    let nationalDexNumber: Int
    let formattedNumber: String
    let speciesName: String
    let category: String
    let isShiny: Bool
    let spriteAsset: PokedexSpriteAsset
    let gameTitle: String
    let gameId: String
    let systemId: String
    let capturedAt: String
    let captureLocation: String
    let title: String
    let headline: String
    let subtitle: String
}

struct PokedexSyncStateDocument: Codable, Equatable {
    let schemaVersion: Int
    let extensionId: String
    let catalogVersion: String
    let ownerProfileId: String
    var syncRevision: Int
    var updatedAt: String
    var contentSha256: String
    var records: [PokedexCaptureRecord]
}

struct PokedexBackupBundle: Codable, Equatable {
    let schemaVersion: Int
    let backupType: String
    let exportedAt: String
    let ownerProfileId: String
    let catalogVersion: String
    let syncRevision: Int
    let recordCount: Int
    let contentSha256: String
    let records: [PokedexCaptureRecord]
}

struct PokedexRecordResult: Equatable {
    let recorded: Bool
    let duplicate: Bool
    let record: PokedexCaptureRecord
    let notification: PokedexDiscoveryEvent?
    let syncRevision: Int
}

struct PokedexMergeResult: Codable, Equatable {
    let ok: Bool
    let ownerProfileId: String
    let addedCount: Int
    let replacedWithEarlierCount: Int
    let preservedCount: Int
    let totalRecords: Int
    let syncRevision: Int
    let contentSha256: String
}

enum PokedexUniversalError: LocalizedError, Equatable {
    case invalidSpecies(Int)
    case invalidBackup(String)
    case checksumMismatch
    case profileMismatch

    var errorDescription: String? {
        switch self {
        case .invalidSpecies(let dex): return "Espécie inválida na Pokédex Nacional: \(dex)"
        case .invalidBackup(let reason): return "Backup da Pokédex inválido: \(reason)"
        case .checksumMismatch: return "A verificação de integridade SHA-256 do backup da Pokédex falhou."
        case .profileMismatch: return "O perfil da coleção recebida não corresponde ao perfil ativo."
        }
    }
}

final class PokedexUniversalStore {
    static let unknownLocation = "Localização desconhecida"
    static let unknownText = "???"
    static let catalogVersion = "1.0.0"

    private let registry: BrumExtensionRegistry
    private let speciesByDex: [Int: PokedexSpeciesDefinition]
    private let enabledGenerations: [Int]
    private let deviceID: String
    var onDiscovery: ((PokedexDiscoveryEvent) -> Void)?

    init(
        registry: BrumExtensionRegistry = BrumExtensionRegistry(),
        speciesCatalog: [PokedexSpeciesDefinition]? = nil,
        enabledGenerations: [Int] = [1],
        deviceID: String = "ios-mobile"
    ) {
        self.registry = registry
        _ = try? registry.register(.pokedexUniversal)
        let list = speciesCatalog ?? Self.defaultKantoAndPilotCatalog()
        self.speciesByDex = Dictionary(uniqueKeysWithValues: list.map { ($0.nationalDexNumber, $0) })
        self.enabledGenerations = enabledGenerations.isEmpty ? [1] : enabledGenerations.sorted()
        self.deviceID = deviceID
    }

    static func sanitizeLocation(_ raw: String?) -> String {
        let cleaned = (raw ?? "")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.lowercased() == "unknown" || cleaned == unknownText {
            return unknownLocation
        }
        return String(cleaned.prefix(120))
    }

    static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func canonicalRecordsHash(_ records: [PokedexCaptureRecord]) -> String {
        let sorted = records.sorted {
            if $0.nationalDexNumber != $1.nationalDexNumber {
                return $0.nationalDexNumber < $1.nationalDexNumber
            }
            return $0.category < $1.category
        }
        let parts = sorted.map { r in
            "\(r.nationalDexNumber)|\(r.category)|\(r.speciesName)|\(r.firstCapturedGame)|\(r.firstCapturedGameId)|\(r.systemId)|\(r.capturedAt)|\(r.captureLocation)|\(r.ownerProfileId)|\(r.captureId)"
        }
        return sha256Hex(parts.joined(separator: "\n"))
    }

    private func collectionFileURL(profileID: String) throws -> URL {
        let dir = try registry.isolatedStorageURL(for: BrumExtensionManifest.pokedexUniversal.id, profileID: profileID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("collection-v1.json")
    }

    func loadSyncState(profileID: String = "primary") throws -> PokedexSyncStateDocument {
        let file = try collectionFileURL(profileID: profileID)
        guard FileManager.default.fileExists(atPath: file.path) else {
            return PokedexSyncStateDocument(
                schemaVersion: 1,
                extensionId: BrumExtensionManifest.pokedexUniversal.id,
                catalogVersion: Self.catalogVersion,
                ownerProfileId: profileID,
                syncRevision: 1,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                contentSha256: Self.canonicalRecordsHash([]),
                records: []
            )
        }
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode(PokedexSyncStateDocument.self, from: data)
    }

    private func saveSyncState(_ doc: PokedexSyncStateDocument) throws {
        let file = try collectionFileURL(profileID: doc.ownerProfileId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(doc)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func recordCapture(
        ownerProfileId: String = "primary",
        nationalDexNumber: Int,
        isShiny: Bool,
        gameTitle: String,
        gameId: String = "",
        systemId: String = "gba",
        capturedAt: String? = nil,
        captureLocation: String? = nil
    ) throws -> PokedexRecordResult {
        guard let species = speciesByDex[nationalDexNumber] else {
            throw PokedexUniversalError.invalidSpecies(nationalDexNumber)
        }
        var doc = try loadSyncState(profileID: ownerProfileId)
        let category = isShiny ? "shiny" : "normal"

        if let existing = doc.records.first(where: { $0.nationalDexNumber == nationalDexNumber && $0.category == category }) {
            return PokedexRecordResult(
                recorded: false,
                duplicate: true,
                record: existing,
                notification: nil,
                syncRevision: doc.syncRevision
            )
        }

        let timestamp = (capturedAt?.isEmpty == false) ? capturedAt! : ISO8601DateFormatter().string(from: Date())
        let location = Self.sanitizeLocation(captureLocation)
        let game = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pokémon FireRed Version" : gameTitle
        let capId = String(Self.sha256Hex("\(ownerProfileId)|\(nationalDexNumber)|\(category)|\(game)|\(timestamp)|\(location)").prefix(32))

        let record = PokedexCaptureRecord(
            captureId: capId,
            ownerProfileId: ownerProfileId,
            nationalDexNumber: species.nationalDexNumber,
            formattedNumber: species.formattedNumber,
            generation: species.generation,
            speciesName: species.name,
            speciesDescription: species.description,
            genus: species.genus,
            spriteAsset: PokedexSpriteAsset(
                activeKey: isShiny ? species.spriteAsset.shinyKey : species.spriteAsset.normalKey,
                normalKey: species.spriteAsset.normalKey,
                shinyKey: species.spriteAsset.shinyKey,
                silhouetteKey: species.spriteAsset.silhouetteKey
            ),
            category: category,
            isShiny: isShiny,
            firstCapturedGame: game,
            firstCapturedGameId: gameId,
            systemId: systemId.lowercased(),
            capturedAt: timestamp,
            captureLocation: location,
            sourceDeviceId: deviceID
        )

        doc.records.append(record)
        doc.records.sort {
            if $0.nationalDexNumber != $1.nationalDexNumber { return $0.nationalDexNumber < $1.nationalDexNumber }
            return $0.category < $1.category
        }
        doc.syncRevision += 1
        doc.updatedAt = ISO8601DateFormatter().string(from: Date())
        doc.contentSha256 = Self.canonicalRecordsHash(doc.records)
        try saveSyncState(doc)

        let event = PokedexDiscoveryEvent(
            eventId: "pokedex-discovery:\(ownerProfileId):\(nationalDexNumber):\(category)",
            type: "pokedex_discovery",
            extensionId: BrumExtensionManifest.pokedexUniversal.id,
            ownerProfileId: ownerProfileId,
            nationalDexNumber: species.nationalDexNumber,
            formattedNumber: species.formattedNumber,
            speciesName: species.name,
            category: category,
            isShiny: isShiny,
            spriteAsset: record.spriteAsset,
            gameTitle: game,
            gameId: gameId,
            systemId: systemId.lowercased(),
            capturedAt: timestamp,
            captureLocation: location,
            title: isShiny ? "Novo Pokémon Shiny descoberto!" : "Novo Pokémon descoberto!",
            headline: "\(species.formattedNumber) — \(species.name)",
            subtitle: "Registrado na Pokédex Universal"
        )
        onDiscovery?(event)

        return PokedexRecordResult(
            recorded: true,
            duplicate: false,
            record: record,
            notification: event,
            syncRevision: doc.syncRevision
        )
    }

    func projectedView(profileID: String = "primary", platform: String = "ios") throws -> PokedexProjectedView {
        let doc = try loadSyncState(profileID: profileID)
        let enabledSet = Set(enabledGenerations)
        let discoveredDexSet = Set(doc.records.map(\.nationalDexNumber))

        let visibleSpecies = speciesByDex.values
            .filter { enabledSet.contains($0.generation) || discoveredDexSet.contains($0.nationalDexNumber) }
            .sorted { $0.nationalDexNumber < $1.nationalDexNumber }

        var byKey: [String: PokedexCaptureRecord] = [:]
        for r in doc.records {
            byKey["\(r.nationalDexNumber):\(r.category)"] = r
        }

        var pokemonTab: [PokedexProjectedEntry] = []
        var shiniesTab: [PokedexProjectedEntry] = []
        var normalDiscovered = 0
        var shinyDiscovered = 0

        for sp in visibleSpecies {
            if let normalRec = byKey["\(sp.nationalDexNumber):normal"] {
                normalDiscovered += 1
                pokemonTab.append(PokedexProjectedEntry(
                    nationalDexNumber: sp.nationalDexNumber,
                    formattedNumber: sp.formattedNumber,
                    generation: sp.generation,
                    discovered: true,
                    silhouetteOnly: false,
                    category: "normal",
                    isShiny: false,
                    name: sp.name,
                    genus: sp.genus,
                    description: sp.description,
                    spriteAsset: PokedexSpriteAsset(
                        activeKey: sp.spriteAsset.normalKey,
                        normalKey: sp.spriteAsset.normalKey,
                        shinyKey: nil,
                        silhouetteKey: sp.spriteAsset.silhouetteKey
                    ),
                    capture: PokedexCaptureDetail(
                        captureId: normalRec.captureId,
                        firstCapturedGame: normalRec.firstCapturedGame,
                        firstCapturedGameId: normalRec.firstCapturedGameId,
                        systemId: normalRec.systemId,
                        capturedAt: normalRec.capturedAt,
                        captureLocation: normalRec.captureLocation,
                        ownerProfileId: normalRec.ownerProfileId
                    )
                ))
            } else {
                pokemonTab.append(PokedexProjectedEntry(
                    nationalDexNumber: sp.nationalDexNumber,
                    formattedNumber: sp.formattedNumber,
                    generation: sp.generation,
                    discovered: false,
                    silhouetteOnly: true,
                    category: "normal",
                    isShiny: false,
                    name: Self.unknownText,
                    genus: Self.unknownText,
                    description: Self.unknownText,
                    spriteAsset: PokedexSpriteAsset(
                        activeKey: sp.spriteAsset.silhouetteKey,
                        normalKey: nil,
                        shinyKey: nil,
                        silhouetteKey: sp.spriteAsset.silhouetteKey
                    ),
                    capture: nil
                ))
            }

            if let shinyRec = byKey["\(sp.nationalDexNumber):shiny"] {
                shinyDiscovered += 1
                shiniesTab.append(PokedexProjectedEntry(
                    nationalDexNumber: sp.nationalDexNumber,
                    formattedNumber: sp.formattedNumber,
                    generation: sp.generation,
                    discovered: true,
                    silhouetteOnly: false,
                    category: "shiny",
                    isShiny: true,
                    name: sp.name,
                    genus: sp.genus,
                    description: sp.description,
                    spriteAsset: PokedexSpriteAsset(
                        activeKey: sp.spriteAsset.shinyKey,
                        normalKey: nil,
                        shinyKey: sp.spriteAsset.shinyKey,
                        silhouetteKey: sp.spriteAsset.silhouetteKey
                    ),
                    capture: PokedexCaptureDetail(
                        captureId: shinyRec.captureId,
                        firstCapturedGame: shinyRec.firstCapturedGame,
                        firstCapturedGameId: shinyRec.firstCapturedGameId,
                        systemId: shinyRec.systemId,
                        capturedAt: shinyRec.capturedAt,
                        captureLocation: shinyRec.captureLocation,
                        ownerProfileId: shinyRec.ownerProfileId
                    )
                ))
            }
        }

        return PokedexProjectedView(
            schemaVersion: 1,
            extensionId: BrumExtensionManifest.pokedexUniversal.id,
            catalogVersion: Self.catalogVersion,
            ownerProfileId: profileID,
            platform: platform.lowercased(),
            syncRevision: doc.syncRevision,
            updatedAt: doc.updatedAt,
            contentSha256: doc.contentSha256,
            enabledGenerations: enabledGenerations,
            summary: PokedexViewSummary(
                normalDiscovered: normalDiscovered,
                normalAvailableTotal: pokemonTab.count,
                shinyDiscovered: shinyDiscovered,
                totalCatalogSpecies: max(802, speciesByDex.count)
            ),
            tabs: PokedexViewTabs(pokemon: pokemonTab, shinies: shiniesTab)
        )
    }

    private static func isEarlier(_ candidate: PokedexCaptureRecord, than existing: PokedexCaptureRecord) -> Bool {
        if candidate.capturedAt != existing.capturedAt {
            return candidate.capturedAt < existing.capturedAt
        }
        return candidate.captureId < existing.captureId
    }

    func mergeCollection(profileID: String = "primary", incomingRecords: [PokedexCaptureRecord], incomingOwnerProfileId: String? = nil) throws -> PokedexMergeResult {
        if let incomingOwnerProfileId, !incomingOwnerProfileId.isEmpty, incomingOwnerProfileId != profileID {
            throw PokedexUniversalError.profileMismatch
        }
        var doc = try loadSyncState(profileID: profileID)
        var byKey: [String: PokedexCaptureRecord] = [:]
        for r in doc.records {
            byKey["\(r.nationalDexNumber):\(r.category)"] = r
        }

        var addedCount = 0
        var replacedCount = 0
        var preservedCount = 0

        for raw in incomingRecords {
            guard speciesByDex[raw.nationalDexNumber] != nil else {
                throw PokedexUniversalError.invalidSpecies(raw.nationalDexNumber)
            }
            let key = "\(raw.nationalDexNumber):\(raw.category)"
            if let existing = byKey[key] {
                if Self.isEarlier(raw, than: existing) {
                    byKey[key] = raw
                    replacedCount += 1
                } else {
                    preservedCount += 1
                }
            } else {
                byKey[key] = raw
                addedCount += 1
            }
        }

        if addedCount > 0 || replacedCount > 0 {
            doc.records = byKey.values.sorted {
                if $0.nationalDexNumber != $1.nationalDexNumber { return $0.nationalDexNumber < $1.nationalDexNumber }
                return $0.category < $1.category
            }
            doc.syncRevision += 1
            doc.updatedAt = ISO8601DateFormatter().string(from: Date())
            doc.contentSha256 = Self.canonicalRecordsHash(doc.records)
            try saveSyncState(doc)
        }

        return PokedexMergeResult(
            ok: true,
            ownerProfileId: profileID,
            addedCount: addedCount,
            replacedWithEarlierCount: replacedCount,
            preservedCount: preservedCount,
            totalRecords: doc.records.count,
            syncRevision: doc.syncRevision,
            contentSha256: doc.contentSha256
        )
    }

    func exportBackup(profileID: String = "primary") throws -> PokedexBackupBundle {
        let doc = try loadSyncState(profileID: profileID)
        return PokedexBackupBundle(
            schemaVersion: 1,
            backupType: "brum.ext.pokedex.backup",
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            ownerProfileId: profileID,
            catalogVersion: doc.catalogVersion,
            syncRevision: doc.syncRevision,
            recordCount: doc.records.count,
            contentSha256: doc.contentSha256,
            records: doc.records
        )
    }

    func verifyBackup(_ bundle: PokedexBackupBundle) throws {
        guard bundle.schemaVersion == 1, bundle.backupType == "brum.ext.pokedex.backup" else {
            throw PokedexUniversalError.invalidBackup("cabeçalho ou versão incompatível.")
        }
        let computed = Self.canonicalRecordsHash(bundle.records)
        guard computed == bundle.contentSha256, bundle.recordCount == bundle.records.count else {
            throw PokedexUniversalError.checksumMismatch
        }
    }

    func restoreBackup(profileID: String = "primary", bundle: PokedexBackupBundle) throws -> PokedexMergeResult {
        try verifyBackup(bundle)
        return try mergeCollection(profileID: profileID, incomingRecords: bundle.records, incomingOwnerProfileId: profileID)
    }

    static func defaultKantoAndPilotCatalog() -> [PokedexSpeciesDefinition] {
        // Loads full 802 catalog if bundled in docs/Resources, otherwise provides representative species 1..802 for unit tests
        if let url = Bundle.main.url(forResource: "pokedex-species-catalog-v1", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = root["species"] as? [[String: Any]],
           let listData = try? JSONSerialization.data(withJSONObject: list),
           let decoded = try? JSONDecoder().decode([PokedexSpeciesDefinition].self, from: listData),
           decoded.count >= 802 {
            return decoded
        }

        let knownNames: [Int: (String, String, String)] = [
            1: ("Bulbasaur", "Seed Pokémon", "There is a plant seed on its back right from the day this Pokémon is born."),
            4: ("Charmander", "Lizard Pokémon", "From the time it is born, a flame burns at the tip of its tail."),
            7: ("Squirtle", "Tiny Turtle Pokémon", "When it retracts its long neck into its shell, it squirts out water with vigorous force."),
            25: ("Pikachu", "Mouse Pokémon", "It has small electric sacs on both its cheeks. If threatened, it looses electric charges from the sacs."),
            133: ("Eevee", "Evolution Pokémon", "An extremely rare Pokémon that may evolve in a number of different ways depending on stimuli."),
            150: ("Mewtwo", "Genetic Pokémon", "A Pokémon whose genetic code was repeatedly recombined for research."),
            151: ("Mew", "New Species Pokémon", "A Pokémon of South America that was thought to have been extinct."),
            152: ("Chikorita", "Leaf Pokémon", "A pleasantly aromatic leaf sprouts from its head."),
            252: ("Treecko", "Wood Gecko Pokémon", "It makes its nest in a giant tree in the forest."),
            396: ("Starly", "Starling Pokémon", "They flock in great numbers. Though small, they flap their wings with great power."),
            494: ("Victini", "Victory Pokémon", "This Pokémon brings victory. It is said that Trainers with Victini always win."),
            650: ("Chespin", "Spiny Nut Pokémon", "The quills on its head are usually soft."),
            722: ("Rowlet", "Grass Quill Pokémon", "It sends its feathers, which are as sharp as blades, flying in attack."),
            802: ("Marshadow", "Gloomdweller Pokémon", "It slips into the shadows of others and mimics their powers and movements.")
        ]

        return (1...802).map { dex in
            let gen: Int
            switch dex {
            case 1...151: gen = 1
            case 152...251: gen = 2
            case 252...386: gen = 3
            case 387...493: gen = 4
            case 494...649: gen = 5
            case 650...721: gen = 6
            default: gen = 7
            }
            let code = String(format: "%03d", dex)
            let meta = knownNames[dex] ?? ("Pokémon #\(code)", "Pokémon", "Official National Pokédex entry #\(code).")
            return PokedexSpeciesDefinition(
                nationalDexNumber: dex,
                generation: gen,
                slug: meta.0.lowercased(),
                name: meta.0,
                genus: meta.1,
                description: meta.2,
                spriteAsset: PokedexSpriteAsset(
                    activeKey: "pokedex/normal/\(code)",
                    normalKey: "pokedex/normal/\(code)",
                    shinyKey: "pokedex/shiny/\(code)",
                    silhouetteKey: "pokedex/silhouette/\(code)"
                )
            )
        }
    }
}
