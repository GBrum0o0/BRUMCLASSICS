import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var closestFirst = true
    private var games: [Game] {
        store.snapshot.games.filter { $0.achievementsAvailable && ($0.achievementsTotal ?? 0) > 0 }.sorted {
            if closestFirst && $0.achievementProgress != $1.achievementProgress { return $0.achievementProgress > $1.achievementProgress }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PageHeader(kicker: "PROGRESSO", title: "Conquistas", subtitle: "Modernos e CLASSICS em uma só jornada")
                Toggle("Mais perto de 100% primeiro", isOn: $closestFirst).font(.subheadline.bold()).tint(BrumTheme.primary).padding(.vertical, 8)
                ForEach(games) { game in
                    Button { store.selectedGame = game } label: {
                        BrumCard {
                            HStack(spacing: 14) {
                                GameCoverView(game: game, cornerRadius: 7).frame(width: 70, height: 98)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(game.title).font(.headline).foregroundStyle(BrumTheme.text).lineLimit(2)
                                    Text("\(game.achievementsCollected ?? 0)/\(game.achievementsTotal ?? 0) DESBLOQUEADAS").font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
                                    ProgressView(value: Double(game.achievementProgress), total: 100).tint(BrumTheme.primary)
                                    Text("\(game.achievementProgress)%").font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                                }
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }.background(BrumTheme.background.ignoresSafeArea()).refreshable { await store.refresh() }
    }
}
