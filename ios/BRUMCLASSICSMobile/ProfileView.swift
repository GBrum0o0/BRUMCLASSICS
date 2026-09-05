import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var scanner = false
    @State private var manualURL = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(kicker: "CONTA E DISPOSITIVO", title: "Perfil", subtitle: store.configuration?.deviceName ?? "iPhone não pareado")
                NavigationLink { MobileSettingsView() } label: { SettingsRow(icon: "gearshape", title: "CONFIGURAÇÕES DO APP", detail: "Como iniciar CLASSICS pelo B-CARD") }.accessibilityIdentifier("mobile-settings-link")
                BrumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { BrumSectionLabel(text: "CONEXÃO LOCAL SEGURA"); Spacer(); ConnectionDot(state: store.connection) }
                        if case .error(let detail) = store.connection { Text(detail).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                        if let warning = store.realtimeWarning { Text(warning).font(.caption).foregroundStyle(BrumTheme.muted) }
                        if let config = store.configuration {
                            Text("\(config.host):\(config.port)").font(.headline).foregroundStyle(BrumTheme.text)
                            Text("A biblioteca completa permanece disponível offline. Quando este computador reaparecer na rede local, somente as mudanças serão sincronizadas.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                            if store.pendingCount > 0 { Label("\(store.pendingCount) alterações aguardando envio", systemImage: "arrow.triangle.2.circlepath").font(.caption.bold()).foregroundStyle(.orange) }
                            Button("ATUALIZAR AGORA") { Task { await store.refresh() } }.buttonStyle(PrimaryButtonStyle())
                            Button("DESCONECTAR ESTE IPHONE", role: .destructive) { Task { await store.disconnect() } }.font(.caption.bold()).frame(maxWidth: .infinity).padding(.top, 6)
                        } else {
                            Text("No computador, abra Configurações → MÓVEL → Conectar novo celular e leia o QR Code.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                            Button("LER QR CODE") { scanner = true }.buttonStyle(PrimaryButtonStyle())
                            TextField("Ou cole o endereço brumclassics://pair…", text: $manualURL).textInputAutocapitalization(.never).autocorrectionDisabled().padding(12).background(BrumTheme.elevated).clipShape(RoundedRectangle(cornerRadius: 9))
                            Button("CONECTAR PELO ENDEREÇO") { if let url = URL(string: manualURL) { Task { await store.pair(from: url) } } }.font(.caption.bold()).foregroundStyle(BrumTheme.primary).disabled(manualURL.isEmpty)
                        }
                    }
                }
                NavigationLink { CompanionView() } label: { SettingsRow(icon: "note.text", title: "BRUMCOMPANION", detail: "Jogo ativo, anotações e desempenho") }
                NavigationLink { AchievementsView() } label: { SettingsRow(icon: "trophy.fill", title: "CONQUISTAS", detail: "Progresso dos jogos e CLASSICS") }
                NavigationLink { BCardLibraryView() } label: { SettingsRow(icon: "rectangle.portrait.on.rectangle.portrait", title: "B-CARD", detail: "Envie um jogo instalado ao computador") }
                NavigationLink { MomentsView() } label: { SettingsRow(icon: "photo.on.rectangle.angled", title: "BRUMMOMENTS", detail: "Galeria pessoal de capturas e locais") }
                PersonalUpdateCard()
                BrumCard { VStack(alignment: .leading, spacing: 10) { BrumSectionLabel(text: "PRIVACIDADE"); Text("O iPhone recebe apenas dados sanitizados da biblioteca. Senhas, tokens das lojas, executáveis, ROMs e caminhos privados não saem do computador.").font(.subheadline).foregroundStyle(BrumTheme.muted) } }
                Text("BRUMCLASSICS MÓVEL PARA iOS · \(store.installedVersion)").font(.caption2.bold()).tracking(1.2).foregroundStyle(BrumTheme.muted).frame(maxWidth: .infinity)
            }.padding(20)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .sheet(isPresented: $scanner) {
            ZStack(alignment: .topTrailing) {
                PairingScannerView { url in scanner = false; Task { await store.pair(from: url) } } onError: { store.message = $0 }
                Button { scanner = false } label: { Image(systemName: "xmark").font(.headline).padding(14).background(.black.opacity(0.6)).clipShape(Circle()) }.foregroundStyle(.white).padding()
            }.ignoresSafeArea()
        }
    }
}

