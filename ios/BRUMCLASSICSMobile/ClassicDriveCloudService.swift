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
    public let resourceKey: String?

    public init(id: String, relativePath: String, depth: Int, resourceKey: String? = nil) {
        self.id = id
        self.relativePath = relativePath
        self.depth = depth
        self.resourceKey = resourceKey
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
    public var rootResourceKey: String? = nil
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
              url.user == nil, url.password == nil, url.port == nil,
              let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        return allowedExactHosts.contains(host) || host.hasSuffix(".googleusercontent.com")
    }

    public static func parseLink(from rawInput: String) -> (id: String, isFolder: Bool, resourceKey: String?)? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rawPattern = "^[A-Za-z0-9_-]{10,128}$"
        if trimmed.range(of: rawPattern, options: .regularExpression) != nil {
            return (trimmed, true, nil)
        }
        guard let url = URL(string: trimmed), isAllowedURL(url) else {
            return nil
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let resourceKeyRaw = components?.queryItems?.first(where: { $0.name.caseInsensitiveCompare("resourcekey") == .orderedSame })?.value
        let resourceKey: String? = (resourceKeyRaw?.range(of: "^[A-Za-z0-9_-]{1,200}$", options: .regularExpression) != nil) ? resourceKeyRaw : nil
        let path = url.path

        if let range = path.range(of: #"/folders/([A-Za-z0-9_-]{10,128})"#, options: .regularExpression) {
            let match = String(path[range]).replacingOccurrences(of: "/folders/", with: "")
            return (match, true, resourceKey)
        }
        if let range = path.range(of: #"/file/d/([A-Za-z0-9_-]{10,128})"#, options: .regularExpression) {
            let match = String(path[range]).replacingOccurrences(of: "/file/d/", with: "")
            return (match, false, resourceKey)
        }
        if let idQuery = components?.queryItems?.first(where: { $0.name == "id" })?.value,
           idQuery.range(of: rawPattern, options: .regularExpression) != nil {
            let isFolder = path.lowercased().contains("folder")
            return (idQuery, isFolder, resourceKey)
        }
        return nil
    }

    public static func parseFolderID(from rawInput: String) -> String? {
        parseLink(from: rawInput)?.id
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
        let combined = (relativePath.isEmpty ? "" : relativePath + "/") + filename
        let parts = combined
            .lowercased()
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .dropLast()
            .map(String.init)
        let ext = (filename as NSString).pathExtension.lowercased()

        // Nearest recognized console folder wins (mirrors IntegratedEmulatorSupport).
        for folder in parts.reversed() {
            switch folder {
            case "psp", "ppsspp", "playstation portable", "sony psp":
                return "psp"
            case "ps2", "playstation 2", "sony playstation 2":
                return "ps2"
            case "ps1", "psx", "playstation", "playstation 1", "sony playstation":
                return "psx"
            case "nds", "ds", "nintendo ds":
                return "nds"
            case "3ds", "n3ds", "nintendo 3ds":
                return "3ds"
            case "gba", "game boy advance", "gameboy advance":
                return "gba"
            case "gbc", "game boy color", "gameboy color":
                return "gbc"
            case "gb", "game boy", "gameboy":
                return "gb"
            case "snes", "sfc", "super nintendo", "super famicom":
                return "sfc"
            case "nes", "famicom", "nintendo", "nintendo entertainment system":
                return "nes"
            case "n64", "nintendo 64":
                return "n64"
            case "gamecube", "gc", "nintendo gamecube":
                return "gamecube"
            case "wii", "nintendo wii":
                return "wii"
            case "wiiu", "wii u", "nintendo wii u":
                return "wiiu"
            case "dreamcast", "sega dreamcast":
                return "dreamcast"
            case "saturn", "sega saturn":
                return "saturn"
            case "segacd", "sega cd", "megacd", "mega cd":
                return "segacd"
            case "32x", "sega 32x":
                return "32x"
            case "genesis", "megadrive", "mega drive", "sega genesis", "md":
                return "md"
            case "sms", "master system", "sega master system":
                return "sms"
            case "gg", "game gear", "sega game gear":
                return "gg"
            case "pce", "pc engine", "turbografx-16", "turbografx 16":
                return "pce"
            case "neogeo", "neo geo", "neo-geo":
                return "neogeo"
            case "ws", "wonderswan":
                return "ws"
            case "wsc", "wonderswan color":
                return "wsc"
            case "atari2600", "a2600", "atari 2600":
                return "atari2600"
            case "arcade", "mame", "fbneo":
                return "arcade"
            default:
                continue
            }
        }

        switch ext {
        case "cso": return "psp"
        case "nds": return "nds"
        case "3ds", "3dsx", "z3dsx", "cci", "zcci", "cxi", "zcxi": return "3ds"
        case "gba": return "gba"
        case "gbc": return "gbc"
        case "gb": return "gb"
        case "sfc", "smc": return "sfc"
        case "nes": return "nes"
        case "z64", "n64", "v64": return "n64"
        case "rvz", "gcz", "ciso", "gcm": return "gamecube"
        case "cdi", "gdi": return "dreamcast"
        case "md", "gen", "smd": return "md"
        case "32x": return "32x"
        case "sms": return "sms"
        case "gg": return "gg"
        case "pce": return "pce"
        case "neo": return "neogeo"
        case "ws": return "ws"
        case "wsc": return "wsc"
        case "a26": return "atari2600"
        default: return ""
        }
    }

    public static func directDownloadURL(fileID: String, resourceKey: String? = nil) -> URL {
        var c = URLComponents(string: "https://drive.usercontent.google.com/download")!
        var items = [
            URLQueryItem(name: "id", value: fileID),
            URLQueryItem(name: "export", value: "download"),
            URLQueryItem(name: "confirm", value: "t")
        ]
        if let rk = resourceKey, !rk.isEmpty {
            items.append(URLQueryItem(name: "resourcekey", value: rk))
        }
        c.queryItems = items
        return c.url!
    }
}

