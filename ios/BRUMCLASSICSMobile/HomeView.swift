import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: Int
    private var lastPlayed: Game? { store.snapshot.games.filter { !$0.lastPlayedAt.isEmpty || ($0.playtimeMinutes ?? 0) > 0 }.sorted { $0.lastPlayedAt > $1.lastPlayedAt }.first }
    private var favorites: [Game] { Array(store.snapshot.games.filter(\.favorite).prefix(8)) }
    private var wantToPlay: [Game] { Array(store.snapshot.games.filter(\.wantToPlay).prefix(8)) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                HStack { BrumLogo(); Spacer(); ConnectionDot(state: store.connection) }.padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text(greeting).font(.system(size: 20, weight: .bold)).foregroundStyle(BrumTheme.primary)
                    Text("Sua biblioteca,\nem qualquer lugar.").font(.system(size: 40, weight: .black)).foregroundStyle(BrumTheme.text)
                }
                if let active = store.companionGame, store.connection == .online {
                    Button { selection = 3 } label: { CompanionCard(game: active) }.buttonStyle(.plain)
                }
                if let lastPlayed { FeaturedGameCard(game: lastPlayed) }
                NavigationLink { BCardLibraryView() } label: { SettingsRow(icon: "rectangle.portrait.on.rectangle.portrait", title: "B-CARD", detail: "Seus jogos instalados · Jogos e CLASSICS") }
                NavigationLink { ClassicsEverywhereView() } label: { SettingsRow(icon: "gamecontroller", title: "CLASSICS in every everywhere", detail: "Adicionar ROMs e jogar no iPhone com RetroArch") }.accessibilityIdentifier("classics-everywhere-link")
                GameStrip(title: "FAVORITOS", games: favorites, empty: "Marque jogos como favoritos no launcher ou no perfil do jogo.")
                GameStrip(title: "QUERO JOGAR", games: wantToPlay, empty: "Sua lista Quero jogar aparecerá aqui.")
                JourneyCard(games: store.snapshot.games)
            }.padding(20)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .refreshable { await store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .openGame)) { if let game = $0.object as? Game { store.selectedGame = game } }
    }

    private var greeting: String { let hour = Calendar.current.component(.hour, from: Date()); return hour < 12 ? "Bom dia." : hour < 18 ? "Boa tarde." : "Boa noite." }
}

struct ConnectionDot: View {
    let state: AppStore.ConnectionState
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 7, height: 7); Text(label).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.muted) }
    }
    private var color: Color { state == .online ? BrumTheme.primary : .orange }
    private var label: String {
        switch state {
        case .online: return "CONECTADO"
        case .connecting: return "SINCRONIZANDO"
        case .offline: return "OFFLINE"
        case .error: return "ERRO DE SINCRONIZAÇÃO"
        }
    }
}

struct FeaturedGameCard: View {
    @EnvironmentObject private var store: AppStore
    let game: Game
    var body: some View {
        Button { store.selectedGame = game } label: {
            BrumCard {
                HStack(spacing: 18) {
                    GameCoverView(game: game, cornerRadius: 8).frame(width: 112, height: 158)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("ÚLTIMO JOGO JOGADO").font(.caption2.bold()).tracking(1.3).foregroundStyle(BrumTheme.primary)
                        Text(game.title).font(.title2.bold()).foregroundStyle(BrumTheme.text).lineLimit(3)
                        Text("\(game.platform) · \(game.playtimeLabel)").font(.caption).foregroundStyle(BrumTheme.muted)
                        ProgressView(value: Double(game.achievementProgress), total: 100).tint(BrumTheme.primary)
                        Text("\(game.achievementProgress)% DAS CONQUISTAS").font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
                    }
                }
            }
        }.buttonStyle(.plain)
    }
}

struct GameStrip: View {
    let title: String; let games: [Game]; let empty: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrumSectionLabel(text: title)
            if games.isEmpty { Text(empty).font(.subheadline).foregroundStyle(BrumTheme.muted).padding(.vertical, 20) }
            else { ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 14) { ForEach(games) { game in GameTile(game: game).frame(width: 145) } } } }
        }
    }
}

struct JourneyCard: View {
    let games: [Game]
    var body: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 16) {
                BrumSectionLabel(text: "MINHA JORNADA")
                HStack { metric("JOGOS", "\(games.count)"); metric("HORAS", String(format: "%.1f", games.compactMap(\.playtimeMinutes).reduce(0,+) / 60)); metric("CAMPANHAS", "\(games.filter(\.storyCompleted).count)") }
            }
        }
    }
    private func metric(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(value).font(.title2.bold()).foregroundStyle(BrumTheme.text); Text(label).font(.caption2.bold()).foregroundStyle(BrumTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading) }
}

struct CompanionCard: View {
    @EnvironmentObject private var store: AppStore
    let game: Game
    var body: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack { BrumSectionLabel(text: "BRUMCOMPANION"); Spacer(); Text("SESSÃO ATIVA").font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
                Text(game.title).font(.title3.bold()).foregroundStyle(BrumTheme.text)
                Text([game.notes.whereStopped, game.notes.objectives, game.notes.tips, game.notes.commands].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "").font(.subheadline).foregroundStyle(BrumTheme.muted).lineLimit(3)
                Text("ABRIR MINHAS ANOTAÇÕES").font(.caption.bold()).foregroundStyle(BrumTheme.primary)
            }
        }
    }
}
