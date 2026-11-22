import Foundation

struct PersonalUpdateManifest: Codable, Equatable, Sendable {
    let version: String
    let build: Int
    let minimumIOS: String
    let buildURL: URL
    let notes: [String]
    let downloadURL: URL?
    let sizeBytes: Int64?
    let sha256: String?
    let releaseDate: String?
    let sourceURL: URL?

    init(
        version: String,
        build: Int,
        minimumIOS: String,
        buildURL: URL,
        notes: [String],
        downloadURL: URL? = nil,
        sizeBytes: Int64? = nil,
        sha256: String? = nil,
        releaseDate: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.version = version
        self.build = build
        self.minimumIOS = minimumIOS
        self.buildURL = buildURL
        self.notes = notes
        self.downloadURL = downloadURL
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.releaseDate = releaseDate
        self.sourceURL = sourceURL
    }

    enum CodingKeys: String, CodingKey {
        case version, build, notes, downloadURL, sizeBytes, sha256, releaseDate, sourceURL
        case minimumIOS = "minimumIos"
        case buildURL = "buildUrl"
    }
}

enum PersonalUpdateState: Equatable {
    case idle
    case checking
    case current
    case available(PersonalUpdateManifest)
    case failed(String)
}

enum SideStoreLinks {
    static func addSourceURL(sourceURL: URL = PersonalUpdateService.sideStoreSourceURL) -> URL? {
        var components = URLComponents()
        components.scheme = "sidestore"
        components.host = "source"
        components.queryItems = [URLQueryItem(name: "url", value: sourceURL.absoluteString)]
        return components.url
    }

    static func installIPAURL(_ ipaURL: URL) -> URL? {
        guard SideStoreSourceParser.isValidOfficialIOSDownloadURL(ipaURL) else { return nil }
        var components = URLComponents()
        components.scheme = "sidestore"
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: ipaURL.absoluteString)]
        return components.url
    }

    static func releasePageURL(for version: String) -> URL {
        URL(string: "https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v\(version)")!
    }
}

enum SideStoreSourceParser {
    private struct SourceDocument: Decodable {
        let sourceURL: String?
        let apps: [AppEntry]
    }

    private struct AppEntry: Decodable {
        let bundleIdentifier: String
        let versions: [VersionEntry]
    }

    private struct VersionEntry: Decodable {
        let version: String
        let buildVersion: String?
        let date: String?
        let localizedDescription: String?
        let downloadURL: String
        let size: Int64?
        let sha256: String?
        let minOSVersion: String?
    }

    static func isValidOfficialIOSDownloadURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com" else {
            return false
        }
        let path = url.path
        if path.lowercased().contains("/releases/latest") { return false }
        let pattern = #"^/GBrum0o0/BRUMCLASSICS/releases/download/ios-v(\d+\.\d+\.\d+)/BRUMCLASSICS-MOVEL-IOS-\1\.ipa$"#
        return path.range(of: pattern, options: .regularExpression) != nil
    }

    static func latestManifest(from data: Data) throws -> PersonalUpdateManifest {
        let document = try JSONDecoder().decode(SourceDocument.self, from: data)
        guard let app = document.apps.first(where: { $0.bundleIdentifier == PersonalUpdateService.expectedBundleIdentifier }) else {
            throw UpdateError.manifestUnavailable
        }

        let candidates: [(build: Int, parts: [Int], manifest: PersonalUpdateManifest)] = app.versions.compactMap { entry in
            guard let build = Int((entry.buildVersion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
                  build > 0,
                  let downloadURL = URL(string: entry.downloadURL),
                  isValidOfficialIOSDownloadURL(downloadURL) else {
                return nil
            }
            let versionParts = entry.version.split(separator: ".").map { Int($0) ?? 0 }
            guard versionParts.count >= 2 else { return nil }
            let notes = normalizedNotes(from: entry.localizedDescription)
            let manifest = PersonalUpdateManifest(
                version: entry.version,
                build: build,
                minimumIOS: (entry.minOSVersion?.isEmpty == false ? entry.minOSVersion! : "16.0"),
                buildURL: SideStoreLinks.releasePageURL(for: entry.version),
                notes: notes,
                downloadURL: downloadURL,
                sizeBytes: entry.size,
                sha256: entry.sha256?.lowercased(),
                releaseDate: entry.date,
                sourceURL: document.sourceURL.flatMap(URL.init(string:)) ?? PersonalUpdateService.sideStoreSourceURL
            )
            return (build: build, parts: versionParts, manifest: manifest)
        }

        guard let newest = candidates.max(by: { lhs, rhs in
            let count = max(lhs.parts.count, rhs.parts.count)
            for idx in 0..<count {
                let l = idx < lhs.parts.count ? lhs.parts[idx] : 0
                let r = idx < rhs.parts.count ? rhs.parts[idx] : 0
                if l != r { return l < r }
            }
            return lhs.build < rhs.build
        }) else {
            throw UpdateError.manifestUnavailable
        }
        return newest.manifest
    }

    private static func normalizedNotes(from description: String?) -> [String] {
        guard let description, !description.isEmpty else { return [] }
        let rawLines = description
            .components(separatedBy: .newlines)
            .map { line -> String in
                var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                while text.hasPrefix("#") || text.hasPrefix("-") || text.hasPrefix("*") || text.hasPrefix("•") {
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return text
            }
            .filter { !$0.isEmpty }
        return Array(rawLines.prefix(8))
    }
}

actor PersonalUpdateService {
    static let expectedBundleIdentifier = "com.brumclassics.mobile.ios"
    static let sideStoreSourceURL = URL(string: "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/sidestore-source/sidestore-source.json")!
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/main/ios-update.json")!

    func check(currentVersion: String, currentBuild: Int) async throws -> PersonalUpdateManifest? {
        let latestManifest: PersonalUpdateManifest
        if let sideStoreManifest = try? await fetchSideStoreManifest() {
            latestManifest = sideStoreManifest
        } else {
            latestManifest = try await fetchFallbackManifest()
        }
        guard Self.isNewer(latestManifest, thanVersion: currentVersion, build: currentBuild) else { return nil }
        return latestManifest
    }

    private func fetchSideStoreManifest() async throws -> PersonalUpdateManifest {
        let data = try await fetchFreshJSON(from: Self.sideStoreSourceURL)
        return try SideStoreSourceParser.latestManifest(from: data)
    }

    private func fetchFallbackManifest() async throws -> PersonalUpdateManifest {
        let data = try await fetchFreshJSON(from: Self.manifestURL)
        return try JSONDecoder().decode(PersonalUpdateManifest.self, from: data)
    }

    private func fetchFreshJSON(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count <= 2 * 1024 * 1024 else {
            throw UpdateError.manifestUnavailable
        }
        return data
    }

    nonisolated static func isNewer(_ manifest: PersonalUpdateManifest, thanVersion currentVersion: String, build currentBuild: Int) -> Bool {
        let remote = manifest.version.split(separator: ".").map { Int($0) ?? 0 }
        let local = currentVersion.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(remote.count, local.count)

        for index in 0..<count {
            let remotePart = index < remote.count ? remote[index] : 0
            let localPart = index < local.count ? local[index] : 0
            if remotePart != localPart { return remotePart > localPart }
        }
        return manifest.build > currentBuild
    }
}

enum UpdateError: LocalizedError {
    case manifestUnavailable

    var errorDescription: String? {
        switch self {
        case .manifestUnavailable:
            return "Não foi possível consultar a fonte de atualização agora. O aplicativo continua funcionando normalmente."
        }
    }
}
