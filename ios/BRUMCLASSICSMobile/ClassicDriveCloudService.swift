import Foundation
import Security

public enum ClassicAvailabilityState: String, Codable, Sendable {
    case available
    case onComputer = "pc_only"
    case inCloud = "cloud"
    case downloading
    case incompatible

    public var label: String {
        switch self {
        case .available: return "Disponível"
        case .onComputer: return "No computador"
        case .inCloud: return "Na nuvem (Google Drive)"
        case .downloading: return "Baixando"
        case .incompatible: return "Incompatível"
        }
    }

    public var colorToken: String {
        switch self {
        case .available: return "green"
        case .onComputer: return "gray"
        case .inCloud: return "cloud_blue"
        case .downloading: return "amber"
        case .incompatible: return "muted_red"
        }
    }

    public static func resolve(
        isClassic: Bool,
        installedLocally: Bool,
        availableInCloud: Bool,
        isDownloading: Bool,
        supportedOnDevice: Bool = true
    ) -> ClassicAvailabilityState {
        if !supportedOnDevice {
            return .incompatible
        }
        if isDownloading {
            return .downloading
        }
        if installedLocally {
            return .available
        }
        if isClassic && availableInCloud {
            return .inCloud
        }
        return .onComputer
    }
}

public struct ClassicDriveFolderTask: Codable, Equatable, Sendable {
    public let id: String
    public let relativePath: String
    public let depth: Int

    public init(id: String, relativePath: String, depth: Int) {
        self.id = id
        self.relativePath = relativePath
        self.depth = depth
    }
}

public struct ClassicDriveGameItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let relativePath: String
    public let folderID: String
    public let parentRelativePath: String
    public let sizeBytes: Int64?
    public let systemHint: String
    public let downloadURL: String
    public var downloadedLocalPath: String?
    public var downloadedBytes: Int64
    public var downloadStatus: String
    public var downloadError: String?

    public init(
        id: String,
        name: String,
        title: String,
        relativePath: String,
        folderID: String,
        parentRelativePath: String,
        sizeBytes: Int64? = nil,
        systemHint: String = "",
        downloadURL: String,
        downloadedLocalPath: String? = nil,
        downloadedBytes: Int64 = 0,
        downloadStatus: String = "cloud",
        downloadError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.relativePath = relativePath
        self.folderID = folderID
        self.parentRelativePath = parentRelativePath
        self.sizeBytes = sizeBytes
        self.systemHint = systemHint
        self.downloadURL = downloadURL
        self.downloadedLocalPath = downloadedLocalPath
        self.downloadedBytes = downloadedBytes
        self.downloadStatus = downloadStatus
        self.downloadError = downloadError
    }
}

public struct ClassicDriveCheckpoint: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var rootURL: String = ""
    public var rootFolderID: String = ""
    public var storageDirectoryPath: String = ""
    public var pendingFolders: [ClassicDriveFolderTask] = []
    public var visitedFolderIDs: [String] = []
    public var seenFileIDs: [String] = []
    public var items: [ClassicDriveGameItem] = []
    public var completed: Bool = false
    public var totalFoldersRead: Int = 0
    public var lastError: String = ""
    public var updatedAt: Date = Date()

    public init() {}
}

public enum ClassicDriveError: LocalizedError, Equatable {
    case invalidFolderURL
    case disallowedHost
    case unauthorized
    case networkFailure(String)
    case responseTooLarge
    case insufficientSpace(required: Int64, available: Int64)
    case invalidDownloadPayload(String)
    case missingStorageDirectory

