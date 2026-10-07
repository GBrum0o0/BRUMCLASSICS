import CryptoKit
import Foundation

struct NativeSaveCandidatesResponse: Decodable, Sendable {
    let protocolVersion: Int
    let transferEnabled: Bool
    let downloadEnabled: Bool
    let candidates: [NativeSaveCandidate]

    func validated(for canonicalGameID: String) throws -> [NativeSaveCandidate] {
        guard protocolVersion == 1, downloadEnabled,
              candidates.allSatisfy({ $0.isValid(for: canonicalGameID) }) else {
            throw BridgeError.invalidResponse("O catálogo de saves do Launcher Beta é incompatível. Nenhum save foi alterado.")
        }
        return candidates
    }
}

struct NativeSaveCandidate: Decodable, Sendable {
    let versionId: String
    let gameId: String
    let canonicalGameId: String
    let profileId: String
    let createdAt: String
    let files: [NativeSaveFile]

    func isValid(for canonicalGameID: String) -> Bool {
        canonicalGameId == canonicalGameID && !gameId.isEmpty && !profileId.isEmpty &&
        !versionId.isEmpty && versionId.count <= 80 && versionId.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45
        } && !files.isEmpty && files.allSatisfy({ $0.isValid }) &&
        Set(files.map(\.fileIndex)).count == files.count
    }
}

struct NativeSaveFile: Decodable, Sendable {
    let fileIndex: Int
    let name: String
    let size: Int
    let sha256: String

    var isValid: Bool {
        fileIndex >= 0 && fileIndex < 10_000 && size >= 0 && size <= 2_147_483_648 &&
        !name.isEmpty && name == (name as NSString).lastPathComponent && !name.contains("\\") &&
        !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) &&
        sha256.utf8.count == 64 && sha256.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
        }
    }
}

enum NativeSaveTransfer {
    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var digest = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
