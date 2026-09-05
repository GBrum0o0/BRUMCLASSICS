import Foundation

struct PocketTimeReceipt: Decodable { let ok: Bool; let acceptedSeconds: Int }

struct PocketPlaySession: Codable, Equatable {
    let gameID: UUID
    let filename: String
    let launchedAt: Date
    var backgroundedAt: Date?
}

enum PocketSessionRules {
    static let maximumDuration = 24 * 60 * 60

    static func elapsed(_ session: PocketPlaySession, returnedAt: Date) -> Int? {
        guard let backgroundedAt = session.backgroundedAt else { return nil }
        let seconds = Int(returnedAt.timeIntervalSince(backgroundedAt).rounded(.down))
        guard seconds > 0, seconds <= maximumDuration else { return nil }
        return seconds
    }
}

actor PocketPlaySessionFiles {
    private let file: URL

    init(root: URL? = nil) {
        let directory = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassicsEverywhere", isDirectory: true)
        file = directory.appendingPathComponent("active-play-session.json")
    }

    func begin(_ game: PocketClassic, now: Date = Date()) throws {
        let session = PocketPlaySession(gameID: game.id, filename: game.filename, launchedAt: now, backgroundedAt: nil)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func markBackgrounded(now: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        var session = try JSONDecoder().decode(PocketPlaySession.self, from: Data(contentsOf: file))
        if session.backgroundedAt == nil {
            session.backgroundedAt = now
            try JSONEncoder().encode(session).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
    }

    func finish(returnedAt: Date = Date()) throws -> (session: PocketPlaySession, seconds: Int)? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let session = try JSONDecoder().decode(PocketPlaySession.self, from: Data(contentsOf: file))
        guard let seconds = PocketSessionRules.elapsed(session, returnedAt: returnedAt) else {
            if session.backgroundedAt != nil { try? FileManager.default.removeItem(at: file) }
            return nil
        }
        try FileManager.default.removeItem(at: file)
        return (session, seconds)
    }

    func cancel() { try? FileManager.default.removeItem(at: file) }
}

struct PocketRuntimeRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var streamID = UUID().uuidString
    var filename: String
    var lastObservedSeconds: Int
    var creditedSeconds = 0
    var acknowledgedSeconds = -1
    var launcherGameID = ""
    var serverFingerprint = ""
    var counterReset = false

    mutating func observe(_ seconds: Int) throws {
        guard !counterReset, seconds >= lastObservedSeconds else {
            counterReset = true
            throw PocketError.message("O contador do RetroArch diminuiu. Reestabeleça o ponto de partida; as horas anteriores foram preservadas.")
        }
        creditedSeconds += seconds - lastObservedSeconds
        lastObservedSeconds = seconds
    }
}

enum PocketRuntimeRules {
    static func seconds(_ data: Data) throws -> Int {
        guard data.count <= 65_536,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtime = object["runtime"] as? String else { throw PocketError.message("Log de tempo inválido; nenhum tempo foi acrescentado.") }
        let parts = runtime.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }),
              let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]), h <= 87_660, m < 60, s < 60 else {
            throw PocketError.message("Formato de tempo do RetroArch não reconhecido.")
        }
        return h * 3600 + m * 60 + s
    }
    static func logName(_ filename: String) throws -> String {
        guard PocketRules.safeFilename(filename) else { throw PocketError.message("Nome de ROM inválido.") }
        return (filename as NSString).deletingPathExtension + ".lrtl"
    }
}