    public var errorDescription: String? {
        switch self {
        case .invalidFolderURL:
            return "Informe um link válido de pasta pública ou autorizada do Google Drive (HTTPS)."
        case .disallowedHost:
            return "Host não permitido para biblioteca em nuvem do Google Drive."
        case .unauthorized:
            return "Pasta privada ou sem acesso. Conecte sua conta Google Drive ou torne a pasta acessível por link."
        case .networkFailure(let detail):
            return "Falha de rede durante a leitura do Google Drive (progresso preservado): \(detail)"
        case .responseTooLarge:
            return "Resposta do Google Drive excedeu o limite seguro de 8 MB."
        case .insufficientSpace(let required, let available):
            let reqMB = max(1, required / (1024 * 1024))
            let availMB = max(0, available / (1024 * 1024))
            return "Espaço insuficiente no aparelho (\(availMB) MB livres, necessários cerca de \(reqMB) MB)."
        case .invalidDownloadPayload(let reason):
            return "O arquivo baixado não é uma ROM válida (\(reason))."
        case .missingStorageDirectory:
            return "Não foi possível preparar a pasta de armazenamento local para downloads."
        }
    }
}

public enum ClassicDriveLinkParser {
    private static let allowedExactHosts: Set<String> = [
        "drive.google.com",
        "docs.google.com",
        "drive.usercontent.google.com"
    ]

    public static func isAllowedURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        return allowedExactHosts.contains(host) || host.hasSuffix(".googleusercontent.com")
    }

    public static func parseFolderID(from rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rawPattern = "^[A-Za-z0-9_-]{10,128}$"
        if trimmed.range(of: rawPattern, options: .regularExpression) != nil {
            return trimmed
        }
        guard let url = URL(string: trimmed), isAllowedURL(url) else {
            return nil
        }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let idQuery = components.queryItems?.first(where: { $0.name == "id" })?.value,
           idQuery.range(of: rawPattern, options: .regularExpression) != nil {
            return idQuery
        }
        let path = url.path
        if let range = path.range(of: #"/folders/([A-Za-z0-9_-]{10,128})"#, options: .regularExpression) {
            let match = String(path[range]).replacingOccurrences(of: "/folders/", with: "")
            return match
        }
        return nil
    }

    public static func isExcludedPCFile(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        let blocked: Set<String> = [
            "exe", "msi", "bat", "cmd", "ps1", "vbs", "wsf", "lnk", "reg",
            "dmg", "pkg", "app", "deb", "rpm", "appimage", "sh", "dll", "so"
        ]
        return blocked.contains(ext)
    }

    public static func isAcceptedClassicROM(_ filename: String) -> Bool {
        guard !isExcludedPCFile(filename), PocketRules.safeFilename(filename) else {
            return false
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        return PocketRules.extensions.contains(ext)
    }

    public static func detectSystemHint(relativePath: String, filename: String) -> String {
        let lower = (relativePath + "/" + filename).lowercased()
        if lower.contains("ppsspp") || lower.contains("/psp/") || filename.lowercased().hasSuffix(".cso") { return "psp" }
        if lower.contains("/nds/") || filename.lowercased().hasSuffix(".nds") { return "nds" }
        if lower.contains("/3ds/") || filename.lowercased().hasSuffix(".3ds") || filename.lowercased().hasSuffix(".cia") { return "3ds" }
        if lower.contains("/gba/") || filename.lowercased().hasSuffix(".gba") { return "gba" }
        if lower.contains("/gbc/") || filename.lowercased().hasSuffix(".gbc") { return "gbc" }
        if lower.contains("/gb/") || filename.lowercased().hasSuffix(".gb") { return "gb" }
        if lower.contains("/snes/") || filename.lowercased().hasSuffix(".sfc") || filename.lowercased().hasSuffix(".smc") { return "snes" }
        if lower.contains("/nes/") || filename.lowercased().hasSuffix(".nes") { return "nes" }
        if lower.contains("/n64/") || filename.lowercased().hasSuffix(".z64") || filename.lowercased().hasSuffix(".n64") { return "n64" }
        if lower.contains("/ps1/") || lower.contains("/psx/") { return "ps1" }
        if lower.contains("/dreamcast/") || filename.lowercased().hasSuffix(".cdi") { return "dreamcast" }
        if lower.contains("/genesis/") || lower.contains("/megadrive/") || filename.lowercased().hasSuffix(".md") { return "genesis" }
        return ""
    }

    public static func directDownloadURL(fileID: String) -> URL {
        var c = URLComponents(string: "https://drive.usercontent.google.com/download")!
        c.queryItems = [
            URLQueryItem(name: "id", value: fileID),
            URLQueryItem(name: "export", value: "download"),
            URLQueryItem(name: "confirm", value: "t")
        ]
        return c.url!
    }
}