struct MobileSettingsView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @AppStorage("bcard_classic_launch_mode") private var mode = "new"
    @State private var choosingROMFolder = false
    var body: some View {
        Form {
            Section("CLASSICS no iPhone") {
                LabeledContent("Pasta de ROMs", value: pocket.romFolderName)
                Button(pocket.romFolderConfigured ? "ALTERAR PASTA DE ROMS" : "SELECIONAR PASTA DO RETROARCH") { choosingROMFolder = true }
                    .accessibilityIdentifier("choose-rom-folder")
                Button("VERIFICAR PASTA AGORA") { Task { await pocket.refreshROMFolder() } }
                    .disabled(!pocket.romFolderConfigured)
                Text("Para tocar e jogar sem importar novamente, selecione uma pasta que pertença ao RetroArch em No Meu iPhone → RetroArch. Outras pastas podem ser lidas pelo BRUMCLASSICS, mas o iOS pode impedir que o RetroArch acesse o mesmo caminho. O app não copia nem apaga suas ROMs.").font(.caption).foregroundStyle(BrumTheme.muted)
                if !pocket.romFolderStatus.isEmpty { Text(pocket.romFolderStatus).font(.caption).foregroundStyle(BrumTheme.muted) }
                NavigationLink("RetroArch e RetroAchievements") { PocketSetupView() }
            }
            Section("B-CARD · CLASSICS") {
                Picker("Ao iniciar um clássico", selection: $mode) {
                    Text("Novo jogo").tag("new")
                    Text("Continuar no auto save").tag("continue-auto")
                    Text("Continuar no save manual").tag("continue-manual")
                }.pickerStyle(.inline).accessibilityIdentifier("classic-launch-mode")
                Text("Essa preferência vale para os CLASSICS enviados pelo B-CARD. Jogos de PC usam a inicialização normal. Se o save escolhido não existir, o launcher informará o problema; seus saves não são apagados.").font(.caption).foregroundStyle(BrumTheme.muted)
            }
        }.scrollContentBackground(.hidden).background(BrumTheme.background).navigationTitle("Configurações do app")
        .fileImporter(isPresented: $choosingROMFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder): Task { await pocket.configureROMFolder(folder) }
            case .failure(let error): pocket.message = error.localizedDescription
            }
        }
    }
}

private struct PersonalUpdateCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BrumSectionLabel(text: "ATUALIZAÇÃO PESSOAL")
                    Spacer()
                    status
                }

                switch store.personalUpdate {
                case .available(let manifest):
                    Text("Versão \(manifest.version) disponível").font(.headline).foregroundStyle(BrumTheme.text)
                    if !manifest.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(manifest.notes, id: \.self) { note in
                                Text("• \(note)").font(.caption).foregroundStyle(BrumTheme.muted)
                            }
                        }
                    }
                    Button("ABRIR BUILD PESSOAL") { openURL(manifest.buildURL) }.buttonStyle(PrimaryButtonStyle())
                    Text("Baixe no computador e instale sobre a versão anterior usando o mesmo método de sideload. O identificador do app permanece fixo para preservar seus dados.").font(.caption).foregroundStyle(BrumTheme.muted)
                case .failed:
                    Text("A consulta falhou, mas sua biblioteca offline e o restante do app continuam disponíveis.").font(.caption).foregroundStyle(BrumTheme.muted)
                default:
                    Text("O iPhone verifica silenciosamente se existe um novo build pessoal. Nenhuma versão é publicada na App Store.").font(.caption).foregroundStyle(BrumTheme.muted)
                }

                Button("VERIFICAR AGORA") { Task { await store.checkForPersonalUpdate(showCurrentMessage: true) } }
                    .font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    .disabled(store.personalUpdate == .checking)
            }
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