// Reads ONLY the selected aggregate log directory. No process timers, ROM scans,
// emulator-config changes, save access or arbitrary filesystem paths are needed.
actor PocketRuntimeFiles {
    private struct State: Codable {
        var version = 1
        var bookmark: Data?
        var records: [PocketRuntimeRecord] = []
    }
    private let root: URL
    private var state = State()
    private var loaded = false
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClassicsEverywhere", isDirectory: true)
    }
    func load() throws -> [PocketRuntimeRecord] {
        if !loaded {
            let file = root.appendingPathComponent("runtime-ledger.json")
            if FileManager.default.fileExists(atPath: file.path) {
                let decoded = try JSONDecoder().decode(State.self, from: Data(contentsOf: file))
                guard decoded.version == 1, Set(decoded.records.map(\.id)).count == decoded.records.count,
                      decoded.records.allSatisfy({ $0.lastObservedSeconds >= 0 && $0.creditedSeconds >= 0 && $0.acknowledgedSeconds >= -1 && $0.acknowledgedSeconds <= $0.creditedSeconds }) else { throw PocketError.message("Registro de horas inválido. Arquivo preservado para recuperação.") }
                state = decoded
            }
            loaded = true
        }
        return state.records
    }
    private func commit(_ next: State) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: root.appendingPathComponent("runtime-ledger.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        state = next
    }
    func configured() throws -> Bool { _ = try load(); return state.bookmark != nil }
    func configure(_ folder: URL) throws {
        _ = try load()
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw PocketError.message("Selecione a pasta de logs, não um arquivo.") }
        var next = state
        next.bookmark = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        // Selecting another directory cannot silently add that directory's history.
        for index in next.records.indices { next.records[index].counterReset = true }
        try commit(next)
    }
    private func observed(_ filename: String) throws -> Int? {
        guard let bookmark = state.bookmark else { throw PocketError.message("Autorize a pasta de logs do RetroArch em Configurações → CLASSICS para registrar horas.") }
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw PocketError.message("A autorização da pasta expirou. Selecione novamente a pasta de logs do RetroArch.") }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appendingPathComponent(try PocketRuntimeRules.logName(filename))
        var coordinationError: NSError?
        var result: Result<Int?, Error>?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &coordinationError) { coordinated in
            result = Result {
                let values = try coordinated.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 65_536 else { throw PocketError.message("Log inválido ou grande demais.") }
                return try PocketRuntimeRules.seconds(Data(contentsOf: coordinated))
            }
        }
        if let coordinationError {
            if coordinationError.domain == NSCocoaErrorDomain && coordinationError.code == NSFileReadNoSuchFileError { return nil }
            throw coordinationError
        }
        do { return try result?.get() }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return nil }
    }
    func prepare(_ game: PocketClassic, allGames: [PocketClassic]) throws {
        _ = try load()
        let log = try PocketRuntimeRules.logName(game.filename).lowercased()
        guard try allGames.filter({ try PocketRuntimeRules.logName($0.filename).lowercased() == log }).count == 1 else { throw PocketError.message("Duas ROMs usam o mesmo nome de log. Renomeie os arquivos no catálogo e no RetroArch para distinguir as horas.") }
        guard !state.records.contains(where: { $0.id == game.id }) else { return }
        let baseline = state.bookmark == nil ? 0 : try observed(game.filename) ?? 0
        var next = state
        next.records.append(PocketRuntimeRecord(id: game.id, filename: game.filename, lastObservedSeconds: baseline))
        try commit(next)
    }
    func creditEstimated(_ id: UUID, filename: String, seconds: Int) throws -> Bool {
        _ = try load()
        guard state.bookmark == nil, seconds > 0, seconds <= PocketSessionRules.maximumDuration else { return false }
        var next = state
        if let index = next.records.firstIndex(where: { $0.id == id }) {
            guard next.records[index].filename.caseInsensitiveCompare(filename) == .orderedSame else {
                throw PocketError.message("A sessão pertence a outro arquivo. O histórico anterior foi preservado.")
            }
            next.records[index].creditedSeconds += seconds
        } else {
            next.records.append(PocketRuntimeRecord(id: id, filename: filename, lastObservedSeconds: 0, creditedSeconds: seconds))
        }
        try commit(next)
        return true
    }
    func collect() throws -> [String] {
        _ = try load()
        // Without an authorized log folder, elapsed time is recorded by the
        // persistent play-session fallback instead of becoming a permanent error.
        guard state.bookmark != nil else { return [] }
        var next = state; var errors: [String] = []
        for index in next.records.indices {
            do {
                guard let seconds = try observed(next.records[index].filename) else { continue }
                try next.records[index].observe(seconds)
            } catch { errors.append("\(next.records[index].filename): \(error.localizedDescription)") }
        }
        if next.records != state.records { try commit(next) }
        return errors
    }
    func rebaseline(_ id: UUID) throws {
        _ = try load()
        guard let index = state.records.firstIndex(where: { $0.id == id }) else { return }
        guard let seconds = try observed(state.records[index].filename) else { throw PocketError.message("Jogue e feche o conteúdo no RetroArch para criar um log antes de reestabelecer a medição.") }
        var next = state
        next.records[index].lastObservedSeconds = seconds
        next.records[index].counterReset = false
        try commit(next)
    }
    func bind(_ id: UUID, gameID: String, fingerprint: String) throws -> PocketRuntimeRecord {
        _ = try load()
        guard !gameID.isEmpty, !fingerprint.isEmpty, let index = state.records.firstIndex(where: { $0.id == id }) else { throw PocketError.message("Vincule o mesmo jogo no launcher antes de enviar horas.") }
        var record = state.records[index]
        guard (record.launcherGameID.isEmpty || record.launcherGameID == gameID), (record.serverFingerprint.isEmpty || record.serverFingerprint == fingerprint) else { throw PocketError.message("Horas vinculadas a outro jogo ou PC. Restaure o vínculo original; não enviaremos o histórico para outra conta.") }
        record.launcherGameID = gameID; record.serverFingerprint = fingerprint
        var next = state; next.records[index] = record; try commit(next)
        return record
    }
    func acknowledge(_ id: UUID, sentSeconds: Int, receipt: PocketTimeReceipt) throws {
        _ = try load()
        guard receipt.ok, receipt.acceptedSeconds == sentSeconds else { throw PocketError.message("O PC possui um contador diferente. Histórico preservado; não serão somadas horas duplicadas.") }
        guard let index = state.records.firstIndex(where: { $0.id == id }) else { return }
        var next = state
        next.records[index].acknowledgedSeconds = max(next.records[index].acknowledgedSeconds, sentSeconds)
        try commit(next)
    }
}
