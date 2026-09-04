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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bcard_classic_launch_mode") private var savedMode = "new"
    @State private var offset: CGFloat = 0
    @State private var sending = false
    @State private var floating = false
    @State private var sendError: String?
    var body: some View {
        GeometryReader { geometry in ZStack {
            BrumTheme.deepBackground.ignoresSafeArea()
            let width = min(geometry.size.width * 0.70, geometry.size.height * 0.45, 300)
            GameCoverView(game: game, cornerRadius: 14, artworkOnly: true)
                .frame(width: width, height: width / 0.72)
                .shadow(color: BrumTheme.primary.opacity(0.12), radius: 35, y: 18)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : floating ? 3 : -3), axis: (x: 0.3, y: 1, z: 0))
                .offset(y: offset + (reduceMotion ? 0 : floating ? -7 : 7))
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: floating)
                .accessibilityLabel("Capa do jogo. Arraste para cima para enviar ao computador.")
                .accessibilityIdentifier("bcard-floating-cover")
                .accessibilityAction(named: "Enviar ao computador") { send(height: geometry.size.height) }
                .gesture(DragGesture().onChanged { if !sending { offset = min(0, $0.translation.height) } }.onEnded { value in
                    guard !sending else { return }
                    if value.translation.height < -90 { send(height: geometry.size.height) }
                    else { withAnimation(.spring()) { offset = 0 } }
                })
            VStack {
                HStack {
                    Button { dismiss() } label: { Label("Voltar", systemImage: "chevron.left").font(.subheadline.bold()).padding(14).background(BrumTheme.surface).clipShape(Capsule()) }
                        .accessibilityIdentifier("bcard-back").foregroundStyle(BrumTheme.text)
                    Spacer()
                }
                Spacer()
                Text(sending ? "ENVIANDO…" : "DESLIZE PARA CIMA").font(.caption2.bold()).tracking(1.3).foregroundStyle(BrumTheme.muted)
            }.padding(20)
        } }
        .onAppear { floating = true }
        .alert("Não foi possível enviar", isPresented: Binding(get: { sendError != nil }, set: { if !$0 { sendError = nil } })) { Button("OK") { sendError = nil } } message: { Text(sendError ?? "") }
    }
    private func send(height: CGFloat) {
        guard !sending else { return }; sending = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.4)) { offset = -height }
        Task {
            let error = await store.launchBCard(game, mode: BCardLaunchMode.validated(savedMode, classic: game.isClassic))
            if let error { sendError = error; sending = false; withAnimation(.spring()) { offset = 0 } }
            else { dismiss() }
        }
    }
}
