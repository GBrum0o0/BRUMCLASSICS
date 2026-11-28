import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton: Bool = false
    @State private var scanner = false
    @State private var manualURL = ""
    @State private var driveCatalogCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !showsCloseButton {
                    PageHeader(
                        kicker: "CONTA E DISPOSITIVO",
                        title: "Perfil",
                        subtitle: store.configuration?.deviceName ?? "iPhone não pareado",
                        showsProfileButton: false
                    )
                }
                NavigationLink { MobileDiagnosticsView() } label: {
                    SettingsRow(icon: "stethoscope", title: "DIAGNÓSTICO", detail: store.syncSummary.title)
                }
                if !store.noteConflicts.isEmpty {
                    NavigationLink { ConflictCenterView() } label: {
                        SettingsRow(icon: "arrow.triangle.branch", title: "CONFLITOS DE SINCRONIZAÇÃO", detail: "Compare o iPhone e o computador antes de escolher")
                    }
                }
                BrumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            BrumSectionLabel(text: "CONEXÃO LOCAL SEGURA")
                            Spacer()
                            ConnectionDot(state: store.syncIndicatorState)
                        }
                        if case .error(let detail) = store.connection {
                            Text(detail).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                        }
                        if let warning = store.realtimeWarning {
                            Text(warning).font(.caption).foregroundStyle(BrumTheme.muted)
                        }
                        if let config = store.configuration {
                            Text("\(config.host):\(config.port)").font(.headline).foregroundStyle(BrumTheme.text)
                            Text("A biblioteca completa permanece disponível offline. Quando este computador reaparecer na rede local, somente as mudanças serão sincronizadas.")
                                .font(.subheadline).foregroundStyle(BrumTheme.muted)
                            if store.pendingCount > 0 {
                                Label("\(store.pendingCount) alterações aguardando envio", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption.bold()).foregroundStyle(.orange)
                            }
                            Button("ATUALIZAR AGORA") { Task { await store.refresh() } }
                                .buttonStyle(PrimaryButtonStyle())
                            Button("DESCONECTAR ESTE IPHONE", role: .destructive) { Task { await store.disconnect() } }
                                .font(.caption.bold()).frame(maxWidth: .infinity).padding(.top, 6)
                        } else {
                            Text("No computador, abra Configurações → MÓVEL → Conectar novo celular e leia o QR Code.")
                                .font(.subheadline).foregroundStyle(BrumTheme.muted)
                            Button("LER QR CODE") { scanner = true }
                                .buttonStyle(PrimaryButtonStyle())
                            TextField("Ou cole o endereço brumclassics://pair…", text: $manualURL)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(12).background(BrumTheme.elevated).clipShape(RoundedRectangle(cornerRadius: 9))
                            Button("CONECTAR PELO ENDEREÇO") {
                                if let url = URL(string: manualURL) { Task { await store.pair(from: url) } }
                            }
                            .font(.caption.bold()).foregroundStyle(BrumTheme.primary).disabled(manualURL.isEmpty)
                        }
                    }
                }

                BrumSectionLabel(text: "CONTAS E BIBLIOTECAS VINCULADAS")
                NavigationLink {
                    RetroAchievementsAccountView()
                } label: {
                    SettingsRow(
                        icon: "trophy.circle.fill",
                        title: "RETROACHIEVEMENTS",
                        detail: pocket.credentials.map { "Conta conectada · \($0.username)" } ?? "Vincule sua conta e Web API Key"
                    )
                }
                .accessibilityIdentifier("profile-ra-link")

                NavigationLink {
                    ClassicDriveCloudSettingsView()
                } label: {
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "GOOGLE DRIVE · BIBLIOTECA",
                        detail: driveCatalogCount > 0 ? "\(driveCatalogCount) jogo(s) vinculados na nuvem" : "Vincular pasta do Google Drive e gerenciar downloads"
                    )
                }
                .accessibilityIdentifier("profile-drive-link")

                NavigationLink {
                    LinkedLibrariesSummaryView()
                } label: {
                    SettingsRow(
                        icon: "link.circle.fill",
                        title: "BIBLIOTECA E CONEXÕES DO PERFIL",
                        detail: "\(store.snapshot.games.count) no PC · \(pocket.romFolderGames.count) ROM(s) locais"
                    )
                }
                .accessibilityIdentifier("profile-library-links")

                BrumSectionLabel(text: "CONTEÚDO DO USUÁRIO")
                NavigationLink { CompanionView() } label: { SettingsRow(icon: "note.text", title: "BRUMCOMPANION", detail: "Jogo ativo, anotações e desempenho") }
                NavigationLink { AchievementsView() } label: { SettingsRow(icon: "trophy.fill", title: "CONQUISTAS", detail: "Progresso dos jogos e CLASSICS") }
                NavigationLink { BCardLibraryView() } label: { SettingsRow(icon: "rectangle.portrait.on.rectangle.portrait", title: "B-CARD", detail: "Envie um jogo instalado ao computador") }
                NavigationLink { MomentsView() } label: { SettingsRow(icon: "photo.on.rectangle.angled", title: "BRUMMOMENTS", detail: "Galeria pessoal de capturas e locais") }

                PersonalUpdateCard()
                BrumCard {
                    VStack(alignment: .leading, spacing: 10) {
                        BrumSectionLabel(text: "PRIVACIDADE")
                        Text("O iPhone recebe apenas dados sanitizados da biblioteca. Senhas, tokens das lojas, executáveis, ROMs e caminhos privados não saem do computador.")
                            .font(.subheadline).foregroundStyle(BrumTheme.muted)
                    }
                }
                Text("BRUMCLASSICS+ PARA iOS · \(store.installedVersion)")
                    .font(.caption2.bold()).tracking(1.2).foregroundStyle(BrumTheme.muted).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .navigationTitle(showsCloseButton ? "Perfil" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .task {
            let cp = await ClassicDriveCloudService.shared.currentCheckpoint()
            driveCatalogCount = cp.items.count
        }
        .sheet(isPresented: $scanner) {
            ZStack(alignment: .topTrailing) {
                PairingScannerView { url in scanner = false; Task { await store.pair(from: url) } } onError: { store.message = $0 }
                Button { scanner = false } label: {
                    Image(systemName: "xmark").font(.headline).padding(14).background(.black.opacity(0.6)).clipShape(Circle())
                }.foregroundStyle(.white).padding()
            }.ignoresSafeArea()
        }
    }
}