public enum ClassicDriveHtmlParser {
    public struct ParsedFolderPage: Equatable, Sendable {
        public let subfolders: [(id: String, name: String)]
        public let files: [(id: String, name: String, sizeBytes: Int64?)]

        public static func == (lhs: ParsedFolderPage, rhs: ParsedFolderPage) -> Bool {
            lhs.subfolders.elementsEqual(rhs.subfolders) { $0.id == $1.id && $0.name == $1.name } &&
            lhs.files.elementsEqual(rhs.files) { $0.id == $1.id && $0.name == $1.name && $0.sizeBytes == $1.sizeBytes }
        }
    }

    public struct DetailedParsedFolderPage: Equatable, Sendable {
        public let subfolders: [(id: String, name: String, resourceKey: String?)]
        public let files: [(id: String, name: String, resourceKey: String?, sizeBytes: Int64?)]

        public static func == (lhs: DetailedParsedFolderPage, rhs: DetailedParsedFolderPage) -> Bool {
            lhs.subfolders.elementsEqual(rhs.subfolders) { $0.id == $1.id && $0.name == $1.name && $0.resourceKey == $1.resourceKey } &&
            lhs.files.elementsEqual(rhs.files) { $0.id == $1.id && $0.name == $1.name && $0.resourceKey == $1.resourceKey && $0.sizeBytes == $1.sizeBytes }
        }
    }

    public static func parseFolderHTML(_ html: String) -> ParsedFolderPage {
        let detailed = parseFolderHTMLDetailed(html)
        return ParsedFolderPage(
            subfolders: detailed.subfolders.map { (id: $0.id, name: $0.name) },
            files: detailed.files.map { (id: $0.id, name: $0.name, sizeBytes: $0.sizeBytes) }
        )
    }

