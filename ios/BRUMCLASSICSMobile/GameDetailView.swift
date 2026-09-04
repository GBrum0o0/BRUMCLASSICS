import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let initialGame: Game
    var game: Game { store.snapshot.games.first { $0.id == initialGame.id } ?? initialGame }
    init(game: Game) { initialGame = game }
    @State private var editNotes = false
    @State private var showBCard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GameCoverView(game: game, cornerRadius: 16).aspectRatio(0.72, contentMode: .fit).frame(maxWidth: 310).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) { Text(game.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text); Text("\(game.platform.uppercased()) · \(game.genre.uppercased())").font(.caption.bold()).tracking(1).foregroundStyle(BrumTheme.primary); Text(game.description).font(.body).foregroundStyle(BrumTheme.muted) }
                    HStack { DetailMetric(label: "TEMPO", value: game.playtimeLabel); DetailMetric(label: "CONQUISTAS", value: game.achievementsAvailable ? "\(game.achievementsCollected ?? 0)/\(game.achievementsTotal ?? 0)" : "INDISP."); DetailMetric(label: "STATUS", value: game.statusLabel) }
                    HStack { Button(game.favorite ? "REMOVER FAVORITO" : "FAVORITAR") { Task { await store.setLibraryState(game: game, favorite: !game.favorite, wantToPlay: game.wantToPlay) } }; Button(game.wantToPlay ? "REMOVER DA LISTA" : "QUERO JOGAR") { Task { await store.setLibraryState(game: game, favorite: game.favorite, wantToPlay: !game.wantToPlay) } } }.font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    NotesSummary(notes: game.notes) { editNotes = true }
                    if game.installed { Button("ABRIR B-CARD") { showBCard = true }.buttonStyle(PrimaryButtonStyle()) }
                    if game.achievementsAvailable { AchievementList(game: game) }
                }.padding(20)
            }
            .background(BrumTheme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) } } }
            .sheet(isPresented: $editNotes) { NotesEditor(game: game) }
            .fullScreenCover(isPresented: $showBCard) { BCardView(game: game) }
        }
    }
}

struct DetailMetric: View {
    let label: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(value).font(.caption.bold()).foregroundStyle(BrumTheme.text).lineLimit(2); Text(label).font(.caption2.bold()).foregroundStyle(BrumTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading) }
}

struct NotesSummary: View {
    let notes: Game.Notes; let edit: () -> Void
    var body: some View {
        BrumCard { VStack(alignment: .leading, spacing: 12) { HStack { BrumSectionLabel(text: "ANOTAÇÕES"); Spacer(); Button("EDITAR", action: edit).font(.caption.bold()).foregroundStyle(BrumTheme.primary) }; note("ONDE PAREI", notes.whereStopped); note("OBJETIVOS", notes.objectives); note("DICAS", notes.tips); note("COMANDOS", notes.commands) } }
    }
    @ViewBuilder private func note(_ label: String, _ value: String) -> some View { if !value.isEmpty { VStack(alignment: .leading, spacing: 3) { Text(label).font(.caption2.bold()).foregroundStyle(BrumTheme.primary); Text(value).font(.subheadline).foregroundStyle(BrumTheme.text) } } }
}

struct NotesEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var notes: Game.Notes
    @State private var saving = false
    init(game: Game) { self.game = game; _notes = State(initialValue: game.notes) }
    var body: some View {
        NavigationStack {
            Form { noteField("Onde parei", text: $notes.whereStopped); noteField("Objetivos", text: $notes.objectives); noteField("Dicas", text: $notes.tips); noteField("Comandos", text: $notes.commands) }
                .scrollContentBackground(.hidden).background(BrumTheme.background)
                .navigationTitle("Anotações")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Salvando…" : "Salvar") { saving = true; Task { if await store.saveNotes(game: game, notes: notes) { dismiss() }; saving = false } }.disabled(saving) } }
        }
    }
    private func noteField(_ title: String, text: Binding<String>) -> some View { Section(title) { TextEditor(text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(6000)) })).frame(minHeight: 90) } }
}

struct AchievementList: View {
    let game: Game
    var body: some View { VStack(alignment: .leading, spacing: 12) { BrumSectionLabel(text: "CONQUISTAS"); ForEach(game.achievements) { item in HStack(spacing: 12) { Image(systemName: item.unlocked ? "trophy.fill" : "lock.fill").foregroundStyle(item.unlocked ? BrumTheme.primary : BrumTheme.muted).frame(width: 28); VStack(alignment: .leading, spacing: 2) { Text(item.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text); Text(item.description).font(.caption).foregroundStyle(BrumTheme.muted).lineLimit(2) }; Spacer(); if item.points > 0 { Text("\(item.points)").font(.caption.bold()).foregroundStyle(BrumTheme.primary) } }.padding(.vertical, 7) } } }
}
