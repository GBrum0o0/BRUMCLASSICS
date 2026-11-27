import GameController
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct QRControlTargetBox: Identifiable {
    let payload: MurbPairingPayload
    var id: String { "\(payload.host):\(payload.port):\(payload.token)" }
}

struct TopControlAndSettingsActions: View {
    @Environment(\.scenePhase) private var scenePhase
    let identifierPrefix: String
    @State private var controllers: [GCController] = []
    @State private var activePanel: Panel?
    @State private var showMurbRemote = false
    @State private var showQRScanner = false
    @State private var scannedRemoteTarget: MurbPairingPayload?
    @State private var qrScanError = ""

    private enum Panel: String, Identifiable {
        case settings, controllers
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 10) {
            icon("gamecontroller", label: controllers.isEmpty ? "Controles" : "Controles conectados",
                 highlighted: !controllers.isEmpty) { activePanel = .controllers }
                .accessibilityIdentifier("\(identifierPrefix)-controllers")
            icon("qrcode.viewfinder", label: "Ler QR Code do MyBrumControl") {
                qrScanError = ""
                showQRScanner = true
            }
                .accessibilityIdentifier("\(identifierPrefix)-qr-control")
            icon("gearshape", label: "Configurações") { activePanel = .settings }
                .accessibilityIdentifier("\(identifierPrefix)-settings")
        }
        .onAppear(perform: refreshControllers)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshControllers() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect).receive(on: RunLoop.main)) { _ in
            refreshControllers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect).receive(on: RunLoop.main)) { _ in
            refreshControllers()
        }
        .sheet(item: $activePanel) { panel in
            NavigationStack {
                switch panel {
                case .settings:
                    GamingSettingsPanel()
                case .controllers:
                    controllerList
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showMurbRemote) {
            MurbRemoteGamepadLauncherSheet()
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            ZStack(alignment: .topTrailing) {
                PairingScannerView(validator: { url in
                    MurbPairingPayload.parse(url) != nil
                }, onCode: { url in
                    showQRScanner = false
                    if var parsed = MurbPairingPayload.parse(url) {
                        parsed.isExternalControl = true
                        MyBrumControlStore().remember(parsed)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            scannedRemoteTarget = parsed
                        }
                    } else {
                        qrScanError = "QR Code recusado: utilize o QR murb:// gerado pelo PC de destino."
                    }
                }, onError: { detail in
                    qrScanError = detail
                })

                if !qrScanError.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text(qrScanError)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Button("Fechar") { showQRScanner = false }
                            .buttonStyle(.borderedProminent)
                            .tint(BrumTheme.primary)
                            .foregroundStyle(.black)
                    }
                    .padding(20)
                    .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }

                Button { showQRScanner = false } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .padding(14)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .foregroundStyle(.white)
                .padding()
                .accessibilityLabel("Fechar leitor de QR Code")
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: Binding(
            get: { scannedRemoteTarget.map { QRControlTargetBox(payload: $0) } },
            set: { scannedRemoteTarget = $0?.payload }
        )) { box in
            MurbRemoteGamepadView(target: box.payload)
        }
    }

    private func icon(_ name: String, label: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlighted ? BrumTheme.primary : BrumTheme.text)
                .frame(width: 44, height: 44)
                .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private var controllerList: some View {
        List {
            Section("Controles físicos no celular") {
                if controllers.isEmpty {
                    Text("Nenhum controle conectado.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("gaming-mode-no-controllers")
                }
                ForEach(Array(controllers.enumerated()), id: \.element) { index, controller in
                    HStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill").foregroundStyle(BrumTheme.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("P\(index + 1) · \(controller.vendorName ?? "Controle Bluetooth / USB")")
                                .font(.subheadline.weight(.semibold))
                            Text(controllerDetail(controller))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let battery = controller.battery {
                            Text("\(Int((battery.batteryLevel * 100).rounded()))%")
                                .font(.caption2.monospacedDigit()).foregroundStyle(BrumTheme.primary)
                        }
                    }
                }
                Text("Controles físicos conectados ao iPhone são encaminhados automaticamente aos jogos e ao controle para PC.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Controle virtual na tela") {
                HStack {
                    Label("Multitoque + Analógico", systemImage: "iphone.landscape")
                    Spacer()
                    GamingAvailabilityBadge(kind: .available)
                }
                Text("Inclui D-Pad em cruz, analógicos virtuais por console, botões táteis e segundas telas de DS/3DS com toque direto.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Gamepad para PC") {
                HStack {
                    Label("Controle + 2ª Tela na rede local", systemImage: "desktopcomputer")
                    Spacer()
                    GamingAvailabilityBadge(kind: .onComputer)
                }
                Button("Abrir Gamepad para PC") {
                    activePanel = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showMurbRemote = true
                    }
                }
                Text("Pareia via QR Code `murb://` ou reconexão direta na rede local quando um jogo estiver em execução no computador.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Controles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fechar") { activePanel = nil }
            }
        }
    }

    private func controllerDetail(_ controller: GCController) -> String {
        let profile = controller.extendedGamepad != nil ? "Controle completo" : "Controle básico"
        return "\(profile) · ponte ativa"
    }

    private func refreshControllers() {
        controllers = GCController.controllers().filter { !$0.isSnapshot }
    }
}

