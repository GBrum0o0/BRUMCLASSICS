import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SaveMigrationSummary: Equatable, Sendable {
    let fileCount: Int
    let totalBytes: Int64
}

struct SaveMigrationBackupFile: Codable, Equatable, Sendable {
    let relativePath: String
    let sizeBytes: Int64
    let sha256: String
}

struct SaveMigrationBackupManifest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let bundleIdentifier: String
    let appVersion: String
    let appBuild: Int
    let createdAtISO8601: String
    let files: [SaveMigrationBackupFile]
}

enum SaveMigrationBackupError: LocalizedError {
    case supportDirectoryUnavailable
    case nothingToBackup
    case invalidManifest(String)
    case unsafeRelativePath(String)
    case integrityCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case .supportDirectoryUnavailable:
            return "Diretório de armazenamento local indisponível neste aparelho."
        case .nothingToBackup:
            return "Nenhum save integrado ou vínculo local encontrado para exportar."
        case .invalidManifest(let detail):
            return "Backup inválido ou incompleto: \(detail)"
        case .unsafeRelativePath(let path):
            return "Caminho inseguro detectado no pacote de backup: \(path)"
        case .integrityCheckFailed(let file):
            return "Falha de verificação SHA-256 no arquivo \(file). Nenhum dado existente foi substituído."
        }
    }
}

enum SaveMigrationBackupService {
    static let manifestFileName = "manifest.json"
    private static let maxBackupFileBytes: Int64 = 128 * 1024 * 1024

    static func defaultSupportDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    static func summarize(supportDirectory: URL, fileManager: FileManager = .default) -> SaveMigrationSummary {
        let items = collectSourceFiles(in: supportDirectory, fileManager: fileManager)
        let bytes = items.reduce(Int64(0)) { partial, item in
            let values = try? item.url.resourceValues(forKeys: [.fileSizeKey])
            return partial + Int64(values?.fileSize ?? 0)
        }
        return SaveMigrationSummary(fileCount: items.count, totalBytes: bytes)
    }

    @discardableResult
    static func exportBackup(
        from supportDirectory: URL,
        to destinationParent: URL,
        appVersion: String,
        appBuild: Int,
        bundleIdentifier: String = PersonalUpdateService.expectedBundleIdentifier,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> (folder: URL, manifest: SaveMigrationBackupManifest) {
        let items = collectSourceFiles(in: supportDirectory, fileManager: fileManager)
        guard !items.isEmpty else { throw SaveMigrationBackupError.nothingToBackup }

        let folderName = "BRUMCLASSICS-Backup-\(timestampSlug(from: now))"
        let temporaryFolder = destinationParent.appendingPathComponent(".\(folderName)-\(UUID().uuidString)", isDirectory: true)
        let finalFolder = destinationParent.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)

        var manifestFiles: [SaveMigrationBackupFile] = []
        do {
            for item in items {
                guard isSafeRelativePath(item.relativePath) else {
                    throw SaveMigrationBackupError.unsafeRelativePath(item.relativePath)
                }
                let data = try Data(contentsOf: item.url)
                let hash = sha256Hex(of: data)
                let targetFile = temporaryFolder.appendingPathComponent("files", isDirectory: true)
                    .appendingPathComponent(item.relativePath)
                try fileManager.createDirectory(at: targetFile.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: targetFile, options: [.atomic])
                manifestFiles.append(SaveMigrationBackupFile(relativePath: item.relativePath, sizeBytes: Int64(data.count), sha256: hash))
            }

            let manifest = SaveMigrationBackupManifest(
                schemaVersion: SaveMigrationBackupManifest.currentSchemaVersion,
                bundleIdentifier: bundleIdentifier,
                appVersion: appVersion,
                appBuild: appBuild,
                createdAtISO8601: isoString(from: now),
                files: manifestFiles.sorted { $0.relativePath < $1.relativePath }
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: temporaryFolder.appendingPathComponent(manifestFileName), options: [.atomic])

            _ = try verifyBackup(at: temporaryFolder, fileManager: fileManager)

            let uniqueFinal = uniqueDestinationURL(for: finalFolder, fileManager: fileManager)
            try fileManager.moveItem(at: temporaryFolder, to: uniqueFinal)
            let verified = try verifyBackup(at: uniqueFinal, fileManager: fileManager)
            return (uniqueFinal, verified)
        } catch {
            try? fileManager.removeItem(at: temporaryFolder)
            throw error
        }
    }