    public static func isServiceLoginHTML(_ html: String) -> Bool {
        html.range(of: #"accounts\.google\.com/ServiceLogin"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    public static func extractSingleFileTitle(from html: String) -> String? {
        guard let titleRegex = try? NSRegularExpression(pattern: #"<title[^>]*>([\s\S]*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = html as NSString
        guard let match = titleRegex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let raw = stripTagsAndDecode(ns.substring(with: match.range(at: 1)))
        let cleaned = raw.replacingOccurrences(of: #"\s*[-–]\s*Google Drive\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    public static func parseFolderHTMLDetailed(_ html: String) -> DetailedParsedFolderPage {
        var folderMap: [String: (name: String, resourceKey: String?)] = [:]
        var fileMap: [String: (name: String, resourceKey: String?, sizeBytes: Int64?)] = [:]

        // Primary parser matching Desktop (`src/classic-drive-service.js`): real Drive
        // embeddedfolderview wraps names inside nested <div class="flip-entry-title"> tags within <a>.
        let anchorRegex = try? NSRegularExpression(
            pattern: #"<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let flipTitleRegex = try? NSRegularExpression(
            pattern: #"class=["'][^"']*flip-entry-title[^"']*["'][^>]*>([\s\S]*?)</div>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        if let regex = anchorRegex {
            let ns = html as NSString
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let rawHref = decodeHTMLEntities(ns.substring(with: m.range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let link = ClassicDriveLinkParser.parseLink(from: rawHref) else { continue }
                let innerHTML = ns.substring(with: m.range(at: 2))
                var extracted = ""
                if let titleRegex = flipTitleRegex,
                   let tm = titleRegex.firstMatch(in: innerHTML, range: NSRange(location: 0, length: (innerHTML as NSString).length)) {
                    extracted = stripTagsAndDecode((innerHTML as NSString).substring(with: tm.range(at: 1)))
                }
                if extracted.isEmpty {
                    extracted = stripTagsAndDecode(innerHTML)
                }
                let cleanName = String(extracted.prefix(300)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanName.isEmpty else { continue }
                if link.isFolder {
                    if folderMap[link.id] == nil { folderMap[link.id] = (cleanName, link.resourceKey) }
                } else {
                    if fileMap[link.id] == nil { fileMap[link.id] = (cleanName, link.resourceKey, nil) }
                }
            }
        }

        // Secondary fallback: data-id attributes with aria-label / data-tooltip
        let dataIdRegex = try? NSRegularExpression(
            pattern: #"data-id="([A-Za-z0-9_-]{10,128})"[^>]*?(?:data-target="([^"]*)")?[^>]*?>[\s\S]{0,600}?(?:aria-label|data-tooltip)="([^"]{1,220})""#,
            options: [.caseInsensitive]
        )
        if let regex = dataIdRegex {
            let ns = html as NSString
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                let target = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)).lowercased() : ""
                let name = stripTagsAndDecode(ns.substring(with: m.range(at: 3)))
                guard !name.isEmpty else { continue }
                if target == "folder" || (!name.contains(".") && !ClassicDriveLinkParser.isAcceptedClassicROM(name)) {
                    if folderMap[id] == nil { folderMap[id] = (name, nil) }
                } else if fileMap[id] == nil {
                    fileMap[id] = (name, nil, nil)
                }
            }
        }

        let subfolders = folderMap.map { (id: $0.key, name: $0.value.name, resourceKey: $0.value.resourceKey) }.sorted { $0.id < $1.id }
        let files = fileMap.map { (id: $0.key, name: $0.value.name, resourceKey: $0.value.resourceKey, sizeBytes: $0.value.sizeBytes) }.sorted { $0.id < $1.id }
        return DetailedParsedFolderPage(subfolders: subfolders, files: files)
    }

    private static func stripTagsAndDecode(_ html: String) -> String {
        let noTags = html.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        return decodeHTMLEntities(noTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"&#x([0-9a-fA-F]+);|&#(\d+);|&(amp|quot|apos|lt|gt|nbsp);"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }
        let ns = text as NSString
        var out = ""
        var lastEnd = 0
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > lastEnd {
                out += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
            }
            if m.range(at: 1).location != NSNotFound,
               let code = UInt32(ns.substring(with: m.range(at: 1)), radix: 16),
               let scalar = UnicodeScalar(code) {
                out.append(Character(scalar))
            } else if m.range(at: 2).location != NSNotFound,
                      let code = UInt32(ns.substring(with: m.range(at: 2))),
                      let scalar = UnicodeScalar(code) {
                out.append(Character(scalar))
            } else if m.range(at: 3).location != NSNotFound {
                switch ns.substring(with: m.range(at: 3)).lowercased() {
                case "amp": out.append("&")
                case "quot": out.append("\"")
                case "apos": out.append("'")
                case "lt": out.append("<")
                case "gt": out.append(">")
                case "nbsp": out.append(" ")
                default: break
                }
            }
            lastEnd = m.range.location + m.range.length
        }
        if lastEnd < ns.length {
            out += ns.substring(from: lastEnd)
        }
        return out
    }
}

public protocol ClassicDriveHTTPTransport: Sendable {
    func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data)
    func downloadFile(url: URL, to destination: URL, bearerToken: String?, progress: @Sendable (Int64, Int64?) -> Void) async throws -> Int64
}

public extension ClassicDriveHTTPTransport {
    func fetchFolderPage(folderID: String, bearerToken: String?, resourceKey: String?) async throws -> (statusCode: Int, body: Data) {
        try await fetchFolderPage(folderID: folderID, bearerToken: bearerToken)
    }
}

