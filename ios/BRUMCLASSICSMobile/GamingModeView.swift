import SwiftUI

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var introVisible = true
    @State private var selectedGame: Game?

    private var orderedGames: [Game] {
        store.snapshot.games.sorted {
            if $0.lastPlayedAt != $1.lastPlayedAt { return $0.lastPlayedAt > $1.lastPlayedAt }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    private var lastPlayed: Game? { orderedGames.first { !$0.lastPlayedAt.isEmpty || ($0.playtimeMinutes ?? 0) > 0 } ?? orderedGames.first }
    private var recentPocket: [PocketClassic] {
        pocket.games.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 25) {
                    HStack { BrumLogo(compact: true); Text("GAMING MODE").font(.caption.bold()).tracking(2).foregroundStyle(BrumTheme.primary); Spacer(); ConnectionDot(state: store.connection) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sua biblioteca inteira.").font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text("Só escolha e jogue.").font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.primary)
                    }
                    if let game = lastPlayed { continueCard(game) }
                    unifiedLibrary
                    routes
                    capabilityStatus
                }
                .padding(20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(BrumTheme.background.ignoresSafeArea())
            .refreshable { await store.refresh(); await pocket.refreshROMFolder() }

            if introVisible { GamingModeIntro().transition(.opacity.combined(with: .scale(scale: 1.06))) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            introVisible = true
            try? await Task.sleep(for: .milliseconds(1150))
            withAnimation(.easeOut(duration: 0.42)) { introVisible = false }
        }
        .fullScreenCover(item: $selectedGame) { GamingGameView(game: $0) }
    }

    private func continueCard(_ game: Game) -> some View {
        Button { selectedGame = game } label: {
            ZStack(alignment: .bottomLeading) {
                GameCoverView(game: game, cornerRadius: 16).frame(maxWidth: .infinity).frame(height: 250).clipped().opacity(0.58)
                LinearGradient(colors: [.clear, BrumTheme.deepBackground.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONTINUE DE ONDE PAROU").font(.caption2.bold()).tracking(1.5).foregroundStyle(BrumTheme.primary)
                    Text(game.title).font(.system(size: 27, weight: .black)).foregroundStyle(BrumTheme.text).lineLimit(2)
                    Text(continueDetail(game)).font(.caption).foregroundStyle(BrumTheme.text.opacity(0.78))
                    Text("CONTINUAR").font(.caption.bold()).tracking(1).foregroundStyle(.black).padding(.horizontal, 18).padding(.vertical, 11).background(BrumTheme.primary).clipShape(Capsule())
                }.padding(20)
            }
            .background(BrumTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(BrumTheme.line))
        }.buttonStyle(.plain)
    }

    private var unifiedLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { BrumSectionLabel(text: "ESCOLHA UM JOGO"); Spacer(); Text("PC + CLASSICS").font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
            if orderedGames.isEmpty && recentPocket.isEmpty {
                BrumCard { Text("Sincronize o launcher ou configure sua pasta de ROMs para montar a biblioteca do Gaming Mode.").font(.subheadline).foregroundStyle(BrumTheme.muted) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(orderedGames.prefix(18)) { game in
                            Button { selectedGame = game } label: { GamingGameTile(game: game) }.buttonStyle(.plain).frame(width: 145)
                        }
                        ForEach(recentPocket.filter { pocketGame in !orderedGames.contains { $0.id == pocketGame.launcherGameID } }.prefix(8)) { game in
                            NavigationLink { PocketGameView(id: game.id) } label: { GamingPocketTile(game: game) }.buttonStyle(.plain).frame(width: 145)
                        }
                    }
                }
            }
        }
    }

    private var routes: some View {
        VStack(alignment: .leading, spacing: 13) {
            BrumSectionLabel(text: "SEUS MODOS DE JOGAR")
            NavigationLink { ClassicsEverywhereView() } label: { GamingRouteRow(icon: "gamecontroller.fill", title: "JOGAR NESTE APARELHO", detail: "CLASSICS preparados para RetroArch", status: pocket.games.isEmpty ? "CONFIGURAR" : "PRONTO") }
            NavigationLink { BCardLibraryView() } label: { GamingRouteRow(icon: "desktopcomputer", title: "INICIAR NO COMPUTADOR", detail: "Envie o jogo pelo canal seguro do B-CARD", status: store.connection == .online ? "CONECTADO" : "OFFLINE") }
            NavigationLink { StatsView() } label: { GamingRouteRow(icon: "chart.bar.fill", title: "ESTATÍSTICAS", detail: "Tempo, plataformas e progresso", status: "ABRIR") }
        }.buttonStyle(.plain)
    }

    private var capabilityStatus: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { BrumSectionLabel(text: "STREAMING REMOTO"); Spacer(); Text("EM DESENVOLVIMENTO").font(.caption2.bold()).foregroundStyle(.orange) }
                Text("Hoje o Gaming Mode já consegue iniciar jogos no PC. A transmissão de vídeo, áudio e controles pela internet ainda não está disponível nesta versão.").font(.caption).foregroundStyle(BrumTheme.muted)
            }
        }
    }

    private func continueDetail(_ game: Game) -> String {
        if game.isClassic, pocket.retroArchGame(for: game) != nil { return "CLASSICS · pronto neste aparelho" }
        if game.installed { return store.connection == .online ? "PC em casa · pronto para iniciar" : "PC em casa · aguardando conexão" }
        return "Biblioteca preservada · instalação não confirmada"
    }
}