    @discardableResult
    static func verifyBackup(at backupFolder: URL, fileManager: FileManager = .default) throws -> SaveMigrationBackupManifest {
        let manifestURL = backupFolder.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw SaveMigrationBackupError.invalidManifest("Arquivo manifest.json ausente.")
        }
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest: SaveMigrationBackupManifest
        do {
            manifest = try JSONDecoder().decode(SaveMigrationBackupManifest.self, from: manifestData)
        } catch {
            throw SaveMigrationBackupError.invalidManifest("Não foi possível ler os metadados do backup.")
        }
        guard manifest.schemaVersion == SaveMigrationBackupManifest.currentSchemaVersion else {
            throw SaveMigrationBackupError.invalidManifest("Versão de manifesto não suportada (\(manifest.schemaVersion)).")
        }
        guard !manifest.files.isEmpty else {
            throw SaveMigrationBackupError.invalidManifest("O backup não contém arquivos de save.")
        }

        let filesRoot = backupFolder.appendingPathComponent("files", isDirectory: true).standardizedFileURL
        for entry in manifest.files {
            guard isSafeRelativePath(entry.relativePath) else {
                throw SaveMigrationBackupError.unsafeRelativePath(entry.relativePath)
            }
            let fileURL = filesRoot.appendingPathComponent(entry.relativePath).standardizedFileURL
            guard fileURL.path.hasPrefix(filesRoot.path + "/") else {
                throw SaveMigrationBackupError.unsafeRelativePath(entry.relativePath)
            }
            let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
            if (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink {
                throw SaveMigrationBackupError.unsafeRelativePath(entry.relativePath)
            }
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  Int64(data.count) <= maxBackupFileBytes else {
                throw SaveMigrationBackupError.integrityCheckFailed(entry.relativePath)
            }
            guard Int64(data.count) == entry.sizeBytes,
                  sha256Hex(of: data) == entry.sha256.lowercased() else {
                throw SaveMigrationBackupError.integrityCheckFailed(entry.relativePath)
            }
        }
        return manifest
    }