struct GamingHeader<Leading: View>: View {
    @EnvironmentObject private var store: AppStore
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(spacing: 12) {
            leading().foregroundStyle(BrumTheme.text)
            Spacer()
            ConnectionDot(state: store.connection)
            TopControlAndSettingsActions(identifierPrefix: "gaming-mode")
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
        .background(BrumTheme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(BrumTheme.line).frame(height: 1) }
    }
}

private struct GamingSettingsPanel: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("BrumVirtualControlHapticsEnabled") private var virtualHaptics = true
    @AppStorage("BrumAutoHidePadWithController") private var autoHidePadWithController = false
    @AppStorage("BrumDefaultScreenFillEnabled") private var defaultFillDisplay = false
    @AppStorage(PocketClassicsStore.autoSaveSyncKey) private var autoSaveSync = true
    @State private var username = ""
    @State private var key = ""
    @State private var feedback = ""
    @State private var savedAccount: String?
    @State private var choosingROMFolder = false

    var body: some View {
        Form {
            Section("Pasta de ROMs no celular") {
                Button(pocket.romFolderConfigured ? "Alterar pasta de ROMs" : "Selecionar pasta de ROMs") {
                    choosingROMFolder = true
                }
                .accessibilityIdentifier("gaming-mode-choose-rom-folder")
                Text(pocket.romFolderConfigured
                     ? "Pasta atual: \(pocket.romFolderName). Novas ROMs colocadas nela aparecem no Gaming Mode."
                     : "Nenhuma pasta selecionada — toque acima para escolher onde colocar suas ROMs.")
                    .font(.caption).foregroundStyle(.secondary)
                if pocket.romFolderConfigured {
                    Button("Verificar pasta agora") {
                        Task { await pocket.refreshROMFolder() }
                    }
                    .disabled(pocket.busy)
                }
                if !pocket.romFolderStatus.isEmpty { Text(pocket.romFolderStatus).font(.caption).foregroundStyle(.secondary) }
                if let message = pocket.message, !message.isEmpty { Text(message).font(.caption).foregroundStyle(.orange) }
            }
            Section("RetroAchievements") {
                Text(savedAccount.map { "Conta configurada · \($0)" } ?? "Nenhuma conta configurada")
                TextField("Usuário RetroAchievements", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("gaming-mode-ra-username")
                SecureField("Web API Key", text: $key)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("gaming-mode-ra-key")
                Link("Obter minha Web API Key", destination: URL(string: "https://retroachievements.org/settings")!)
                Button("Salvar conta") { save() }
                Text("A chave permite consultar as conquistas da sua conta.")
                    .font(.caption).foregroundStyle(.secondary)
                if !feedback.isEmpty { Text(feedback).font(.caption) }
            }
            Section("Controles e tela") {
                Toggle("Vibração tátil nos botões virtuais", isOn: $virtualHaptics)
                Toggle("Ocultar controles na tela com joystick conectado", isOn: $autoHidePadWithController)
                Toggle("Preencher tela por padrão ao iniciar jogo", isOn: $defaultFillDisplay)
            }
            Section("Launcher PC e sincronização") {
                LabeledContent("Launcher PC", value: store.connection == .online ? "Conectado (\(store.configuration?.host ?? "LAN"))" : "Offline (biblioteca em cache)")
                Toggle("Auto Save Sync com o PC (ao abrir/sair)", isOn: $autoSaveSync)
                Button("Atualizar horas e conquistas") {
                    Task { await pocket.sync(launcher: store, force: true) }
                }.disabled(pocket.busy)
                if !pocket.lastSaveSyncSummary.isEmpty {
                    Text(pocket.lastSaveSyncSummary).font(.caption).foregroundStyle(.secondary)
                }
                if !pocket.status.isEmpty { Text(pocket.status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Biblioteca em nuvem") {
                NavigationLink("Biblioteca em nuvem — Google Drive") {
                    ClassicDriveCloudSettingsView()
                }
                .accessibilityIdentifier("gaming-mode-drive-settings")
            }
        }
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        .onAppear {
            savedAccount = pocket.credentials?.username
            username = savedAccount ?? ""
        }
        .fileImporter(isPresented: $choosingROMFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder):
                Task { await pocket.configureROMFolder(folder) }
            case .failure(let error):
                pocket.message = error.localizedDescription
            }
        }
    }

    private func save() {
        do {
            try pocket.configure(username: username, key: key)
            savedAccount = pocket.credentials?.username
            key = ""
            feedback = "Conta salva neste iPhone."
            Task { await pocket.sync(launcher: store, force: true) }
        } catch { feedback = error.localizedDescription }
    }
}

