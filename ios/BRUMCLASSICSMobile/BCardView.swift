import SwiftUI

struct BCardLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var segment = "Jogos"
    @State private var selected: Game?
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    private var games: [Game] { store.snapshot.games.filter { $0.installed && ($0.isClassic == (segment == "Classics")) }.sorted { $0.title < $1.title } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Envie um cartão ao computador para iniciar um jogo instalado.").foregroundStyle(BrumTheme.muted)
                Picker("Categoria", selection: $segment) { Text("JOGOS").tag("Jogos"); Text("CLASSICS").tag("Classics") }.pickerStyle(.segmented)
                LazyVGrid(columns: columns, spacing: 20) { ForEach(games) { game in Button { selected = game } label: { VStack(alignment: .leading) { GameCoverView(game: game).aspectRatio(0.72, contentMode: .fit); Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2) } }.buttonStyle(.plain) } }
            }.padding(20)
        }.navigationTitle("B-CARD").background(BrumTheme.background.ignoresSafeArea()).fullScreenCover(item: $selected) { BCardView(game: $0) }
    }
}

struct BCardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var mode = "new"
    @State private var offset: CGFloat = 0
    @State private var sending = false
    var body: some View {
        ZStack {
            BrumTheme.deepBackground.ignoresSafeArea()
            Circle().fill(BrumTheme.primary.opacity(0.08)).frame(width: 500).blur(radius: 45).offset(y: -100)
            VStack(spacing: 22) {
                HStack { BrumLogo(); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).padding(12).background(BrumTheme.surface).clipShape(Circle()) } }.padding(.horizontal, 20)
                Spacer()
                VStack(spacing: 15) {
                    GameCoverView(game: game, cornerRadius: 18).frame(width: 225, height: 315)
                    Text(game.title).font(.title2.bold()).foregroundStyle(BrumTheme.text).multilineTextAlignment(.center)
                    Text(game.isClassic ? "B-CARD · CLASSICS" : "B-CARD · JOGOS").font(.caption.bold()).tracking(1.4).foregroundStyle(BrumTheme.primary)
                }
                .padding(22).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(BrumTheme.primary.opacity(0.35)))
                .offset(y: offset)
                .gesture(DragGesture().onChanged { offset = min(0, $0.translation.height) }.onEnded { value in if value.translation.height < -110 { send() } else { withAnimation(.spring) { offset = 0 } } })
                if game.isClassic {
                    Picker("Modo", selection: $mode) { Text("NOVO").tag("new"); Text("AUTO SAVE").tag("continue-auto"); Text("SAVE MANUAL").tag("continue-manual") }.pickerStyle(.segmented).padding(.horizontal, 24)
                }
                VStack(spacing: 7) { Image(systemName: "chevron.up").foregroundStyle(BrumTheme.primary); Text(sending ? "ENVIANDO AO COMPUTADOR…" : "ARRASTE O CARTÃO PARA CIMA").font(.caption.bold()).tracking(1.2).foregroundStyle(BrumTheme.muted) }
                Spacer()
            }.padding(.vertical, 16)
        }
    }
    private func send() {
        guard !sending else { return }; sending = true
        withAnimation(.easeIn(duration: 0.35)) { offset = -UIScreen.main.bounds.height }
        Task { await store.launchBCard(game, mode: mode); try? await Task.sleep(for: .milliseconds(500)); dismiss() }
    }
}
