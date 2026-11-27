import SwiftUI

struct GraphicsResolutionSettingsView: View {
    @State private var settings = GraphicsResolutionPack.shared.loadSettings()
    @State private var selectedSystem = "__global__"
    @State private var statusMessage = ""

    private var selectedEntry: GraphicsSystemCatalogEntry? {
        guard selectedSystem != "__global__" else { return nil }
        return GraphicsResolutionPack.catalog.first { $0.id == selectedSystem }
    }

    private var resolvedPreview: ResolvedGraphicsConfig {
        let previewSys = selectedSystem == "__global__" ? "psp" : selectedSystem
        return GraphicsResolutionPack.shared.resolve(systemID: previewSys, settings: settings)
    }

    private var activeProfileBinding: Binding<GraphicsProfile> {
        Binding(
            get: {
                if selectedSystem == "__global__" { return settings.profile }
                return settings.systems[selectedSystem]?.profile ?? settings.profile
            },
            set: { newValue in
                if selectedSystem == "__global__" {
                    settings.profile = newValue
                } else {
                    var ov = settings.systems[selectedSystem] ?? GraphicsSystemOverride()
                    ov.profile = newValue
                    settings.systems[selectedSystem] = ov
                }
                GraphicsResolutionPack.shared.saveSettings(settings)
            }
        )
    }

    private var activeMultiplierBinding: Binding<Int> {
        Binding(
            get: {
                if selectedSystem == "__global__" { return settings.globalMultiplier }
                return settings.systems[selectedSystem]?.multiplier ?? settings.globalMultiplier
            },
            set: { newValue in
                if selectedSystem == "__global__" {
                    settings.globalMultiplier = newValue
                } else {
                    var ov = settings.systems[selectedSystem] ?? GraphicsSystemOverride()
                    ov.multiplier = newValue
                    settings.systems[selectedSystem] = ov
                }
                GraphicsResolutionPack.shared.saveSettings(settings)
            }
        )
    }

    private var activeScaleModeBinding: Binding<GraphicsScaleMode> {
        Binding(
            get: {
                if selectedSystem == "__global__" { return settings.globalScaleMode }
                return settings.systems[selectedSystem]?.scaleMode ?? settings.globalScaleMode
            },
            set: { newValue in
                if selectedSystem == "__global__" {
                    settings.globalScaleMode = newValue
                } else {
                    var ov = settings.systems[selectedSystem] ?? GraphicsSystemOverride()
                    ov.scaleMode = newValue
                    settings.systems[selectedSystem] = ov
                }
                GraphicsResolutionPack.shared.saveSettings(settings)
            }
        )
    }

    private var activeFilterBinding: Binding<GraphicsVideoFilter> {
        Binding(
            get: {
                if selectedSystem == "__global__" { return settings.globalVideoFilter }
                return settings.systems[selectedSystem]?.videoFilter ?? settings.globalVideoFilter
            },
            set: { newValue in
                if selectedSystem == "__global__" {
                    settings.globalVideoFilter = newValue
                } else {
                    var ov = settings.systems[selectedSystem] ?? GraphicsSystemOverride()
                    ov.videoFilter = newValue
                    settings.systems[selectedSystem] = ov
                }
                GraphicsResolutionPack.shared.saveSettings(settings)
            }
        )
    }

