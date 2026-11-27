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

actor PersonalUpdateService {
    static let expectedBundleIdentifier = "com.brumclassics.mobile.ios"
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/main/ios-update.json")!

    nonisolated static func isValidOfficialIOSReleaseURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com" else {
            return false
        }
        let path = url.path
        if path.lowercased().contains("/releases/latest") { return false }
        let tagPattern = #"^/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v(\d+\.\d+\.\d+)$"#
        let ipaPattern = #"^/GBrum0o0/BRUMCLASSICS/releases/download/ios-v(\d+\.\d+\.\d+)/BRUMCLASSICS-MOVEL-IOS-\1\.ipa$"#
        return path.range(of: tagPattern, options: .regularExpression) != nil
            || path.range(of: ipaPattern, options: .regularExpression) != nil
    }

    func check(currentVersion: String, currentBuild: Int) async throws -> PersonalUpdateManifest? {
        let latestManifest = try await fetchManifest()
        guard Self.isValidOfficialIOSReleaseURL(latestManifest.buildURL) else {
            throw UpdateError.manifestUnavailable
        }
        guard Self.isNewer(latestManifest, thanVersion: currentVersion, build: currentBuild) else { return nil }
        return latestManifest
    }

    private func fetchManifest() async throws -> PersonalUpdateManifest {
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
