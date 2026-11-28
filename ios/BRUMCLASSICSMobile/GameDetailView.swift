import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let initialGame: Game
    var game: Game { store.snapshot.games.first { $0.id == initialGame.id } ?? initialGame }
    init(game: Game) { initialGame = game }
    @State private var editNotes = false
    @State private var showBCard = false
    @State private var launchingGamepad = false
    @State private var showLocalMultiplayer = false
    @State private var showMurbRemote = false
    @State private var activeMurbTarget: MurbRemoteLaunchTarget?
    @State private var gamepadMessage = ""

    private var canStartOnPC: Bool { game.installed && store.connection == .online }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GameCoverView(game: game, cornerRadius: 16).aspectRatio(0.72, contentMode: .fit).frame(maxWidth: 310).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ExecutionBadge(kind: game.installed ? .dependsOnPC : .unavailable)
                            Spacer()
                        }
                        Text(game.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text("\(game.platform.uppercased()) · \(game.genre.uppercased())").font(.caption.bold()).tracking(1).foregroundStyle(BrumTheme.primary)
                        Text(game.description).font(.body).foregroundStyle(BrumTheme.muted)
                    }
                    HStack { DetailMetric(label: "TEMPO", value: game.playtimeLabel); DetailMetric(label: "CONQUISTAS", value: game.achievementsAvailable || game.allowsManualAchievements ? "\(game.achievementsCollected ?? 0)/\(game.achievementsTotal ?? 0)" : "INDISP."); DetailMetric(label: "STATUS", value: game.statusLabel) }
                    GamingActionBar(
                        canPlay: game.installed,
                        playTitle: "JOGAR",
                        playSubtitle: game.installed ? "Abrir via B-CARD" : "Indisponível",
                        gamepadBusy: launchingGamepad,
                        pcOnline: canStartOnPC,
                        onPlay: { showBCard = true },
                        onGamepad: { startPCGamepad(players: 1, hybridMode: "mobile1-pc2", myPlayerNumber: 1) },
                        onLocalMultiplayer: { showLocalMultiplayer = true }
                    )
                    if !gamepadMessage.isEmpty {
                        Text(gamepadMessage).font(.caption).foregroundStyle(BrumTheme.primary)
                    }
                    GamingInfoCard(title: "Informações do jogo", items: [
                        GamingInfoItem(label: "Plataforma", value: game.platform),
                        GamingInfoItem(label: "Loja / Origem", value: game.store),
                        GamingInfoItem(label: "Tamanho", value: game.sizeBytes > 0 ? ByteCountFormatter.string(fromByteCount: game.sizeBytes, countStyle: .file) : ""),
                        GamingInfoItem(label: "Execução", value: game.installed ? "Computador (B-CARD / Streaming / MURB Engine)" : "Instalação não confirmada no PC")
                    ])
                    HStack { Button(game.favorite ? "REMOVER FAVORITO" : "FAVORITAR") { Task { await store.setLibraryState(game: game, favorite: !game.favorite, wantToPlay: game.wantToPlay) } }; Button(game.wantToPlay ? "REMOVER DA LISTA" : "QUERO JOGAR") { Task { await store.setLibraryState(game: game, favorite: game.favorite, wantToPlay: !game.wantToPlay) } } }.font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    NotesSummary(notes: game.notes) { editNotes = true }
                    if game.installed { Button("ABRIR B-CARD") { showBCard = true }.buttonStyle(PrimaryButtonStyle()) }
                    if game.achievementsAvailable || game.allowsManualAchievements { AchievementList(game: game) }
                }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 32)
            }
            .background(BrumTheme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) } } }
            .sheet(isPresented: $editNotes) { NotesEditor(game: game) }
            .fullScreenCover(isPresented: $showBCard) { BCardView(game: game) }
            .sheet(isPresented: $showMurbRemote) {
                MurbRemoteGamepadLauncherSheet().preferredColorScheme(.dark)
            }
            .fullScreenCover(item: $activeMurbTarget) { target in
                MurbRemoteGamepadView(target: target.payload, gameTitle: target.gameTitle, playerNumber: target.playerNumber, p2Payload: target.p2Payload)
            }
            .sheet(isPresented: $showLocalMultiplayer) {
                LocalMultiplayerSheet(
                    gameTitle: game.title,
                    pcAvailable: canStartOnPC,
                    phoneCoopAvailable: false,
                    onStartPhoneCoop: { _ in },
                    onStartPCLanMultiplayer: { hybridMode, myPlayerNumber in
                        showLocalMultiplayer = false
                        startPCGamepad(players: 2, hybridMode: hybridMode, myPlayerNumber: myPlayerNumber)
                    },
                    onOpenManualMurb: {
                        showLocalMultiplayer = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showMurbRemote = true }
                    }
                )
                .preferredColorScheme(.dark)
            }
        }
    }

    private func startPCGamepad(players: Int, hybridMode: String, myPlayerNumber: Int) {
        guard canStartOnPC else {
            gamepadMessage = "Computador offline ou jogo não confirmado."
            showMurbRemote = true
            return
        }
        launchingGamepad = true
        gamepadMessage = "Abrindo \(game.title) no computador e preparando o joystick virtual…"
        Task {
            let outcome = await GamingGamepadLaunch.start(
                store: store,
                gameID: game.id,
                filename: nil,
                title: game.title,
                players: players,
                hybridMode: hybridMode,
                myPlayerNumber: myPlayerNumber
            )
            launchingGamepad = false
            gamepadMessage = outcome.message
            if let target = outcome.target { activeMurbTarget = target }
            else if outcome.openManualSheet { showMurbRemote = true }
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
    @EnvironmentObject private var store: AppStore
    let game: Game
    @State private var search = ""
    @State private var pending: Game.Achievement?
    @State private var saving = false

    private var visible: [Game.Achievement] {
        game.achievements.filter { AchievementGameSearch.matches(search, fields: [$0.title, $0.description]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrumSectionLabel(text: game.isClassic && game.achievementsAvailable ? "CONQUISTAS · RETROACHIEVEMENTS" : "CONQUISTAS")
            if let total = game.achievementsTotal, total > 0, let collected = game.achievementsCollected {
                HStack {
                    Text("\(collected) de \(total) desbloqueadas")
                        .font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                    Spacer()
                    Text("\(game.achievementProgress)%")
                        .font(.caption.bold()).foregroundStyle(BrumTheme.muted)
                }
                ProgressView(value: GamingAchievements.fraction(earned: collected, total: total))
                    .tint(BrumTheme.primary)
            }
            if !game.achievements.isEmpty {
                TextField("Buscar conquista", text: $search)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(BrumTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(BrumTheme.text)
            }
            if game.allowsManualAchievements {
                Text("\(game.achievementCatalogLabel) · toque para marcar ou desfazer. Confirmações oficiais permanecem protegidas.")
                    .font(.caption2.bold()).tracking(0.7).foregroundStyle(BrumTheme.primary)
            }
            if visible.isEmpty {
                Text(search.isEmpty ? "Abra este jogo na seção Conquistas do launcher para localizar o catálogo oficial." : "Nenhuma conquista corresponde à busca.")
                    .font(.caption).foregroundStyle(BrumTheme.muted)
            }
            ForEach(visible) { item in
                Button {
                    if game.allowsManualAchievements && (!item.unlocked || item.manual == true) { pending = item }
                } label: {
                    HStack(spacing: 12) {
                        AchievementBadge(item: item)
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
        .confirmationDialog(pending?.manual == true ? "Desmarcar conquista?" : "Marcar como desbloqueada?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            if let item = pending {
                Button(item.manual == true ? "Desmarcar" : "Marcar como desbloqueada", role: item.manual == true ? .destructive : nil) {
                    Task {
                        saving = true
                        _ = await store.setManualAchievement(game: game, achievement: item, unlocked: item.manual != true)
                        saving = false
                        pending = nil
                    }
                }
            }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: {
            Text(pending.map { "\($0.title) · o progresso será identificado como manual." } ?? "")
        }
        .allowsHitTesting(!saving)
    }
}

struct AchievementBadge: View {
    let item: Game.Achievement
    var body: some View {
        Group {
            if let raw = item.badgeUrl, let url = URL(string: raw), !raw.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallback }
                }
            } else { fallback }
        }
        .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 7))
        .opacity(item.unlocked ? 1 : 0.55).saturation(item.unlocked ? 1 : 0.25)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(BrumTheme.surface)
            Image(systemName: item.unlocked ? "trophy.fill" : "lock.fill").foregroundStyle(item.unlocked ? BrumTheme.primary : BrumTheme.muted)
        }
    }
}
