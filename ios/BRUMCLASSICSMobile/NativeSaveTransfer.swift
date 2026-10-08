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

struct NativeSaveUploadReceipt: Decodable, Sendable {
    let requestId: String
    let status: String
    let sha256: String
    let size: Int
}

private struct NativeSaveProfileBinding: Codable {
    let canonicalGameID: String
    let profileID: String
    let launcherFingerprint: String
}

private struct NativeSaveInstallJournal: Codable {
    let id: String
    let canonicalGameID: String
    let previousExisted: Bool
    let incomingSHA256: String
    let incomingSize: Int
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
    private static func batteryPaths(for identity: CanonicalGameIdentity) throws -> (payload: URL, metadata: URL, journal: URL) {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BridgeError.invalidResponse("Armazenamento local indisponível.")
        }
        let directory = support.appendingPathComponent("IntegratedEmulator", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
            .appendingPathComponent(identity.systemID.rawValue, isDirectory: true)
        let stem = identity.contentSHA256
        return (directory.appendingPathComponent("\(stem).srm"),
                directory.appendingPathComponent("\(stem).save.json"),
                directory.appendingPathComponent("\(stem).brum-native-sync.json"))
    }

    private static func historyDirectory(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BridgeError.invalidResponse("Journal de save inválido.")
        }
        return support.appendingPathComponent("NativeSaveTransfers", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true).appendingPathComponent(id, isDirectory: true)
    }

    static func recoverPendingInstall(for identity: CanonicalGameIdentity) throws {
        let manager = FileManager.default
        let paths = try batteryPaths(for: identity)
        guard manager.fileExists(atPath: paths.journal.path) else { return }
        let journal = try JSONDecoder().decode(NativeSaveInstallJournal.self, from: Data(contentsOf: paths.journal))
        guard journal.canonicalGameID == identity.canonicalGameID,
              journal.incomingSize > 0, journal.incomingSize <= 2_147_483_648,
              journal.incomingSHA256.utf8.count == 64 else {
            throw BridgeError.invalidResponse("Journal de save incompatível. Nenhum arquivo foi alterado.")
        }
        let history = try historyDirectory(journal.id)
        let payloadValid = (try? paths.payload.resourceValues(forKeys: [.fileSizeKey]).fileSize) == journal.incomingSize &&
            (try? sha256(of: paths.payload)) == journal.incomingSHA256
        let metadataValid: Bool
        if let data = try? Data(contentsOf: paths.metadata),
           let manifest = try? JSONDecoder().decode(LocalBatteryManifest.self, from: data) {
            metadataValid = manifest.canonicalGameID == identity.canonicalGameID &&
                manifest.payloadSHA256 == journal.incomingSHA256 && manifest.sizeBytes == journal.incomingSize
        } else { metadataValid = false }
        if payloadValid && metadataValid {
            try manager.removeItem(at: paths.journal)
            return
        }
        let previousPayload = history.appendingPathComponent("previous.srm")
        let previousMetadata = history.appendingPathComponent("previous.save.json")
        if journal.previousExisted {
            guard manager.fileExists(atPath: previousPayload.path), manager.fileExists(atPath: previousMetadata.path) else {
                throw BridgeError.invalidResponse("Backup anterior ausente; o save foi preservado para recuperação manual.")
            }
            let previousManifest = try JSONDecoder().decode(LocalBatteryManifest.self,
                from: Data(contentsOf: previousMetadata))
            guard previousManifest.canonicalGameID == identity.canonicalGameID,
                  previousManifest.systemID == identity.systemID.rawValue,
                  previousManifest.sizeBytes == (try previousPayload.resourceValues(forKeys: [.fileSizeKey]).fileSize),
                  previousManifest.payloadSHA256 == (try sha256(of: previousPayload)) else {
                throw BridgeError.invalidResponse("Backup anterior não corresponde à ROM; recuperação automática suspensa.")
            }
            let tempPayload = paths.payload.appendingPathExtension("recovery")
            let tempMetadata = paths.metadata.appendingPathExtension("recovery")
            for file in [tempPayload, tempMetadata] where manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
            try manager.copyItem(at: previousPayload, to: tempPayload)
            try manager.copyItem(at: previousMetadata, to: tempMetadata)
            for file in [paths.payload, paths.metadata] where manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
            try manager.moveItem(at: tempPayload, to: paths.payload)
            try manager.moveItem(at: tempMetadata, to: paths.metadata)
        } else {
            for file in [paths.payload, paths.metadata] where manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
        }
        try manager.removeItem(at: paths.journal)
    }

    static func installStagedBatterySave(_ staged: URL, identity: CanonicalGameIdentity,
                                         candidate: NativeSaveCandidate, allowReplace: Bool) throws -> Bool {
        guard candidate.isValid(for: identity.canonicalGameID), candidate.files.count == 1,
              let file = candidate.files.first, file.name.lowercased().hasSuffix(".srm"),
              file.size > 0, try sha256(of: staged) == file.sha256,
              (try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize) == file.size else {
            throw BridgeError.invalidResponse("O save baixado não corresponde à ROM ou falhou na verificação.")
        }
        try recoverPendingInstall(for: identity)
        let manager = FileManager.default
        let paths = try batteryPaths(for: identity)
        let local = try inspectLocalBatterySave(for: identity)
        if local?.revisionId == candidate.revisionId { return false }
        if local != nil && !allowReplace {
            throw BridgeError.invalidResponse("Há progresso diferente no iPhone. Confirme a substituição antes de aplicar o save do PC.")
        }
        let id = UUID().uuidString.lowercased()
        let history = try historyDirectory(id)
        try manager.createDirectory(at: paths.payload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.createDirectory(at: history, withIntermediateDirectories: true)
        if local != nil {
            try manager.copyItem(at: paths.payload, to: history.appendingPathComponent("previous.srm"))
            try manager.copyItem(at: paths.metadata, to: history.appendingPathComponent("previous.save.json"))
        }
        let tempPayload = paths.payload.appendingPathExtension("\(id).tmp")
        let tempMetadata = paths.metadata.appendingPathExtension("\(id).tmp")
        try manager.copyItem(at: staged, to: tempPayload)
        let manifest: [String: Any] = ["schemaVersion": 1, "canonicalGameID": identity.canonicalGameID,
            "systemID": identity.systemID.rawValue, "coreID": "brum-core-pc-import", "slot": "battery",
            "generation": (local?.generation ?? 0) + 1, "payloadSHA256": file.sha256,
            "sizeBytes": file.size, "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "deviceID": "ios-local", "formatVersion": 1]
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
            .write(to: tempMetadata, options: [.atomic, .completeFileProtectionUnlessOpen])
        let journal = NativeSaveInstallJournal(id: id, canonicalGameID: identity.canonicalGameID,
                                               previousExisted: local != nil, incomingSHA256: file.sha256,
                                               incomingSize: file.size)
        try JSONEncoder().encode(journal).write(to: paths.journal, options: [.atomic, .completeFileProtectionUnlessOpen])
        do {
            for file in [paths.payload, paths.metadata] where manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
            try manager.moveItem(at: tempPayload, to: paths.payload)
            try manager.moveItem(at: tempMetadata, to: paths.metadata)
            guard try inspectLocalBatterySave(for: identity, recoverPending: false)?.revisionId == candidate.revisionId else {
                throw BridgeError.invalidResponse("O save aplicado falhou na verificação; a versão anterior será recuperada.")
            }
            try manager.removeItem(at: paths.journal)
            return true
        } catch {
            try recoverPendingInstall(for: identity)
            throw error
        }
    }
    private static func bindingFile(for identity: CanonicalGameIdentity) throws -> URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BridgeError.invalidResponse("Armazenamento local indisponível.")
        }
        return support.appendingPathComponent("NativeSaveTransfers", isDirectory: true)
            .appendingPathComponent("Bindings", isDirectory: true)
            .appendingPathComponent("\(identity.systemID.rawValue)-\(identity.contentSHA256).json")
    }

    static func checkProfileBinding(for identity: CanonicalGameIdentity, profileID: String,
                                    launcherFingerprint: String) throws {
        guard !profileID.isEmpty, profileID.utf8.count <= 100,
              launcherFingerprint.filter(\.isHexDigit).count == 64 else {
            throw BridgeError.invalidResponse("Perfil ou identidade do launcher inválidos.")
        }
        let file = try bindingFile(for: identity)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let binding = try JSONDecoder().decode(NativeSaveProfileBinding.self, from: Data(contentsOf: file))
        guard binding.canonicalGameID == identity.canonicalGameID,
              binding.profileID == profileID,
              binding.launcherFingerprint.uppercased() == launcherFingerprint.uppercased() else {
            throw BridgeError.invalidResponse("Este save do iPhone já está vinculado a outro perfil ou computador. Nenhum arquivo foi alterado.")
        }
    }

    static func bindProfile(for identity: CanonicalGameIdentity, profileID: String,
                            launcherFingerprint: String) throws {
        try checkProfileBinding(for: identity, profileID: profileID, launcherFingerprint: launcherFingerprint)
        let file = try bindingFile(for: identity)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let binding = NativeSaveProfileBinding(canonicalGameID: identity.canonicalGameID,
                                               profileID: profileID, launcherFingerprint: launcherFingerprint.uppercased())
        try JSONEncoder().encode(binding).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
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

    static func inspectLocalBatterySave(for identity: CanonicalGameIdentity, savesRoot: URL? = nil,
                                        recoverPending: Bool = true) throws -> VerifiedLocalBatterySave? {
        if recoverPending && savesRoot == nil { try recoverPendingInstall(for: identity) }
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
