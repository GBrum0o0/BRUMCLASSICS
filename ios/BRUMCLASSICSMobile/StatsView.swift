import SwiftUI
import Charts

struct StatsView: View {
    private struct PlatformCount: Identifiable { let name: String; let count: Int; var id: String { name } }
    @EnvironmentObject private var store: AppStore
    private var games: [Game] { store.snapshot.games }
    private var distribution: [PlatformCount] { Dictionary(grouping: games, by: { $0.platform }).map { PlatformCount(name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }.prefix(8).map { $0 } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(kicker: "MINHA JORNADA", title: "Estatísticas", subtitle: "Dados preservados no aparelho")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(value: "\(games.count)", label: "JOGOS")
                    StatCard(value: String(format: "%.1f", games.compactMap(\.playtimeMinutes).reduce(0,+) / 60), label: "HORAS")
                    StatCard(value: "\(games.filter(\.storyCompleted).count)", label: "CAMPANHAS")
                    StatCard(value: "\(games.flatMap(\.achievements).filter(\.unlocked).count)", label: "CONQUISTAS")
                }
                NavigationLink { AchievementsView() } label: { SettingsRow(icon: "trophy.fill", title: "CONQUISTAS", detail: "Ver progresso e jogos próximos de 100%") }
                BrumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        BrumSectionLabel(text: "DISTRIBUIÇÃO POR PLATAFORMA")
                        Chart(distribution) { item in BarMark(x: .value("Jogos", item.count), y: .value("Plataforma", item.name)).foregroundStyle(BrumTheme.primary) }.frame(height: 280).chartXAxis(.hidden)
                    }
                }
            }.padding(20)
        }.background(BrumTheme.background.ignoresSafeArea()).refreshable { await store.refresh() }
    }
}

struct StatCard: View {
    let value: String; let label: String
    var body: some View { BrumCard { VStack(alignment: .leading, spacing: 7) { Text(value).font(.system(size: 31, weight: .black)).foregroundStyle(BrumTheme.text); Text(label).font(.caption2.bold()).tracking(1.2).foregroundStyle(BrumTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading) } }
}