    var body: some View {
        Form {
            Section("Escopo") {
                Picker("Sistema", selection: $selectedSystem) {
                    Text("Padrão global").tag("__global__")
                    ForEach(GraphicsResolutionPack.catalog) { item in
                        Text("\(item.label) (\(item.is3D ? "3D" : "2D"))").tag(item.id)
                    }
                }
                Picker("Perfil gráfico", selection: activeProfileBinding) {
                    Text("Automática (recomendada)").tag(GraphicsProfile.automatic)
                    Text("Original (nativa)").tag(GraphicsProfile.original)
                    Text("Melhorada").tag(GraphicsProfile.enhanced)
                    Text("Personalizada").tag(GraphicsProfile.custom)
                }
            }

            Section("Resolução e escala") {
                if selectedEntry == nil || selectedEntry?.is3D == true {
                    Picker("Resolução interna 3D", selection: activeMultiplierBinding) {
                        ForEach(1...(selectedEntry?.maxMultiplier ?? 4), id: \.self) { mult in
                            Text("\(mult)x nativa").tag(mult)
                        }
                    }
                } else {
                    Text("Sistemas 2D usam escalonamento inteiro de pixel art sem esticar nem simular resolução 3D.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }

                Picker("Proporção / Escala", selection: activeScaleModeBinding) {
                    Text("Original (preservar proporção)").tag(GraphicsScaleMode.original)
                    Text("Inteira (Pixel-Perfect 2D)").tag(GraphicsScaleMode.integer)
                    Text("Preencher tela").tag(GraphicsScaleMode.stretch)
                }

                Picker("Filtro gráfico", selection: activeFilterBinding) {
                    Text("Nenhum (nítido)").tag(GraphicsVideoFilter.none)
                    Text("Nitidez adaptativa (CAS)").tag(GraphicsVideoFilter.casSharpen)
                    Text("Sharp Bilinear (anti-tremor)").tag(GraphicsVideoFilter.sharpBilinear)
                    Text("Edge Upscale 2x (EPX 2D)").tag(GraphicsVideoFilter.edgeUpscale2x)
                    Text("CRT Scanlines").tag(GraphicsVideoFilter.crtScanlines)
                    Text("Grade LCD (portáteis)").tag(GraphicsVideoFilter.lcdGrid)
                    Text("Bilinear sutil").tag(GraphicsVideoFilter.bilinearSubtle)
                }
            }

            Section("Prévia aplicada") {
                let preview = resolvedPreview
                LabeledContent("Multiplicador interno", value: preview.is3D ? "\(preview.internalMultiplier)x" : "Nativo 2D")
                LabeledContent("Escala", value: preview.scaleMode.rawValue)
                LabeledContent("Filtro", value: preview.videoFilter.rawValue)
                LabeledContent("Tier detectado", value: preview.hardwareTier.rawValue)
                Button("Restaurar original", role: .destructive) {
                    settings = GraphicsResolutionPack.shared.resetSettings(systemID: selectedSystem == "__global__" ? nil : selectedSystem)
                    statusMessage = "Configurações gráficas restauradas."
                }
                if !statusMessage.isEmpty {
                    Text(statusMessage).font(.caption).foregroundStyle(BrumTheme.primary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrumTheme.background)
        .navigationTitle("Resolução e Filtros")
    }
}

struct ClassicDriveCloudSettingsView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    private let driveService = ClassicDriveCloudService.shared

    @State private var folderLink = ""
    @State private var oauthToken = ""
    @State private var checkpoint = ClassicDriveCheckpoint()
    @State private var busy = false
    @State private var feedback = ""
    @State private var freeSpaceLabel = "Calculando…"
    @State private var playingROM: ROMFolderGame? = nil

    var body: some View {
        Form {
            Section("Biblioteca em nuvem — Google Drive") {
                TextField("https://drive.google.com/drive/folders/...", text: $folderLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Token OAuth opcional (somente pastas privadas)", text: $oauthToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("Espaço livre no aparelho", value: freeSpaceLabel)
                Button(busy ? "Varrendo Google Drive…" : "Validar e atualizar catálogo") {
                    Task { await scan(refresh: true) }
                }
                .disabled(busy)

                if !checkpoint.completed && !checkpoint.pendingFolders.isEmpty {
                    Button("Continuar varredura (\(checkpoint.totalFoldersRead) lidas · \(checkpoint.pendingFolders.count) pendentes)") {
                        Task { await scan(refresh: false) }
                    }
                    .disabled(busy)
                }

                if !feedback.isEmpty {
                    Text(feedback).font(.caption).foregroundStyle(BrumTheme.muted)
                }
            }

            if !checkpoint.items.isEmpty {
                Section("Jogos encontrados (\(checkpoint.items.count))") {
                    ForEach(checkpoint.items) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text("\(item.systemHint.isEmpty ? "Clássico" : item.systemHint.uppercased()) · \(item.downloadedLocalPath != nil ? "Disponível offline" : "Na nuvem")")
                                    .font(.caption)
                                    .foregroundStyle(BrumTheme.muted)
                                if let err = item.downloadError, !err.isEmpty {
                                    Text(err).font(.caption2).foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            if item.downloadStatus == "downloading" {
                                Button("Cancelar", role: .cancel) {
                                    Task {
                                        await driveService.cancelDownload(fileID: item.id)
                                        await reloadState()
                                    }
                                }
                                .font(.caption.bold())
                            } else if item.downloadedLocalPath == nil {
                                Button("Baixar") {
                                    Task { await download(item: item) }
                                }
                                .font(.caption.bold())
                            } else {
                                Button("Jogar") {
                                    launchDownloaded(item: item)
                                }
                                .font(.caption.bold())
                                .buttonStyle(.borderedProminent)
                                .tint(BrumTheme.primary)
                                .foregroundStyle(.black)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrumTheme.background)
        .navigationTitle("Google Drive (Nuvem)")
        .task { await reloadState() }
        .fullScreenCover(item: $playingROM) { rom in
            IntegratedEmulatorView(rom: rom, returnsToPortrait: true)
        }
    }

    private func reloadState() async {
        let cp = await driveService.currentCheckpoint()
        let bytes = await driveService.availableFreeSpaceBytes()
        checkpoint = cp
        if folderLink.isEmpty && !cp.rootURL.isEmpty { folderLink = cp.rootURL }
        freeSpaceLabel = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func scan(refresh: Bool) async {
        busy = true
        defer { busy = false }
        let cleanToken = oauthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanToken.isEmpty {
            ClassicDriveKeychainStore.saveToken(cleanToken)
            oauthToken = ""
        }
        do {
            checkpoint = refresh
                ? try await driveService.startOrRefreshScan(folderURL: folderLink)
                : try await driveService.continueScan()
            feedback = checkpoint.completed
                ? "Varredura concluída: \(checkpoint.items.count) jogo(s) encontrados."
                : "Lote parcial salvo: \(checkpoint.totalFoldersRead) pastas lidas, \(checkpoint.pendingFolders.count) pendentes."
        } catch {
            feedback = error.localizedDescription
            checkpoint = await driveService.currentCheckpoint()
        }
        let bytes = await driveService.availableFreeSpaceBytes()
        freeSpaceLabel = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func download(item: ClassicDriveGameItem) async {
        do {
            let localURL = try await driveService.downloadGame(fileID: item.id)
            await pocket.refreshROMFolder()
            feedback = "\(item.title) salvo em \(localURL.lastPathComponent) para jogar offline."
        } catch {
            feedback = error.localizedDescription
        }
        await reloadState()
    }

    private func launchDownloaded(item: ClassicDriveGameItem) {
        guard let localPath = item.downloadedLocalPath, FileManager.default.fileExists(atPath: localPath) else {
            feedback = "Arquivo offline não encontrado; tente baixar novamente."
            return
        }
        let localURL = URL(fileURLWithPath: localPath).standardizedFileURL
        let filename = localURL.lastPathComponent
        if let existing = pocket.romFolderGames.first(where: { $0.filename.caseInsensitiveCompare(filename) == .orderedSame }) {
            playingROM = existing
            return
        }
        Task {
            await pocket.refreshROMFolder()
            if let reloaded = pocket.romFolderGames.first(where: { $0.filename.caseInsensitiveCompare(filename) == .orderedSame }) {
                playingROM = reloaded
            } else {
                feedback = "Não foi possível carregar este jogo no catálogo local."
            }
        }
    }
}