private struct GamingModeIntro: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            BrumTheme.deepBackground.ignoresSafeArea()
            VStack(spacing: 15) {
                BrumLogo(compact: true).scaleEffect(glow ? 1.08 : 0.92)
                Text("BRUMCLASSICS").font(.system(size: 27, weight: .black, design: .rounded)).tracking(2).foregroundStyle(BrumTheme.text)
                Text("GAMING MODE").font(.caption.bold()).tracking(3).foregroundStyle(BrumTheme.primary)
                VStack(spacing: 3) {
                    Text("SEU JOGO.").font(.title2.weight(.black)).foregroundStyle(BrumTheme.text)
                    Text("SEM ETAPAS.").font(.title2.weight(.black)).foregroundStyle(BrumTheme.primary)
                }.padding(.top, 24)
            }
        }.onAppear { withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) { glow = true } }
    }
}

private struct GamingGameTile: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameCoverView(game: game, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
            Text(game.isClassic ? "CLASSICS" : game.platform.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.primary)
            Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
            Text(game.isClassic ? "NO APARELHO" : game.installed ? "PC PRONTO" : "NA BIBLIOTECA").font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
        }
    }
}

private struct GamingPocketTile: View {
    let game: PocketClassic
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 11).fill(LinearGradient(colors: [BrumTheme.surface, BrumTheme.primary.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(0.72, contentMode: .fit).overlay(Image(systemName: "gamecontroller.fill").font(.largeTitle).foregroundStyle(BrumTheme.primary))
            Text("CLASSICS").font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.primary)
            Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
            Text("NO APARELHO").font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
        }
    }
}

private struct GamingRouteRow: View {
    let icon: String
    let title: String
    let detail: String
    let status: String
    var body: some View {
        BrumCard {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(BrumTheme.primary).frame(width: 34)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text); Text(detail).font(.caption).foregroundStyle(BrumTheme.muted) }
                Spacer()
                Text(status).font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
            }
        }
    }
}

private struct GamingGameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var launchState = ""
    @State private var launching = false

    private var localClassic: RetroArchLibraryGame? { game.isClassic ? pocket.retroArchGame(for: game) : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GameCoverView(game: game, cornerRadius: 16).aspectRatio(0.72, contentMode: .fit).frame(maxWidth: 330).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(routeLabel).font(.caption.bold()).tracking(1.5).foregroundStyle(BrumTheme.primary)
                        Text(game.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text(game.description).font(.body).foregroundStyle(BrumTheme.muted)
                    }
                    Button(action: play) { HStack { if launching { ProgressView().tint(.black) }; Text(playLabel) }.frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!canPlay || launching).opacity(canPlay ? 1 : 0.38)
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    BrumCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { BrumSectionLabel(text: "STREAMING REMOTO"); Spacer(); Text("EM DESENVOLVIMENTO").font(.caption2.bold()).foregroundStyle(.orange) }
                            Text("O jogo pode ser iniciado no computador, mas esta versão ainda não recebe vídeo e áudio nem envia controles pela internet.").font(.caption).foregroundStyle(BrumTheme.muted)
                        }
                    }
                }.padding(20)
            }.background(BrumTheme.background.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) } } }
        }
    }

    private var routeLabel: String { localClassic != nil ? "CLASSICS · NESTE APARELHO" : "PC · CANAL SEGURO" }
    private var playLabel: String {
        if localClassic != nil { return "JOGAR NESTE APARELHO" }
        if !game.installed { return "INSTALAÇÃO NÃO CONFIRMADA" }
        return store.connection == .online ? "INICIAR NO COMPUTADOR" : "COMPUTADOR OFFLINE"
    }
    private var canPlay: Bool { localClassic != nil || game.installed && store.connection == .online }

    private func play() {
        if let localClassic {
            Task { await pocket.launchRetroArch(localClassic, launcher: store) }
            return
        }
        launching = true
        launchState = "Conectando ao computador e validando a instalação…"
        Task {
            let error = await store.launchBCard(game)
            await MainActor.run {
                launching = false
                launchState = error.map { "Não foi possível iniciar: \($0)" } ?? "Jogo iniciado no computador."
            }
        }
    }
}