    @discardableResult
    static func restoreBackup(
        from backupFolder: URL,
        into supportDirectory: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> (restoredCount: Int, snapshotFolder: URL?) {
        let manifest = try verifyBackup(at: backupFolder, fileManager: fileManager)
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        var snapshotFolder: URL?
        let existingItems = collectSourceFiles(in: supportDirectory, fileManager: fileManager)
        if !existingItems.isEmpty {
            let preRestoreDir = supportDirectory
                .appendingPathComponent("PreRestoreBackups", isDirectory: true)
                .appendingPathComponent("PreRestore-\(timestampSlug(from: now))", isDirectory: true)
            try fileManager.createDirectory(at: preRestoreDir, withIntermediateDirectories: true)
            for item in existingItems {
                let backupTarget = preRestoreDir.appendingPathComponent(item.relativePath)
                try fileManager.createDirectory(at: backupTarget.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: item.url, to: backupTarget)
            }
            snapshotFolder = preRestoreDir
        }

        let filesRoot = backupFolder.appendingPathComponent("files", isDirectory: true)
        for entry in manifest.files {
            let sourceFile = filesRoot.appendingPathComponent(entry.relativePath)
            let targetFile = supportDirectory.appendingPathComponent(entry.relativePath)
            let data = try Data(contentsOf: sourceFile)
            try fileManager.createDirectory(at: targetFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: targetFile, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
        return (manifest.files.count, snapshotFolder)
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("\\"),
              !path.contains("\\"),
              !path.contains("\0") else {
            return false
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return false }
        for part in parts where part.isEmpty || part == "." || part == ".." {
            return false
        }
        return path.hasPrefix("IntegratedEmulator/Saves/") || (path.hasPrefix("ClassicsEverywhere/") && path.hasSuffix(".json") && parts.count == 2)
    }

    private static func collectSourceFiles(in supportDirectory: URL, fileManager: FileManager) -> [(relativePath: String, url: URL)] {
        var collected: [(relativePath: String, url: URL)] = []

        let savesRoot = supportDirectory.appendingPathComponent("IntegratedEmulator/Saves", isDirectory: true)
        if let enumerator = fileManager.enumerator(
            at: savesRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values?.isSymbolicLink != true, values?.isRegularFile == true else { continue }
                let rel = "IntegratedEmulator/Saves/" + relativeSubpath(from: savesRoot, to: fileURL)
                if isSafeRelativePath(rel) {
                    collected.append((rel, fileURL))
                }
            }
        }

        let classicsRoot = supportDirectory.appendingPathComponent("ClassicsEverywhere", isDirectory: true)
        if let topEntries = try? fileManager.contentsOfDirectory(
            at: classicsRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            for fileURL in topEntries {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values?.isSymbolicLink != true,
                      values?.isRegularFile == true,
                      fileURL.pathExtension.lowercased() == "json" else { continue }
                let rel = "ClassicsEverywhere/" + fileURL.lastPathComponent
                if isSafeRelativePath(rel) {
                    collected.append((rel, fileURL))
                }
            }
        }

        return collected.sorted { $0.relativePath < $1.relativePath }
    }

    private static func relativeSubpath(from base: URL, to target: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        guard targetPath.hasPrefix(basePath + "/") else { return target.lastPathComponent }
        return String(targetPath.dropFirst(basePath.count + 1))
    }

    private static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func timestampSlug(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func uniqueDestinationURL(for preferred: URL, fileManager: FileManager) -> URL {
        guard fileManager.fileExists(atPath: preferred.path) else { return preferred }
        var suffix = 2
        while suffix < 100 {
            let candidate = preferred.deletingLastPathComponent()
                .appendingPathComponent("\(preferred.lastPathComponent)-\(suffix)", isDirectory: true)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
        return preferred.deletingLastPathComponent()
            .appendingPathComponent("\(preferred.lastPathComponent)-\(UUID().uuidString.prefix(6))", isDirectory: true)
    }
}

struct SaveMigrationBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var summary = SaveMigrationSummary(fileCount: 0, totalBytes: 0)
    @State private var pickingExportFolder = false
    @State private var pickingRestoreFolder = false
    @State private var pendingRestoreFolder: URL?
    @State private var confirmRestore = false
    @State private var feedback: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Saves locais detectados") {
                    LabeledContent("Arquivos de save/vínculo", value: "\(summary.fileCount)")
                    LabeledContent("Tamanho total", value: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))
                    Text("Inclui saves nativos em IntegratedEmulator/Saves (inclusive PSP/SAVEDATA) e vínculos JSON locais em ClassicsEverywhere. Tokens e senhas do Keychain não são exportados.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }

                Section("Exportar antes de trocar de instalador") {
                    Button("Exportar backup verificado") {
                        errorMessage = nil
                        feedback = nil
                        pickingExportFolder = true
                    }
                    .disabled(summary.fileCount == 0)
                    Text("Ao trocar de conta Apple ou reinstalar com outro Bundle ID no Brum iOS Bridge, o iOS cria um container separado. Exporte seus saves para Arquivos ou iCloud Drive antes de remover o aplicativo antigo.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }

                Section("Restaurar backup existente") {
                    Button("Restaurar backup verificado") {
                        errorMessage = nil
                        feedback = nil
                        pickingRestoreFolder = true
                    }
                    Text("O aplicativo valida o SHA-256 de todos os arquivos antes de gravar e guarda uma cópia preventiva dos saves atuais em PreRestoreBackups.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }

                if let feedback {
                    Section {
                        Text(feedback).font(.caption).foregroundStyle(BrumTheme.primary)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrumTheme.background)
            .navigationTitle("Backup para migração")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { reloadSummary() }
            .fileImporter(isPresented: $pickingExportFolder, allowedContentTypes: [.folder]) { result in
                handleExportSelection(result)
            }
            .fileImporter(isPresented: $pickingRestoreFolder, allowedContentTypes: [.folder]) { result in
                handleRestoreSelection(result)
            }
            .alert("Restaurar backup verificado?", isPresented: $confirmRestore) {
                Button("Restaurar", role: .destructive) { applyPendingRestore() }
                Button("Cancelar", role: .cancel) { pendingRestoreFolder = nil }
            } message: {
                Text("Os saves verificados do backup selecionado serão copiados para este aplicativo. Uma cópia de segurança dos saves atuais será mantida antes da substituição.")
            }
        }
    }

    private func reloadSummary() {
        guard let support = SaveMigrationBackupService.defaultSupportDirectory() else { return }
        summary = SaveMigrationBackupService.summarize(supportDirectory: support)
    }

    private func handleExportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let destination):
            let accessing = destination.startAccessingSecurityScopedResource()
            defer { if accessing { destination.stopAccessingSecurityScopedResource() } }
            do {
                guard let support = SaveMigrationBackupService.defaultSupportDirectory() else {
                    throw SaveMigrationBackupError.supportDirectoryUnavailable
                }
                let exported = try SaveMigrationBackupService.exportBackup(
                    from: support,
                    to: destination,
                    appVersion: store.installedVersion,
                    appBuild: store.installedBuild
                )
                feedback = "Backup verificado salvo em \(exported.folder.lastPathComponent) (\(exported.manifest.files.count) arquivo(s))."
                reloadSummary()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleRestoreSelection(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let folder):
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            do {
                _ = try SaveMigrationBackupService.verifyBackup(at: folder)
                pendingRestoreFolder = folder
                confirmRestore = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyPendingRestore() {
        guard let folder = pendingRestoreFolder else { return }
        pendingRestoreFolder = nil
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        do {
            guard let support = SaveMigrationBackupService.defaultSupportDirectory() else {
                throw SaveMigrationBackupError.supportDirectoryUnavailable
            }
            let result = try SaveMigrationBackupService.restoreBackup(from: folder, into: support)
            feedback = "Restaurados \(result.restoredCount) arquivo(s) verificados."
            reloadSummary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
