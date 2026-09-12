import SwiftUI

enum AchievementGameSearch {
    static func matches(_ query: String, fields: [String]) -> Bool {
        let terms = normalized(query).split { $0.isWhitespace }
        guard !terms.isEmpty else { return true }
        let searchable = normalized(fields.joined(separator: " "))
        return terms.allSatisfy { searchable.contains($0) }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var closestFirst = true
    @State private var searchText = ""
    private var games: [Game] {
        store.snapshot.games.filter {
            $0.achievementsAvailable && ($0.achievementsTotal ?? 0) > 0 &&
                AchievementGameSearch.matches(searchText, fields: [$0.title, $0.platform, $0.store])
        }.sorted {
            if closestFirst && $0.achievementProgress != $1.achievementProgress { return $0.achievementProgress > $1.achievementProgress }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    private var pocketGames: [PocketClassic] {
        pocket.games.filter { game in
            guard let progress = game.progress else { return false }
            return AchievementGameSearch.matches(searchText, fields: [game.title, progress.title, game.filename])
        }.sorted {
            ($0.progress?.title ?? $0.title).localizedStandardCompare($1.progress?.title ?? $1.title) == .orderedAscending
        }
    }
    private var hasResults: Bool { !games.isEmpty || !pocketGames.isEmpty }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PageHeader(kicker: "PROGRESSO", title: "Conquistas", subtitle: "Modernos e CLASSICS em uma só jornada")
                Toggle("Mais perto de 100% primeiro", isOn: $closestFirst).font(.subheadline.bold()).tint(BrumTheme.primary).padding(.vertical, 8)
                if !pocketGames.isEmpty {
                    BrumSectionLabel(text: "CLASSICS NO IPHONE · RETROACHIEVEMENTS")
                    ForEach(pocketGames) { game in
                        if let progress = game.progress {
                            NavigationLink { PocketGameView(id: game.id) } label: { SettingsRow(icon: "trophy", title: progress.title, detail: "\(progress.unlocked)/\(progress.achievements.count) · \(progress.username)") }
                        }
                    }
                    Text("Progresso da conta, compartilhado entre dispositivos. Os cartões abaixo representam a biblioteca do PC; não somamos as duas listas.").font(.caption).foregroundStyle(BrumTheme.muted)
                }
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
                if !hasResults {
                    BrumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(BrumTheme.primary)
                            Text("Nenhum jogo encontrado").font(.headline).foregroundStyle(BrumTheme.text)
                            Text("Tente outro nome. A pesquisa mostra jogos com conquistas já disponíveis no iPhone ou sincronizadas pelo launcher.").font(.caption).foregroundStyle(BrumTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(20)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar jogo")
        .refreshable { await store.refresh(); await pocket.sync(launcher: store, force: true) }
    }
}
