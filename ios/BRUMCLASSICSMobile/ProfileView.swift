import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var scanner = false
    @State private var manualURL = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(kicker: "CONTA E DISPOSITIVO", title: "Perfil", subtitle: store.configuration?.deviceName ?? "iPhone não pareado")
                BrumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { BrumSectionLabel(text: "CONEXÃO LOCAL SEGURA"); Spacer(); ConnectionDot(state: store.connection) }
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
                NavigationLink { CompanionControlView() } label: { SettingsRow(icon: "gamecontroller.fill", title: "BRUMCOMPANION", detail: "Controle e métricas em tempo real") }
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

struct CompanionControlView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let game = store.activeGame { CompanionCard(game: game) }
                BrumCard {
                    VStack(spacing: 18) {
                        HStack { control("chevron.left", "navigate", ["direction": "left"]); control("chevron.up", "navigate", ["direction": "up"]); control("chevron.right", "navigate", ["direction": "right"]) }
                        HStack { control("arrow.uturn.backward", "back"); control("checkmark", "activate"); control("line.3.horizontal", "tab") }
                    }
                }
                BrumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        BrumSectionLabel(text: "PESQUISA NO LIVING ROOM")
                        HStack { TextField("Nome do jogo", text: $search).padding(12).background(BrumTheme.elevated).clipShape(RoundedRectangle(cornerRadius: 9)); Button("ENVIAR") { Task { await store.send("search", payload: ["text": search]) } }.font(.caption.bold()).foregroundStyle(BrumTheme.primary) }
                        BrumSectionLabel(text: "VOLUME")
                        HStack { control("speaker.minus.fill", "set_volume", ["action": "down"]); control("speaker.slash.fill", "set_volume", ["action": "mute"]); control("speaker.plus.fill", "set_volume", ["action": "up"]) }
                    }
                }
                HStack { remoteButton("SAVE", "quick_save"); remoteButton("LOAD", "quick_load"); remoteButton("SAIR", "quit_game") }
                Button("CAPTURAR BRUMMOMENT") { Task { await store.captureMoment() } }.buttonStyle(PrimaryButtonStyle()).disabled(store.activeGame == nil)
                HStack { remoteButton("SUSPENDER", "sleep_pc"); remoteButton("DESLIGAR", "shutdown_pc") }
                Text("Suspender e desligar sempre exigem confirmação no computador.").font(.caption).foregroundStyle(BrumTheme.muted)
            }.padding(20)
        }.navigationTitle("BRUMCOMPANION").background(BrumTheme.background.ignoresSafeArea())
    }
    private func control(_ icon: String, _ command: String, _ payload: [String: Any] = [:]) -> some View { Button { Task { await store.send(command, payload: payload) } } label: { Image(systemName: icon).font(.title2).frame(maxWidth: .infinity).padding(.vertical, 17).background(BrumTheme.elevated).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).foregroundStyle(BrumTheme.text) }
    private func remoteButton(_ label: String, _ command: String) -> some View { Button(label) { Task { await store.send(command) } }.font(.caption.bold()).foregroundStyle(BrumTheme.text).frame(maxWidth: .infinity).padding(.vertical, 13).background(BrumTheme.surface).clipShape(RoundedRectangle(cornerRadius: 9)) }
}
