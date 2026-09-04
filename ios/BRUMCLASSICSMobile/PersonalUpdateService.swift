import Foundation

struct PersonalUpdateManifest: Codable, Equatable {
    let version: String
    let build: Int
    let minimumIOS: String
    let buildURL: URL
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case version, build, notes
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
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/main/ios-update.json")!

    func check(currentVersion: String, currentBuild: Int) async throws -> PersonalUpdateManifest? {
        var request = URLRequest(url: Self.manifestURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateError.manifestUnavailable
        }

        let manifest = try JSONDecoder().decode(PersonalUpdateManifest.self, from: data)
        guard Self.isNewer(manifest, thanVersion: currentVersion, build: currentBuild) else { return nil }
        return manifest
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
            return "Não foi possível consultar a atualização pessoal agora. O aplicativo continua funcionando normalmente."
        }
    }
}
