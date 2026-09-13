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
                    HStack { DetailMetric(label: "TEMPO", value: game.playtimeLabel); DetailMetric(label: "CONQUISTAS", value: game.achievementsAvailable || game.allowsManualAchievements ? "\(game.achievementsCollected ?? 0)/\(game.achievementsTotal ?? 0)" : "INDISP."); DetailMetric(label: "STATUS", value: game.statusLabel) }
                    HStack { Button(game.favorite ? "REMOVER FAVORITO" : "FAVORITAR") { Task { await store.setLibraryState(game: game, favorite: !game.favorite, wantToPlay: game.wantToPlay) } }; Button(game.wantToPlay ? "REMOVER DA LISTA" : "QUERO JOGAR") { Task { await store.setLibraryState(game: game, favorite: game.favorite, wantToPlay: !game.wantToPlay) } } }.font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    NotesSummary(notes: game.notes) { editNotes = true }
                    if game.installed { Button("ABRIR B-CARD") { showBCard = true }.buttonStyle(PrimaryButtonStyle()) }
                    if game.achievementsAvailable || game.allowsManualAchievements { AchievementList(game: game) }
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
    let initialGame: Game
    private var game: Game { store.snapshot.games.first { $0.id == initialGame.id } ?? initialGame }
    init(game: Game) { initialGame = game }
    var body: some View {
        NavigationStack {
            ScrollView { CompanionNotesForm(game: game).padding(20) }
                .background(BrumTheme.background)
                .navigationTitle("Anotações")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        }
    }
}

struct AchievementList: View {
    let game: Game
    @State private var search = ""
    @State private var editing: Game.Achievement?
    @State private var creating = false

    private var visible: [Game.Achievement] {
        game.achievements.filter { AchievementGameSearch.matches(search, fields: [$0.title, $0.description]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BrumSectionLabel(text: "CONQUISTAS")
                Spacer()
                if game.allowsManualAchievements {
                    Button("CADASTRAR") { creating = true }.font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                }
            }
            if !game.achievements.isEmpty {
                TextField("Buscar conquista", text: $search)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(BrumTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(BrumTheme.text)
            }
            if game.allowsManualAchievements {
                Text("REGISTRO MANUAL · toque em um item bloqueado ou manual. Confirmações oficiais permanecem protegidas.")
                    .font(.caption2.bold()).tracking(0.7).foregroundStyle(BrumTheme.primary)
            }
            if visible.isEmpty {
                Text(search.isEmpty ? "A conexão não forneceu um catálogo. Cadastre a conquista para registrar seu histórico." : "Nenhuma conquista corresponde à busca.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
            }
            ForEach(visible) { item in
                Button {
                    if game.allowsManualAchievements && (!item.unlocked || item.manual == true) { editing = item }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.unlocked ? "trophy.fill" : "lock.fill")
                            .foregroundStyle(item.unlocked ? BrumTheme.primary : BrumTheme.muted).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text)
                            Text(item.description).font(.caption).foregroundStyle(BrumTheme.muted).lineLimit(2)
                            if item.manual == true { Text("REGISTRO MANUAL").font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
                            else if item.unlocked { Text("CONFIRMADA OFICIALMENTE").font(.caption2.bold()).foregroundStyle(BrumTheme.muted) }
                        }
                        Spacer()
                        if item.points > 0 { Text("\(item.points)").font(.caption.bold()).foregroundStyle(BrumTheme.primary) }
                    }.padding(.vertical, 7)
                }.buttonStyle(.plain).disabled(item.unlocked && item.manual != true)
            }
        }
        .sheet(item: $editing) { ManualAchievementEditor(game: game, achievement: $0) }
        .sheet(isPresented: $creating) { ManualAchievementEditor(game: game, achievement: nil) }
    }
}

struct ManualAchievementEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let achievement: Game.Achievement?
    @State private var title = ""
    @State private var description = ""
    @State private var points = 0
    @State private var unlockedAt = Date()
    @State private var saving = false
    private var creating: Bool { achievement == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if creating {
                        TextField("Nome da conquista", text: $title)
                        TextField("Descrição opcional", text: $description, axis: .vertical)
                        Stepper("Pontos: \(points)", value: $points, in: 0...100000)
                    } else {
                        Text(achievement?.title ?? "").font(.headline)
                        if !(achievement?.description ?? "").isEmpty { Text(achievement?.description ?? "").foregroundStyle(BrumTheme.muted) }
                    }
                } header: { Text("CONQUISTA") }
                Section {
                    DatePicker("Desbloqueada em", selection: $unlockedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                } footer: { Text("O item será identificado como manual até uma fonte oficial confirmar o mesmo ID.") }
                if achievement?.manual == true {
                    Button("DESFAZER REGISTRO MANUAL", role: .destructive) {
                        Task {
                            saving = true
                            if await store.setManualAchievement(game: game, achievement: achievement, title: achievement?.title ?? "", description: achievement?.description ?? "", points: achievement?.points ?? 0, unlocked: false, unlockedAt: unlockedAt) { dismiss() }
                            saving = false
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(BrumTheme.background)
            .navigationTitle(creating ? "Cadastrar conquista" : "Registro manual")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Marcar") {
                        Task {
                            saving = true
                            if await store.setManualAchievement(game: game, achievement: achievement, title: creating ? title : achievement?.title ?? "", description: creating ? description : achievement?.description ?? "", points: creating ? points : achievement?.points ?? 0, unlocked: true, unlockedAt: unlockedAt) { dismiss() }
                            saving = false
                        }
                    }.disabled(saving || creating && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            title = achievement?.title ?? ""
            description = achievement?.description ?? ""
            points = achievement?.points ?? 0
            if let raw = achievement?.unlockedAt {
                let precise = ISO8601DateFormatter()
                precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = precise.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) { unlockedAt = min(date, Date()) }
            }
        }
    }
}