struct RetroAchievementsAccountView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @State private var username = ""
    @State private var key = ""
    @State private var runtimePassword = ""
    @State private var authenticating = false
    @State private var runtimeTokenActive = false
    @State private var savedAccount: String?
    @State private var feedback = ""

    var body: some View {
        Form {
            Section("Conta RetroAchievements") {
                Text(savedAccount.map { "Conta conectada · \($0)" } ?? "Nenhuma conta configurada")
                TextField("Usuário RetroAchievements", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("gaming-mode-ra-username")
                SecureField("Web API Key", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("gaming-mode-ra-key")
                Link("Obter minha Web API Key", destination: URL(string: "https://retroachievements.org/settings")!)
                Button("Salvar conta") { saveAPIKey() }
                Text("A chave permite consultar catálogo e conquistas sem exigir nova configuração ao reorganizar o aplicativo.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
            }

            Section("Sessão no BRUM Core (Softcore)") {
                SecureField("Senha RetroAchievements (não armazenada)", text: $runtimePassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button(authenticating ? "Autenticando…" : (runtimeTokenActive ? "Renovar token do runtime" : "Entrar para conquistas no jogo")) {
                        let pass = runtimePassword
                        runtimePassword = ""
                        authenticating = true
                        Task { @MainActor in
                            defer { authenticating = false }
                            do {
                                try await pocket.authenticateRuntime(username: username, password: pass)
                                runtimeTokenActive = true
                                feedback = "Token de sessão RetroAchievements salvo com segurança no Keychain."
                            } catch {
                                feedback = error.localizedDescription
                            }
                        }
                    }
                    .disabled(authenticating)
                    if runtimeTokenActive {
                        Button("Desconectar token", role: .destructive) {
                            try? pocket.clearRuntimeToken()
                            runtimeTokenActive = false
                            feedback = "Token do runtime removido do Keychain."
                        }
                    }
                }
                Text("Status runtime: \(runtimeTokenActive ? "token ativo (Softcore)" : "não autenticado").")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
            }

            Section("Sincronização da conta") {
                Button("Atualizar horas e conquistas") {
                    Task { await pocket.sync(launcher: store, force: true) }
                }
                .disabled(pocket.busy)
                if !pocket.status.isEmpty {
                    Text(pocket.status).font(.caption).foregroundStyle(BrumTheme.muted)
                }
                if !feedback.isEmpty {
                    Text(feedback).font(.caption).foregroundStyle(BrumTheme.primary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrumTheme.background)
        .navigationTitle("RetroAchievements")
        .onAppear {
            savedAccount = pocket.credentials?.username
            username = savedAccount ?? ""
            runtimeTokenActive = !(pocket.credentials?.runtimeToken ?? "").isEmpty
        }
    }

    private func saveAPIKey() {
        do {
            try pocket.configure(username: username, key: key)
            savedAccount = pocket.credentials?.username
            key = ""
            feedback = "Conta salva neste iPhone."
            Task { await pocket.sync(launcher: store, force: true) }
        } catch {
            feedback = error.localizedDescription
        }
    }
}

struct LinkedLibrariesSummaryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var choosingRuntime = false

    var body: some View {
        Form {
            Section("Vínculos do perfil") {
                LabeledContent("Jogos sincronizados do PC", value: "\(store.snapshot.games.count)")
                LabeledContent("ROMs detectadas no iPhone", value: "\(pocket.romFolderGames.count)")
                LabeledContent("Clássicos vinculados (IDs)", value: "\(pocket.games.filter { !$0.launcherGameID.isEmpty || !$0.retroAchievementID.isEmpty }.count)")
                if let config = store.configuration {
                    LabeledContent("PC pareado", value: "\(config.deviceName) (\(config.host))")
                } else {
                    LabeledContent("PC pareado", value: "Não pareado")
                }
            }

            Section("Sincronização e logs de tempo") {
                Button("Sincronizar biblioteca e horas com o PC") {
                    Task {
                        await store.refresh()
                        await pocket.sync(launcher: store, force: true)
                    }
                }
                .disabled(pocket.busy)
                Button(pocket.runtimeConfigured ? "Reautorizar pasta de logs RetroArch" : "Autorizar pasta de logs RetroArch") {
                    choosingRuntime = true
                }
                Text(pocket.runtimeStatus)
                    .font(.caption).foregroundStyle(BrumTheme.muted)
                if !pocket.lastSaveSyncSummary.isEmpty {
                    Text(pocket.lastSaveSyncSummary)
                        .font(.caption).foregroundStyle(BrumTheme.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrumTheme.background)
        .navigationTitle("Vínculos do perfil")
        .fileImporter(isPresented: $choosingRuntime, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder): Task { await pocket.configureRuntime(folder) }
            case .failure(let error): pocket.message = error.localizedDescription
            }
        }
    }
}

struct MobileSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton: Bool = false
    @AppStorage("bcard_classic_launch_mode") private var mode = "new"
    @AppStorage("BrumVirtualControlHapticsEnabled") private var virtualHaptics = true
    @AppStorage("BrumAutoHidePadWithController") private var autoHidePadWithController = false
    @AppStorage("BrumDefaultScreenFillEnabled") private var defaultFillDisplay = false
    @AppStorage(PocketClassicsStore.autoSaveSyncKey) private var autoSaveSync = true
    @State private var choosingROMFolder = false
    @AppStorage(OfflineContentPreferences.covers) private var offlineCovers = true
    @AppStorage(OfflineContentPreferences.activity) private var offlineActivity = true
    @AppStorage(OfflineContentPreferences.notifications) private var offlineNotifications = true

    var body: some View {
        Form {
            Section("Armazenamento e Pasta de ROMs") {
                LabeledContent("Pasta de ROMs", value: pocket.romFolderName)
                Button(pocket.romFolderConfigured ? "Alterar pasta de ROMs" : "Selecionar pasta de ROMs") {
                    choosingROMFolder = true
                }
                .accessibilityIdentifier("gaming-mode-choose-rom-folder")
                Button("Verificar pasta agora") { Task { await pocket.refreshROMFolder() } }
                    .disabled(!pocket.romFolderConfigured || pocket.busy)
                Text("Escolha Downloads, iCloud Drive ou outra pasta disponível no app Arquivos. Sistemas integrados abrem diretamente no BRUM Core, sem importação.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
                if !pocket.romFolderStatus.isEmpty {
                    Text(pocket.romFolderStatus).font(.caption).foregroundStyle(BrumTheme.muted)
                }
                if let message = pocket.message, !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.orange)
                }
                Toggle("Capas otimizadas offline", isOn: $offlineCovers)
                if BrumMobileFeatureFlags.showNotificationCenter {
                    Toggle("Atividade e sessões", isOn: $offlineActivity)
                    Toggle("Central de notificações", isOn: $offlineNotifications)
                }
            }

            Section("Vídeo e Resolução") {
                NavigationLink("Resolução e Filtros") { GraphicsResolutionSettingsView() }
                Toggle("Preencher tela por padrão ao iniciar jogo", isOn: $defaultFillDisplay)
            }

            Section("Controles e Interface") {
                Toggle("Vibração tátil nos botões virtuais", isOn: $virtualHaptics)
                Toggle("Ocultar controles na tela com joystick conectado", isOn: $autoHidePadWithController)
            }

            Section("Emulação, Áudio e Saves") {
                Toggle("Auto Save Sync com o PC (ao abrir/sair)", isOn: $autoSaveSync)
                NavigationLink("Compatibilidade RetroArch (tela e áudio)") {
                    PocketSetupView(showAccountSection: false)
                }
                if !pocket.lastSaveSyncSummary.isEmpty {
                    Text(pocket.lastSaveSyncSummary).font(.caption).foregroundStyle(BrumTheme.muted)
                }
            }

            Section("B-CARD · CLASSICS") {
                Picker("Ao iniciar um clássico", selection: $mode) {
                    Text("Novo jogo").tag("new")
                    Text("Continuar no auto save").tag("continue-auto")
                    Text("Continuar no save manual").tag("continue-manual")
                }.pickerStyle(.inline).accessibilityIdentifier("classic-launch-mode")
                Text("Essa preferência vale para os CLASSICS enviados pelo B-CARD. Se o save escolhido não existir, seus saves não são apagados.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrumTheme.background)
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .onChange(of: offlineCovers) { _ in Task { await store.applyOfflinePreferences() } }
        .onChange(of: offlineActivity) { _ in Task { await store.applyOfflinePreferences() } }
        .onChange(of: offlineNotifications) { _ in Task { await store.applyOfflinePreferences() } }
        .fileImporter(isPresented: $choosingROMFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder): Task { await pocket.configureROMFolder(folder) }
            case .failure(let error): pocket.message = error.localizedDescription
            }
        }
    }
}

struct MobileDiagnosticsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(kicker: "CONEXÃO E CACHE", title: "Diagnóstico", subtitle: "O que está funcionando e qual ação é necessária.", showsProfileButton: false)
                diagnostic("PAREAMENTO", store.isPaired ? "Identidade segura confirmada" : "QR Code ainda não lido", store.isPaired)
                diagnostic("COMPUTADOR", store.connection == .online ? "Disponível na rede local" : "Indisponível agora · reconexão automática ativa", store.connection == .online)
                diagnostic("BIBLIOTECA OFFLINE", "\(store.snapshot.games.count) jogos salvos no aparelho", !store.snapshot.games.isEmpty)
                diagnostic("FILA DE ENVIO", store.pendingCount == 0 ? "Nenhuma alteração pendente" : "\(store.pendingCount) alteração(ões) aguardando o computador", store.pendingCount == 0)
                diagnostic("ÚLTIMA SINCRONIZAÇÃO", store.lastSuccessfulSyncAt.map(relativeTime) ?? "Nenhuma sincronização concluída", store.lastSuccessfulSyncAt != nil)
                if let config = store.configuration { diagnostic("CERTIFICADO", "Impressão TLS verificada · \(String(config.fingerprint.prefix(12)))…", true) }
                Text(store.syncSummary.action).font(.headline).foregroundStyle(BrumTheme.primary)
                Button("TESTAR CONEXÃO AGORA") { Task { await store.refresh() } }.buttonStyle(PrimaryButtonStyle())
            }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 32).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(BrumTheme.background.ignoresSafeArea()).navigationTitle("Diagnóstico")
    }
    private func diagnostic(_ title: String, _ detail: String, _ ok: Bool) -> some View {
        BrumCard { HStack(spacing: 13) { Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(ok ? BrumTheme.primary : .orange); VStack(alignment: .leading) { Text(title).font(.caption.bold()).foregroundStyle(BrumTheme.text); Text(detail).font(.subheadline).foregroundStyle(BrumTheme.muted) }; Spacer() } }
    }
}