public final class URLSessionDriveTransport: ClassicDriveHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private static let maxResponseBytes = 8 * 1024 * 1024

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    public func fetchFolderPage(folderID: String, bearerToken: String?) async throws -> (statusCode: Int, body: Data) {
        try await fetchFolderPage(folderID: folderID, bearerToken: bearerToken, resourceKey: nil)
    }

    public func fetchFolderPage(folderID: String, bearerToken: String?, resourceKey: String?) async throws -> (statusCode: Int, body: Data) {
        var components = URLComponents(string: "https://drive.google.com/embeddedfolderview")!
        var items = [URLQueryItem(name: "id", value: folderID)]
        if let rk = resourceKey, !rk.isEmpty {
            items.append(URLQueryItem(name: "resourcekey", value: rk))
        }
        components.queryItems = items
        components.fragment = "list"
        guard let url = components.url, ClassicDriveLinkParser.isAllowedURL(url) else {
            throw ClassicDriveError.disallowedHost
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("BRUMCLASSICS", forHTTPHeaderField: "User-Agent")
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
        return try await performDownload(url: url, to: destination, bearerToken: bearerToken, allowConfirmRetry: true, progress: progress)
    }

    private func performDownload(
        url: URL,
        to destination: URL,
        bearerToken: String?,
        allowConfirmRetry: Bool,
        progress: @Sendable (Int64, Int64?) -> Void
    ) async throws -> Int64 {
        guard ClassicDriveLinkParser.isAllowedURL(url) else {
            throw ClassicDriveError.disallowedHost
        }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("BRUMCLASSICS", forHTTPHeaderField: "User-Agent")
        if let token = bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (tempURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClassicDriveError.networkFailure("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else {
            throw ClassicDriveError.invalidDownloadPayload("Arquivo vazio")
        }
        let mimeIsHTML = http.mimeType?.lowercased().contains("text/html") ?? false
        let looksLikeHTML = mimeIsHTML || Self.fileStartsWithHTML(tempURL)
        if looksLikeHTML {
            if allowConfirmRetry, size <= 512 * 1024,
               let html = try? String(contentsOf: tempURL, encoding: .utf8),
               let confirmURL = Self.extractVirusWarningConfirmURL(from: html, baseURL: url),
               ClassicDriveLinkParser.isAllowedURL(confirmURL) {
                return try await performDownload(url: confirmURL, to: destination, bearerToken: bearerToken, allowConfirmRetry: false, progress: progress)
            }
            throw ClassicDriveError.invalidDownloadPayload("O Google Drive não liberou o arquivo. Confira o compartilhamento ou a cota.")
        }
        progress(size, size)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return size
    }

    private static func fileStartsWithHTML(_ fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 512),
              let snippet = String(data: head, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return snippet.hasPrefix("<!doctype html") || snippet.hasPrefix("<html")
    }

    private static func extractVirusWarningConfirmURL(from html: String, baseURL: URL) -> URL? {
        let formRegex = try? NSRegularExpression(pattern: #"<form[^>]*action=["']([^"']+)["'][^>]*>([\s\S]*?)</form>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        if let regex = formRegex,
           let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)) {
            let ns = html as NSString
            let rawAction = ClassicDriveHtmlParser.decodeHTMLEntities(ns.substring(with: match.range(at: 1)))
            let formBody = ns.substring(with: match.range(at: 2))
            if var comp = URLComponents(string: rawAction) ?? URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
                var queryItems = comp.queryItems ?? []
                let inputRegex = try? NSRegularExpression(pattern: #"<input[^>]*name=["']([^"']+)["'][^>]*value=["']([^"']*)["']"#, options: [.caseInsensitive])
                if let iRegex = inputRegex {
                    let fns = formBody as NSString
                    for im in iRegex.matches(in: formBody, range: NSRange(location: 0, length: fns.length)) {
                        let name = fns.substring(with: im.range(at: 1))
                        let value = ClassicDriveHtmlParser.decodeHTMLEntities(fns.substring(with: im.range(at: 2)))
                        if !queryItems.contains(where: { $0.name == name }) {
                            queryItems.append(URLQueryItem(name: name, value: value))
                        }
                    }
                }
                comp.queryItems = queryItems
                if let url = comp.url, ClassicDriveLinkParser.isAllowedURL(url) {
                    return url
                }
            }
        }
        return nil
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

public extension Notification.Name {
    static let classicDriveCatalogDidChange = Notification.Name("BrumClassicDriveCatalogDidChange")
}

public actor ClassicDriveCloudService {
    public static let shared = ClassicDriveCloudService()
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
        guard let link = ClassicDriveLinkParser.parseLink(from: folderURL) else {
            throw ClassicDriveError.invalidFolderURL
        }
        let previousByID = Dictionary(uniqueKeysWithValues: checkpoint.items.map { ($0.id, $0) })
        let storage = checkpoint.storageDirectoryPath
        checkpoint = ClassicDriveCheckpoint()
        checkpoint.rootURL = folderURL.trimmingCharacters(in: .whitespacesAndNewlines)
        checkpoint.rootFolderID = link.id
        checkpoint.rootResourceKey = link.resourceKey
        checkpoint.storageDirectoryPath = storage
        if !link.isFolder {
            let token = ClassicDriveKeychainStore.loadToken()
            let (status, body) = try await transport.fetchFolderPage(folderID: link.id, bearerToken: token, resourceKey: link.resourceKey)
            if status == 401 || status == 403 {
                throw ClassicDriveError.unauthorized
            }
            let html = String(data: body, encoding: .utf8) ?? ""
            if ClassicDriveHtmlParser.isServiceLoginHTML(html) {
                throw ClassicDriveError.unauthorized
            }
            let name = ClassicDriveHtmlParser.extractSingleFileTitle(from: html) ?? "Game_\(link.id).bin"
            guard ClassicDriveLinkParser.isAcceptedClassicROM(name) else {
                throw ClassicDriveError.invalidDownloadPayload("O link não aponta para um jogo clássico compatível.")
            }
            let prev = previousByID[link.id]
            checkpoint.items = [ClassicDriveGameItem(
                id: link.id,
                name: name,
                title: ROMTitleRules.clean(name),
                relativePath: name,
                folderID: link.id,
                parentRelativePath: "",
                sizeBytes: prev?.sizeBytes,
                systemHint: ClassicDriveLinkParser.detectSystemHint(relativePath: name, filename: name),
                downloadURL: ClassicDriveLinkParser.directDownloadURL(fileID: link.id, resourceKey: link.resourceKey).absoluteString,
                downloadedLocalPath: prev?.downloadedLocalPath,
                downloadedBytes: prev?.downloadedBytes ?? 0,
                downloadStatus: prev?.downloadedLocalPath != nil ? "available" : "cloud",
                downloadError: nil
            )]
            checkpoint.completed = true
            checkpoint.totalFoldersRead = 1
            checkpoint.updatedAt = Date()
            try persist()
            notifyCatalogChanged()
            return checkpoint
        }
        checkpoint.pendingFolders = [ClassicDriveFolderTask(id: link.id, relativePath: "", depth: 0, resourceKey: link.resourceKey)]
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
                (status, body) = try await transport.fetchFolderPage(folderID: folder.id, bearerToken: token, resourceKey: folder.resourceKey)
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

            let parsed = ClassicDriveHtmlParser.parseFolderHTMLDetailed(html)
            if ClassicDriveHtmlParser.isServiceLoginHTML(html) && parsed.subfolders.isEmpty && parsed.files.isEmpty {
                checkpoint.pendingFolders.insert(folder, at: 0)
                checkpoint.lastError = ClassicDriveError.unauthorized.localizedDescription
                try? persist()
                throw ClassicDriveError.unauthorized
            }

            visited.insert(folder.id)
            foldersThisBatch += 1
            checkpoint.totalFoldersRead += 1

            for sub in parsed.subfolders where !visited.contains(sub.id) {
                let rel = folder.relativePath.isEmpty ? sub.name : "\(folder.relativePath)/\(sub.name)"
                checkpoint.pendingFolders.append(ClassicDriveFolderTask(id: sub.id, relativePath: rel, depth: folder.depth + 1, resourceKey: sub.resourceKey))
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
                    downloadURL: ClassicDriveLinkParser.directDownloadURL(fileID: file.id, resourceKey: file.resourceKey).absoluteString,
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
        notifyCatalogChanged()
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
        let safeFile = (item.name as NSString).lastPathComponent
        let itemDir = storageDir.appendingPathComponent(item.id, isDirectory: true)
        try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)
        let dest = itemDir.appendingPathComponent(safeFile)
        let token = ClassicDriveKeychainStore.loadToken()

        checkpoint.items[index].downloadStatus = "downloading"
        checkpoint.items[index].downloadError = nil
        try? persist()
        notifyCatalogChanged()

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
            notifyCatalogChanged()
            return finalURL
        } catch {
            activeDownloads.removeValue(forKey: fileID)
            if let idx = checkpoint.items.firstIndex(where: { $0.id == fileID }) {
                checkpoint.items[idx].downloadStatus = "cloud"
                checkpoint.items[idx].downloadError = error.localizedDescription
                try? persist()
            }
            notifyCatalogChanged()
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
        notifyCatalogChanged()
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

    private func notifyCatalogChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .classicDriveCatalogDidChange, object: nil)
        }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
