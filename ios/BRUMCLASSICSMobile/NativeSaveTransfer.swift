import CryptoKit
import Foundation

struct NativeSaveCandidatesResponse: Decodable, Sendable {
    let protocolVersion: Int
    let transferEnabled: Bool
    let downloadEnabled: Bool
    let activeProfileId: String
    let candidates: [NativeSaveCandidate]

    func validated(for canonicalGameID: String) throws -> [NativeSaveCandidate] {
        guard protocolVersion == 1, downloadEnabled, !activeProfileId.isEmpty,
              candidates.allSatisfy({ $0.profileId == activeProfileId && $0.isValid(for: canonicalGameID) }) else {
            throw BridgeError.invalidResponse("O catálogo de saves do Launcher Beta é incompatível. Nenhum save foi alterado.")
        }
        return candidates
    }
}

struct NativeSaveCandidate: Decodable, Sendable {
    let versionId: String
    let revisionId: String
    let gameId: String
    let canonicalGameId: String
    let profileId: String
    let createdAt: String
    let files: [NativeSaveFile]

    func isValid(for canonicalGameID: String) -> Bool {
        canonicalGameId == canonicalGameID && !gameId.isEmpty && !profileId.isEmpty &&
        !versionId.isEmpty && versionId.count <= 80 && versionId.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45
        } && !files.isEmpty && files.count <= 256 && files.allSatisfy({ $0.isValid }) &&
        Set(files.map(\.fileIndex)).count == files.count &&
        (try? NativeSaveTransfer.revision(for: files)) == revisionId
    }
}

struct NativeSaveFile: Decodable, Sendable {
    let fileIndex: Int
    let name: String
    let size: Int
    let sha256: String

    var isValid: Bool {
        fileIndex >= 0 && fileIndex < 10_000 && size >= 0 && size <= 2_147_483_648 &&
        !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".." &&
        name == (name as NSString).lastPathComponent && !name.contains("/") && !name.contains("\\") &&
        !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) &&
        sha256.utf8.count == 64 && sha256.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
        }
    }
}

// The libretro host writes this manifest alongside its battery RAM. Existing
// manifests have no player profile, so inspection does not authorize upload.
private struct LocalBatteryManifest: Decodable {
    let schemaVersion: Int
    let canonicalGameID: String
    let systemID: String
    let slot: String
    let generation: Int
    let payloadSHA256: String
    let sizeBytes: Int
    let formatVersion: Int
}

struct VerifiedLocalBatterySave: Sendable {
    let file: URL
    let sha256: String
    let size: Int
    let generation: Int
    let revisionId: String
}

enum NativeSaveTransfer {
    // Cross-platform v2 revision: semantic filename role, SHA-256 and size,
    // encoded as length-prefixed UTF-8 and big-endian integers. A renamed
    // battery file can be recognized without treating SRAM and RTC as equal.
    static func revision(for files: [NativeSaveFile]) throws -> String {
        guard !files.isEmpty, files.count <= 256, files.allSatisfy({ $0.isValid }) else {
            throw BridgeError.invalidResponse("Arquivos de save inválidos para revisão.")
        }
        let entries = files.map { file -> (role: String, bytes: [UInt8], file: NativeSaveFile) in
            let name = file.name.precomposedStringWithCanonicalMapping
            let lower = name.lowercased()
            let role = lower.hasSuffix(".srm") ? "battery.srm" :
                (lower.hasSuffix(".rtc") ? "clock.rtc" : name)
            return (role, Array(role.utf8), file)
        }.sorted { $0.bytes.lexicographicallyPrecedes($1.bytes) }
        guard Set(entries.map { $0.role.lowercased() }).count == entries.count else {
            throw BridgeError.invalidResponse("Papéis de save nativo ambíguos.")
        }
        var data = Data("BRUM-NATIVE-SAVE-V2\0".utf8)
        appendUInt32(UInt32(entries.count), to: &data)
        for entry in entries {
            appendUInt32(UInt32(entry.bytes.count), to: &data)
            data.append(contentsOf: entry.bytes)
            let characters = Array(entry.file.sha256.utf8)
            for index in stride(from: 0, to: characters.count, by: 2) {
                let high = hexNibble(characters[index])
                let low = hexNibble(characters[index + 1])
                data.append((high << 4) | low)
            }
            appendUInt64(UInt64(entry.file.size), to: &data)
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "native:v2:\(digest)"
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8 {
        byte <= 57 ? byte - 48 : byte - 87
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: [UInt8((value >> 24) & 255), UInt8((value >> 16) & 255),
                                 UInt8((value >> 8) & 255), UInt8(value & 255)])
    }

    private static func appendUInt64(_ value: UInt64, to data: inout Data) {
        data.append(contentsOf: (0..<8).reversed().map { UInt8((value >> ($0 * 8)) & 255) })
    }

    static func inspectLocalBatterySave(for identity: CanonicalGameIdentity, savesRoot: URL? = nil) throws -> VerifiedLocalBatterySave? {
        let manager = FileManager.default
        let root = savesRoot ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IntegratedEmulator", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
        let directory = root.appendingPathComponent(identity.systemID.rawValue, isDirectory: true)
        let stem = identity.contentSHA256
        let payload = directory.appendingPathComponent("\(stem).srm")
        let metadata = directory.appendingPathComponent("\(stem).save.json")
        let hasPayload = manager.fileExists(atPath: payload.path)
        let hasMetadata = manager.fileExists(atPath: metadata.path)
        if !hasPayload && !hasMetadata { return nil }
        guard hasPayload && hasMetadata else {
            throw BridgeError.invalidResponse("O save local está incompleto. Nenhum progresso foi enviado.")
        }
        let payloadValues = try payload.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        let metadataValues = try metadata.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard payloadValues.isRegularFile == true, payloadValues.isSymbolicLink != true,
              metadataValues.isRegularFile == true, metadataValues.isSymbolicLink != true,
              let actualSize = payloadValues.fileSize, actualSize > 0, actualSize <= 2_147_483_648,
              let metadataSize = metadataValues.fileSize, metadataSize > 0, metadataSize <= 65_536 else {
            throw BridgeError.invalidResponse("O save local não é um arquivo regular válido.")
        }
        let manifest = try JSONDecoder().decode(LocalBatteryManifest.self, from: Data(contentsOf: metadata))
        guard manifest.schemaVersion == 1, manifest.formatVersion == 1,
              manifest.canonicalGameID == identity.canonicalGameID,
              manifest.systemID == identity.systemID.rawValue, manifest.slot == "battery",
              manifest.generation > 0, manifest.sizeBytes == actualSize,
              manifest.payloadSHA256.utf8.count == 64,
              manifest.payloadSHA256.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }),
              try sha256(of: payload) == manifest.payloadSHA256 else {
            throw BridgeError.invalidResponse("O save local não corresponde à ROM ou falhou na verificação de integridade.")
        }
        let revisionId = try revision(for: [NativeSaveFile(fileIndex: 0, name: payload.lastPathComponent,
                                                         size: actualSize, sha256: manifest.payloadSHA256)])
        return VerifiedLocalBatterySave(file: payload, sha256: manifest.payloadSHA256,
                                        size: actualSize, generation: manifest.generation, revisionId: revisionId)
    }

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