struct ConflictCenterView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(kicker: "SEM PERDER DADOS", title: "Resolver conflitos", subtitle: "O rascunho do celular fica preservado até você escolher.", showsProfileButton: false)
                ForEach(Array(store.noteConflicts), id: \.self) { gameID in
                    if let game = store.snapshot.games.first(where: { $0.id == gameID }) {
                        BrumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(game.title).font(.headline).foregroundStyle(BrumTheme.text)
                                Text("IPHONE · ALTERAÇÃO LOCAL").font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
                                notePreview(game.notes)
                                Text("COMPUTADOR · VERSÃO MAIS RECENTE").font(.caption2.bold()).foregroundStyle(.orange)
                                notePreview(store.noteConflictRemote[gameID] ?? .empty)
                                HStack {
                                    Button("MANTER IPHONE") { Task { _ = await store.saveNotes(game: game, notes: game.notes, force: true) } }.buttonStyle(.borderedProminent).tint(BrumTheme.primary).foregroundStyle(.black)
                                    Button("USAR COMPUTADOR", role: .destructive) { Task { _ = await store.useLauncherNotes(gameID: gameID) } }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(BrumTheme.background.ignoresSafeArea()).navigationTitle("Conflitos")
    }
    private func notePreview(_ notes: Game.Notes) -> some View {
        Text([notes.whereStopped, notes.objectives, notes.tips, notes.commands].filter { !$0.isEmpty }.joined(separator: "\n").isEmpty ? "Sem texto" : [notes.whereStopped, notes.objectives, notes.tips, notes.commands].filter { !$0.isEmpty }.joined(separator: "\n"))
            .font(.caption).foregroundStyle(BrumTheme.muted).lineLimit(6)
    }
}

private struct PersonalUpdateCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var showMigrationBackup = false

    var body: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BrumSectionLabel(text: "ATUALIZAÇÃO NO IPHONE")
                    Spacer()
                    status
                }

                Text("Versão instalada: v\(store.installedVersion) (build \(store.installedBuild))")
                    .font(.caption)
                    .foregroundStyle(BrumTheme.muted)

                switch store.personalUpdate {
                case .available(let manifest):
                    Text("Versão \(manifest.version) disponível (build \(manifest.build) · iOS \(manifest.minimumIOS)+)")
                        .font(.headline)
                        .foregroundStyle(BrumTheme.text)
                    if let sizeBytes = manifest.sizeBytes, sizeBytes > 0 {
                        Text("Tamanho do pacote: \(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(BrumTheme.muted)
                    }
                    if !manifest.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(manifest.notes, id: \.self) { note in
                                Text("• \(note)").font(.caption).foregroundStyle(BrumTheme.muted)
                            }
                        }
                    }

                    Text("Atualize conectando o iPhone ao PC e usando o Brum iOS Bridge no BRUMCLASSICS Desktop.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)

                    Button("Abrir release no GitHub") { openURL(manifest.buildURL) }
                        .buttonStyle(PrimaryButtonStyle())
                case .failed:
                    Text("A consulta falhou, mas sua biblioteca offline e o restante do app continuam disponíveis.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                default:
                    Text("Consulta a versão oficial do BRUMCLASSICS+ iOS. Instale e renove a assinatura de 7 dias pelo Brum iOS Bridge no PC.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }

                Button("Verificar atualização") {
                    Task { await store.checkForPersonalUpdate(showCurrentMessage: true) }
                }
                .font(.caption.bold())
                .foregroundStyle(BrumTheme.primary)
                .disabled(store.personalUpdate == .checking)
                .accessibilityIdentifier("check-update-button")

                Button("Backup e restauração de saves") {
                    showMigrationBackup = true
                }
                .font(.caption.bold())
                .foregroundStyle(BrumTheme.primary)
            }
        }
        .sheet(isPresented: $showMigrationBackup) {
            SaveMigrationBackupSheet()
        }
    }

    @ViewBuilder private var status: some View {
        switch store.personalUpdate {
        case .checking:
            ProgressView().controlSize(.small).tint(BrumTheme.primary)
        case .available:
            Text("NOVA").font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
        case .current:
            Label("ATUAL", systemImage: "checkmark.circle.fill").font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
        case .failed:
            Image(systemName: "wifi.slash").font(.caption).foregroundStyle(BrumTheme.muted)
        case .idle:
            EmptyView()
        }
    }
}

struct SettingsRow: View {
    let icon: String; let title: String; let detail: String
    var body: some View { BrumCard { HStack(spacing: 14) { Image(systemName: icon).font(.title2).foregroundStyle(BrumTheme.primary).frame(width: 34); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(BrumTheme.text); Text(detail).font(.caption).foregroundStyle(BrumTheme.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(BrumTheme.muted) } } }
}
