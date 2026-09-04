import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var scope = "Todos"
    @State private var installedOnly = false
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]

    private var games: [Game] {
        store.snapshot.games.filter { game in
            (query.isEmpty || game.title.localizedCaseInsensitiveContains(query)) &&
            (scope == "Todos" || scope == "Jogos" && !game.isClassic || scope == "Classics" && game.isClassic || scope == "Favoritos" && game.favorite) &&
            (!installedOnly || game.installed)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(kicker: "BIBLIOTECA", title: "Todos os jogos", subtitle: "\(games.count) itens disponíveis")
                TextField("Pesquisar por nome...", text: $query).textFieldStyle(.plain).padding(15).background(BrumTheme.surface).clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(BrumTheme.line))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(["Todos", "Jogos", "Classics", "Favoritos"], id: \.self) { item in FilterChip(title: item, selected: scope == item) { scope = item } }; FilterChip(title: "Instalados", selected: installedOnly) { installedOnly.toggle() } }
                }
                if games.isEmpty { VStack(spacing: 12) { Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(BrumTheme.muted); Text("Nenhum jogo encontrado").font(.headline).foregroundStyle(BrumTheme.text); Text("Altere os filtros ou sincronize novamente.").font(.subheadline).foregroundStyle(BrumTheme.muted) }.frame(maxWidth: .infinity).padding(.vertical, 70) }
                else { LazyVGrid(columns: columns, spacing: 22) { ForEach(games) { GameTile(game: $0) } } }
            }.padding(20)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .refreshable { await store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .openGame)) { if let game = $0.object as? Game { store.selectedGame = game } }
    }
}

struct FilterChip: View {
    let title: String; let selected: Bool; let action: () -> Void
    var body: some View { Button(action: action) { Text(title.uppercased()).font(.caption.bold()).padding(.horizontal, 16).padding(.vertical, 11).foregroundStyle(selected ? Color.black : BrumTheme.text).background(selected ? BrumTheme.primary : BrumTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(selected ? Color.clear : BrumTheme.line)) }.buttonStyle(.plain) }
}

struct PageHeader: View {
    let kicker: String; let title: String; let subtitle: String
    var body: some View { VStack(alignment: .leading, spacing: 7) { HStack { BrumLogo(); Spacer(); Text(kicker).font(.caption2.bold()).tracking(1.7).foregroundStyle(BrumTheme.muted) }; Text(title).font(.system(size: 36, weight: .black)).foregroundStyle(BrumTheme.text).padding(.top, 18); Text(subtitle.uppercased()).font(.caption.bold()).tracking(1).foregroundStyle(BrumTheme.muted) } }
}