struct GamingArtwork: View {
    @EnvironmentObject private var store: AppStore
    var game: Game? = nil
    var rom: ROMFolderGame? = nil
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
            }
        }
        .task(id: [game?.id, game?.artworkPath, rom?.id].compactMap { $0 }.joined(separator: "|")) {
            image = nil
            if let game, !game.artworkPath.isEmpty, let picture = await store.image(for: game) {
                if !Task.isCancelled { image = picture }
            } else if let rom {
                let picture = await ROMArtworkCache.shared.artwork(for: rom)
                if !Task.isCancelled { image = picture.flatMap { UIImage(contentsOfFile: $0.imageURL.path) } }
            }
        }
        .accessibilityHidden(true)
    }
}

struct GamingHero<Content: View>: View {
    let title: String
    let platform: String
    let artwork: GamingArtwork
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(platform).font(.caption.weight(.semibold)).foregroundStyle(BrumTheme.text.opacity(0.80))
            Text(title).font(.largeTitle.weight(.black)).foregroundStyle(BrumTheme.text)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
        .background {
            ZStack {
                BrumTheme.elevated
                artwork
                LinearGradient(colors: [BrumTheme.background, BrumTheme.background.opacity(0.84), .clear],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, BrumTheme.background.opacity(0.9)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct GamingMetrics: View {
    let time: String
    let timeLabel: String
    let earned: Int?
    let total: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            DetailMetric(label: timeLabel, value: time)
            if let total, total > 0, let earned {
                DetailMetric(label: "Conquistas", value: "\(earned) / \(total)")
                DetailMetric(label: "Progresso", value: "\(Int(GamingAchievements.fraction(earned: earned, total: total) * 100))%")
            }
        }.frame(maxWidth: 390, alignment: .leading)
    }
}

struct GamingAchievements: View {
    let title: String
    let items: [Game.Achievement]
    let earned: Int?
    let total: Int?
    let emptyMessage: String

    static func fraction(earned: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(min(total, max(0, earned))) / Double(total)
    }

    var body: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Conquistas").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                if let total, total > 0, let earned {
                    Text("\(earned) de \(total) desbloqueadas")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(BrumTheme.primary)
                    ProgressView(value: Self.fraction(earned: earned, total: total)).tint(BrumTheme.primary)
                        .accessibilityLabel("Progresso de conquistas")
                }
                if items.isEmpty {
                    Text(emptyMessage).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 166), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(items) { item in
                            HStack(spacing: 8) {
                                AchievementBadge(item: item).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                    Text(item.manual == true ? "Registro manual" : item.unlocked ? "Desbloqueada" : "Bloqueada")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GamingAvailabilityBadge: View {
    enum Kind: Equatable {
        case available
        case onComputer
        case inCloud
        case downloading
        case unavailable

        var title: String {
            switch self {
            case .available: return GamingModePresentation.localAvailabilityLabel
            case .onComputer: return GamingModePresentation.computerAvailabilityLabel
            case .inCloud: return "Na nuvem (Google Drive)"
            case .downloading: return GamingModePresentation.downloadingAvailabilityLabel
            case .unavailable: return GamingModePresentation.unavailableOnPhoneLabel
            }
        }

        var icon: String {
            switch self {
            case .available: return "checkmark.circle.fill"
            case .onComputer: return "desktopcomputer"
            case .inCloud: return "icloud.and.arrow.down"
            case .downloading: return "arrow.down.circle.fill"
            case .unavailable: return "exclamationmark.circle"
            }
        }

        var tint: Color {
            switch self {
            case .available: return BrumTheme.primary
            case .onComputer: return BrumTheme.muted
            case .inCloud: return .cyan
            case .downloading: return .orange
            case .unavailable: return .orange
            }
        }
    }

    let kind: Kind

    var body: some View {
        Label(kind.title, systemImage: kind.icon)
            .font(.caption2.bold())
            .foregroundStyle(kind.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(kind.tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(kind.tint.opacity(0.35), lineWidth: 1))
    }
}

struct ExecutionBadge: View {
    enum Kind: Equatable {
        case onPhone
        case externalApp
        case dependsOnPC
        case unavailable

        var title: String {
            switch self {
            case .onPhone: return "Executa no celular"
            case .externalApp: return "App externo"
            case .dependsOnPC: return "Depende do PC"
            case .unavailable: return "Indisponível aqui"
            }
        }

        var icon: String {
            switch self {
            case .onPhone: return "iphone"
            case .externalApp: return "arrow.up.forward.app"
            case .dependsOnPC: return "desktopcomputer"
            case .unavailable: return "exclamationmark.circle"
            }
        }

        var tint: Color {
            switch self {
            case .onPhone: return BrumTheme.primary
            case .externalApp: return BrumTheme.text
            case .dependsOnPC, .unavailable: return .orange
            }
        }
    }

    let kind: Kind

    var body: some View {
        Label(kind.title, systemImage: kind.icon)
            .font(.caption2.bold())
            .foregroundStyle(kind.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(kind.tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(kind.tint.opacity(0.35), lineWidth: 1))
    }
}

struct GamingInfoItem: Identifiable, Equatable {
    let label: String
    let value: String
    var id: String { label }
}

struct GamingInfoCard: View {
    let title: String
    let items: [GamingInfoItem]

    var body: some View {
        let nonEmpty = items.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !nonEmpty.isEmpty {
            BrumCard {
                VStack(alignment: .leading, spacing: 10) {
                    BrumSectionLabel(text: title)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], alignment: .leading, spacing: 10) {
                        ForEach(nonEmpty) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label.uppercased()).font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
                                Text(item.value).font(.subheadline.weight(.semibold)).foregroundStyle(BrumTheme.text)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}