public enum ClassicDriveHtmlParser {
    public struct ParsedFolderPage: Equatable, Sendable {
        public let subfolders: [(id: String, name: String)]
        public let files: [(id: String, name: String, sizeBytes: Int64?)]
    }

    public static func parseFolderHTML(_ html: String) -> ParsedFolderPage {
        var folderMap: [String: String] = [:]
        var fileMap: [String: (name: String, sizeBytes: Int64?)] = [:]

        // Pattern 1: folder URLs in public Drive HTML view
        let folderRegex = try? NSRegularExpression(
            pattern: #"href="https://drive\.google\.com/drive(?:/u/\d+)?/folders/([A-Za-z0-9_-]{10,128})[^"]*"[^>]*>([^<]{1,180})</a>"#,
            options: [.caseInsensitive]
        )
        if let regex = folderRegex {
            let ns = html as NSString
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                let rawName = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawName.isEmpty {
                    folderMap[id] = decodeHTMLEntities(rawName)
                }
            }
        }

        // Pattern 2: file links
        let fileRegex = try? NSRegularExpression(
            pattern: #"href="https://drive\.google\.com/file/d/([A-Za-z0-9_-]{10,128})/[^"]*"[^>]*>([^<]{1,220})</a>"#,
            options: [.caseInsensitive]
        )
        if let regex = fileRegex {
            let ns = html as NSString
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                let rawName = decodeHTMLEntities(ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines))
                if !rawName.isEmpty {
                    fileMap[id] = (rawName, nil)
                }
            }
        }

        // Pattern 3: data-id blocks / JSON entry fallback `[null,"ID"] ... title`
        let dataIdRegex = try? NSRegularExpression(
            pattern: #"data-id="([A-Za-z0-9_-]{10,128})"[^>]*?(?:data-target="([^"]*)")?[^>]*?>[\s\S]{0,600}?(?:aria-label|data-tooltip)="([^"]{1,220})""#,
            options: [.caseInsensitive]
        )
        if let regex = dataIdRegex {
            let ns = html as NSString
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                let target = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)).lowercased() : ""
                let name = decodeHTMLEntities(ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines))
                guard !name.isEmpty else { continue }
                if target == "folder" || (!name.contains(".") && !ClassicDriveLinkParser.isAcceptedClassicROM(name)) {
                    if folderMap[id] == nil { folderMap[id] = name }
                } else if fileMap[id] == nil {
                    fileMap[id] = (name, nil)
                }
            }
        }

        let subfolders = folderMap.map { (id: $0.key, name: $0.value) }.sorted { $0.id < $1.id }
        let files = fileMap.map { (id: $0.key, name: $0.value.name, sizeBytes: $0.value.sizeBytes) }.sorted { $0.id < $1.id }
        return ParsedFolderPage(subfolders: subfolders, files: files)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

public protocol ClassicDriveHTTPTransport: Sendable {
    func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data)
    func downloadFile(url: URL, to destination: URL, bearerToken: String?, progress: @Sendable (Int64, Int64?) -> Void) async throws -> Int64
}

