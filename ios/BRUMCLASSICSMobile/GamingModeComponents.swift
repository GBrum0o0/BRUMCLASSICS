import GameController
import SwiftUI
import UIKit

struct GamingHeader<Leading: View>: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var controllers: [GCController] = []
    @State private var activePanel: Panel?
    @ViewBuilder let leading: () -> Leading

    private enum Panel: String, Identifiable {
        case settings, controllers
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 12) {
            leading().foregroundStyle(BrumTheme.text)
            Spacer()
            ConnectionDot(state: store.connection)
            icon("gamecontroller", label: controllers.isEmpty ? "Controles" : "Controles conectados",
                 highlighted: !controllers.isEmpty) { activePanel = .controllers }
                .accessibilityIdentifier("gaming-mode-controllers")
            icon("gearshape", label: "Configurações") { activePanel = .settings }
                .accessibilityIdentifier("gaming-mode-settings")
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
        .background(BrumTheme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(BrumTheme.line).frame(height: 1) }
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
            if controllers.isEmpty {
                Text("Nenhum controle conectado.")
                    .accessibilityIdentifier("gaming-mode-no-controllers")
            }
            ForEach(controllers, id: \.self) { controller in
                Label(controller.vendorName ?? "Controle", systemImage: "gamecontroller.fill")
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

    private func refreshControllers() {
        controllers = GCController.controllers().filter { !$0.isSnapshot }
    }
}

private struct GamingSettingsPanel: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var key = ""
    @State private var feedback = ""
    @State private var savedAccount: String?

    var body: some View {
        Form {
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
            Button("Atualizar horas e conquistas") {
                Task { await pocket.sync(launcher: store, force: true) }
            }.disabled(pocket.busy)
            if !pocket.status.isEmpty { Text(pocket.status).font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        .onAppear {
            savedAccount = pocket.credentials?.username
            username = savedAccount ?? ""
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