public final class URLSessionDriveTransport: ClassicDriveHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private static let maxResponseBytes = 8 * 1024 * 1024

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    public func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data) {
        let urlString = "https://drive.google.com/embeddedfolderview?id=\(folderID)#list"
        guard let url = URL(string: urlString), ClassicDriveLinkParser.isAllowedURL(url) else {
            throw ClassicDriveError.disallowedHost
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("BRUMCLASSICSMobile/0.31.0", forHTTPHeaderField: "User-Agent")
        if let token = bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard data.count <= Self.maxResponseBytes else {
            throw ClassicDriveError.responseTooLarge
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    public func downloadFile(
        url: URL,
        to destination: URL,
        bearerToken: String?,
        progress: @Sendable (Int64, Int64?) -> Void
    ) async throws -> Int64 {
        guard ClassicDriveLinkParser.isAllowedURL(url) else {
            throw ClassicDriveError.disallowedHost
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("BRUMCLASSICSMobile/0.31.0", forHTTPHeaderField: "User-Agent")
        if let token = bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (tempURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClassicDriveError.networkFailure("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        if let mime = http.mimeType?.lowercased(), mime.contains("text/html") {
            throw ClassicDriveError.invalidDownloadPayload("Página HTML retornada em vez do arquivo ROM")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else {
            throw ClassicDriveError.invalidDownloadPayload("Arquivo vazio")
        }
        progress(size, size)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return size
    }
}

public final class ClassicDriveKeychainStore {
    private static let service = "com.brumclassics.mobile.drive"
    private static let account = "oauth_access_token"

    public static func saveToken(_ token: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty,
              let data = token.data(using: .utf8) else {
            return
        }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    public static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            return nil
        }
        return token
    }
}

public actor ClassicDriveCloudService {
    public static let batchFolderBudget = 100
    public static let maxBatchFiles = 5000
    public static let maxDepth = 12

    private let stateURL: URL
    private let defaultDownloadRoot: URL
    private let transport: ClassicDriveHTTPTransport
    private var checkpoint: ClassicDriveCheckpoint
    private var activeDownloads: [String: Task<URL, Error>] = [:]

    public init(
        stateDirectory: URL? = nil,
        defaultDownloadRoot: URL? = nil,
        transport: ClassicDriveHTTPTransport = URLSessionDriveTransport()
    ) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let stateDir = stateDirectory ?? appSupport.appendingPathComponent("ClassicsDrive", isDirectory: true)
        self.stateURL = stateDir.appendingPathComponent("checkpoint.json")
        self.defaultDownloadRoot = defaultDownloadRoot ?? appSupport.appendingPathComponent("ClassicsEverywhere/DriveDownloads", isDirectory: true)
        self.transport = transport
        if let data = try? Data(contentsOf: stateURL),
           let decoded = try? JSONDecoder().decode(ClassicDriveCheckpoint.self, from: data) {
            self.checkpoint = decoded
        } else {
            self.checkpoint = ClassicDriveCheckpoint()
        }
    }

    public func currentCheckpoint() -> ClassicDriveCheckpoint {
        checkpoint
    }

    public func setStorageDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        checkpoint.storageDirectoryPath = directory.path
        try persist()
    }

    public func resolvedStorageDirectory() -> URL {
        if !checkpoint.storageDirectoryPath.isEmpty {
            return URL(fileURLWithPath: checkpoint.storageDirectoryPath, isDirectory: true)
        }
        return defaultDownloadRoot
    }

    public func availableFreeSpaceBytes() -> Int64 {
        let dir = resolvedStorageDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let values = try? dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let cap = values.volumeAvailableCapacityForImportantUsage, cap > 0 {
            return cap
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: dir.path),
           let free = attrs[.systemFreeSize] as? NSNumber {
            return free.int64Value
        }
        return 0
    }

    public func startOrRefreshScan(folderURL: String) async throws -> ClassicDriveCheckpoint {
        guard let folderID = ClassicDriveLinkParser.parseFolderID(from: folderURL) else {
            throw ClassicDriveError.invalidFolderURL
        }
        let previousByID = Dictionary(uniqueKeysWithValues: checkpoint.items.map { ($0.id, $0) })
        let storage = checkpoint.storageDirectoryPath
        checkpoint = ClassicDriveCheckpoint()
        checkpoint.rootURL = folderURL.trimmingCharacters(in: .whitespacesAndNewlines)
        checkpoint.rootFolderID = folderID
        checkpoint.storageDirectoryPath = storage
        checkpoint.pendingFolders = [ClassicDriveFolderTask(id: folderID, relativePath: "", depth: 0)]
        // Keep previous local items intact until scan finishes
        checkpoint.items = Array(previousByID.values)
        try persist()
        return try await runScanBatch(previousByID: previousByID)
    }

    public func continueScan() async throws -> ClassicDriveCheckpoint {
        guard !checkpoint.rootFolderID.isEmpty else {
            throw ClassicDriveError.invalidFolderURL
        }
        let previousByID = Dictionary(uniqueKeysWithValues: checkpoint.items.map { ($0.id, $0) })
        return try await runScanBatch(previousByID: previousByID)
    }

    private func runScanBatch(previousByID: [String: ClassicDriveGameItem]) async throws -> ClassicDriveCheckpoint {
        let token = ClassicDriveKeychainStore.loadToken()
        var visited = Set(checkpoint.visitedFolderIDs)
        var seenFiles = Set(checkpoint.seenFileIDs)
        var byID = Dictionary(uniqueKeysWithValues: checkpoint.items.map { ($0.id, $0) })
        var foldersThisBatch = 0
        var filesThisBatch = 0
        checkpoint.lastError = ""

        while !checkpoint.pendingFolders.isEmpty && foldersThisBatch < Self.batchFolderBudget && filesThisBatch < Self.maxBatchFiles {
            let folder = checkpoint.pendingFolders.removeFirst()
            if visited.contains(folder.id) || folder.depth > Self.maxDepth {
                continue
            }
            let (status, body): (Int, Data)
            do {
                (status, body) = try await transport.fetchFolderPage(folderID: folder.id, bearerToken: token)
            } catch let driveErr as ClassicDriveError {
                checkpoint.pendingFolders.insert(folder, at: 0)
                checkpoint.lastError = driveErr.localizedDescription
                try? persist()
                throw driveErr
            } catch {
                checkpoint.pendingFolders.insert(folder, at: 0)
                let wrapped = ClassicDriveError.networkFailure(error.localizedDescription)
                checkpoint.lastError = wrapped.localizedDescription
                try? persist()
                throw wrapped
            }

            if status == 401 || status == 403 {
                checkpoint.pendingFolders.insert(folder, at: 0)
                checkpoint.lastError = ClassicDriveError.unauthorized.localizedDescription
                try? persist()
                throw ClassicDriveError.unauthorized
            }
            guard (200..<300).contains(status), let html = String(data: body, encoding: .utf8) else {
                checkpoint.pendingFolders.insert(folder, at: 0)
                let err = ClassicDriveError.networkFailure("HTTP \(status)")
                checkpoint.lastError = err.localizedDescription
                try? persist()
                throw err
            }

            visited.insert(folder.id)
            foldersThisBatch += 1
            checkpoint.totalFoldersRead += 1

            let parsed = ClassicDriveHtmlParser.parseFolderHTML(html)
            for sub in parsed.subfolders where !visited.contains(sub.id) {
                let rel = folder.relativePath.isEmpty ? sub.name : "\(folder.relativePath)/\(sub.name)"
                checkpoint.pendingFolders.append(ClassicDriveFolderTask(id: sub.id, relativePath: rel, depth: folder.depth + 1))
            }
            for file in parsed.files where ClassicDriveLinkParser.isAcceptedClassicROM(file.name) {
                seenFiles.insert(file.id)
                filesThisBatch += 1
                let rel = folder.relativePath.isEmpty ? file.name : "\(folder.relativePath)/\(file.name)"
                let prev = byID[file.id] ?? previousByID[file.id]
                byID[file.id] = ClassicDriveGameItem(
                    id: file.id,
                    name: file.name,
                    title: ROMTitleRules.clean(file.name),
                    relativePath: rel,
                    folderID: folder.id,
                    parentRelativePath: folder.relativePath,
                    sizeBytes: file.sizeBytes ?? prev?.sizeBytes,
                    systemHint: ClassicDriveLinkParser.detectSystemHint(relativePath: rel, filename: file.name),
                    downloadURL: ClassicDriveLinkParser.directDownloadURL(fileID: file.id).absoluteString,
                    downloadedLocalPath: prev?.downloadedLocalPath,
                    downloadedBytes: prev?.downloadedBytes ?? 0,
                    downloadStatus: prev?.downloadedLocalPath != nil ? "available" : "cloud",
                    downloadError: nil
                )
            }
            checkpoint.visitedFolderIDs = Array(visited)
            checkpoint.seenFileIDs = Array(seenFiles)
            checkpoint.items = Array(byID.values).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            try persist()
        }

        if checkpoint.pendingFolders.isEmpty {
            checkpoint.completed = true
            // Reconcile only after full scan completion, keeping already downloaded items offline.
            checkpoint.items = checkpoint.items.filter { seenFiles.contains($0.id) || $0.downloadedLocalPath != nil }
        } else {
            checkpoint.completed = false
        }
        checkpoint.updatedAt = Date()
        try persist()
        return checkpoint
    }

    public func downloadGame(fileID: String, onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil) async throws -> URL {
        if let existingTask = activeDownloads[fileID] {
            return try await existingTask.value
        }
        guard let index = checkpoint.items.firstIndex(where: { $0.id == fileID }) else {
            throw ClassicDriveError.invalidDownloadPayload("Jogo não encontrado no catálogo")
        }
        let item = checkpoint.items[index]
        if let existingPath = item.downloadedLocalPath, FileManager.default.fileExists(atPath: existingPath) {
            return URL(fileURLWithPath: existingPath)
        }
        let free = availableFreeSpaceBytes()
        if let expected = item.sizeBytes, expected > 0, free > 0 && free < expected {
            throw ClassicDriveError.insufficientSpace(required: expected, available: free)
        }
        guard let url = URL(string: item.downloadURL), ClassicDriveLinkParser.isAllowedURL(url) else {
            throw ClassicDriveError.disallowedHost
        }

        let storageDir = resolvedStorageDirectory()
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let safeFile = (item.name as NSString).lastPathComponent
        let dest = storageDir.appendingPathComponent("\(item.id)_\(safeFile)")
        let token = ClassicDriveKeychainStore.loadToken()

        checkpoint.items[index].downloadStatus = "downloading"
        checkpoint.items[index].downloadError = nil
        try? persist()

        let task = Task<URL, Error> {
            let downloadedSize = try await self.transport.downloadFile(url: url, to: dest, bearerToken: token) { received, total in
                onProgress?(received, total)
            }
            guard downloadedSize > 0 else {
                throw ClassicDriveError.invalidDownloadPayload("Tamanho zero")
            }
            return dest
        }
        activeDownloads[fileID] = task
        do {
            let finalURL = try await task.value
            activeDownloads.removeValue(forKey: fileID)
            if let idx = checkpoint.items.firstIndex(where: { $0.id == fileID }) {
                checkpoint.items[idx].downloadedLocalPath = finalURL.path
                checkpoint.items[idx].downloadStatus = "available"
                checkpoint.items[idx].downloadError = nil
                if let attrs = try? FileManager.default.attributesOfItem(atPath: finalURL.path),
                   let bytes = (attrs[.size] as? NSNumber)?.int64Value {
                    checkpoint.items[idx].downloadedBytes = bytes
                }
                try? persist()
            }
            return finalURL
        } catch {
            activeDownloads.removeValue(forKey: fileID)
            if let idx = checkpoint.items.firstIndex(where: { $0.id == fileID }) {
                checkpoint.items[idx].downloadStatus = "cloud"
                checkpoint.items[idx].downloadError = error.localizedDescription
                try? persist()
            }
            throw error
        }
    }

    public func cancelDownload(fileID: String) {
        activeDownloads[fileID]?.cancel()
        activeDownloads.removeValue(forKey: fileID)
        if let idx = checkpoint.items.firstIndex(where: { $0.id == fileID }) {
            checkpoint.items[idx].downloadStatus = checkpoint.items[idx].downloadedLocalPath != nil ? "available" : "cloud"
            try? persist()
        }
    }

    public func availabilityState(for item: ClassicDriveGameItem, supportedOnDevice: Bool = true) -> ClassicAvailabilityState {
        let installed = item.downloadedLocalPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        let downloading = activeDownloads[item.id] != nil || item.downloadStatus == "downloading"
        return ClassicAvailabilityState.resolve(
            isClassic: true,
            installedLocally: installed,
            availableInCloud: true,
            isDownloading: downloading,
            supportedOnDevice: supportedOnDevice
        )
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
