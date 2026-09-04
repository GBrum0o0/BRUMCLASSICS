import SwiftUI

struct CompanionView: View {
    @EnvironmentObject private var store: AppStore
    private var recentNotes: [Game] { Array(store.snapshot.games.filter { $0.notes.hasContent }.sorted { $0.notes.updatedAt > $1.notes.updatedAt }.prefix(4)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(kicker: "BRUMCOMPANION", title: "Sua segunda tela.", subtitle: "Consulte e atualize suas anotações sem interromper o jogo.")
                ConnectionDot(state: store.connection)
                if case .error(let detail) = store.connection { Text(detail).font(.caption).foregroundStyle(.orange) }
                if let warning = store.realtimeWarning { Text(warning).font(.caption).foregroundStyle(BrumTheme.muted) }
                PerformancePanel()
                Button(store.capturingMoment ? "CAPTURANDO…" : "TIRAR PRINT") { Task { await store.captureMoment() } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(!store.canCaptureMoment).accessibilityIdentifier("companion-capture")
                if !store.canCaptureMoment && !store.capturingMoment {
                    Text(store.connection != .online ? "Conecte o iPhone ao launcher para capturar a tela do jogo." : "Inicie um jogo pelo launcher para habilitar a captura. Não é necessário ter anotações.").font(.caption).foregroundStyle(BrumTheme.muted)
                }
                if let game = store.companionGame {
                    BrumCard {
                        HStack(spacing: 16) {
                            GameCoverView(game: game).frame(width: 78, height: 108)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(store.connection == .online ? "JOGO ATIVO" : "ÚLTIMA SESSÃO · CACHE").font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                                Text(game.title).font(.title2.bold()).foregroundStyle(BrumTheme.text)
                                Text(game.platform.uppercased()).font(.caption).foregroundStyle(BrumTheme.muted)
                            }
                        }
                    }
                    CompanionNotesForm(game: game).id(game.id)
                } else {
                    BrumCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.activeGame != nil && store.connection == .online ? "NENHUMA ANOTAÇÃO PARA EXIBIR" : "AGUARDANDO UMA SESSÃO").font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                            Text(store.activeGame != nil && store.connection == .online ? "Jogos sem anotações ficam ocultos aqui. Adicione Onde parei, Objetivos, Dicas ou Comandos no perfil do jogo." : "Abra um jogo com anotações pelo BRUMCLASSICS OFICIAL. Fora da rede, suas notas continuam disponíveis abaixo e na Biblioteca.").font(.subheadline).foregroundStyle(BrumTheme.text)
                        }
                    }
                    BrumSectionLabel(text: "ANOTAÇÕES RECENTES")
                    if recentNotes.isEmpty { Text("Nenhuma anotação criada ainda.").foregroundStyle(BrumTheme.muted) }
                    ForEach(recentNotes) { game in
                        Button { store.selectedGame = game } label: { SettingsRow(icon: "note.text", title: game.title, detail: "Disponível offline · consultar e editar") }.buttonStyle(.plain)
                    }
                }
                if store.pendingCount > 0 { Text("\(store.pendingCount) alteração(ões) salva(s) no iPhone aguardando sincronização.").font(.caption).foregroundStyle(BrumTheme.primary) }
                NavigationLink { MomentsView() } label: { SettingsRow(icon: "photo.on.rectangle.angled", title: "BRUMMOMENTS", detail: "Sua galeria pessoal, disponível offline") }
            }.padding(20)
        }.background(BrumTheme.background.ignoresSafeArea()).refreshable { await store.refresh() }
    }
}

struct CompanionNotesForm: View {
    @EnvironmentObject private var store: AppStore
    let game: Game
    @State private var draft: Game.Notes
    @State private var baseGame: Game
    @State private var baseline: Game.Notes
    @State private var saving = false
    @State private var status = ""
    @State private var showConflict = false

    init(game: Game) {
        self.game = game
        _draft = State(initialValue: game.notes)
        _baseline = State(initialValue: game.notes)
        _baseGame = State(initialValue: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrumSectionLabel(text: "SUAS ANOTAÇÕES")
            field("ONDE PAREI", value: $draft.whereStopped)
            field("OBJETIVOS", value: $draft.objectives)
            field("DICAS", value: $draft.tips)
            field("COMANDOS", value: $draft.commands)
            Text(status.isEmpty ? "Até 6.000 caracteres por campo. O rascunho não é substituído pelas atualizações da sessão." : status).font(.caption).foregroundStyle(BrumTheme.muted)
            Button(saving ? "SALVANDO…" : "SALVAR NO BRUMCOMPANION") { save(force: false) }.buttonStyle(PrimaryButtonStyle()).disabled(saving)
            if store.noteConflicts.contains(game.id) {
                Button("RESOLVER CONFLITO") { showConflict = true }.font(.caption.bold()).foregroundStyle(.orange)
            }
        }
        .onChange(of: game.notes) { notes in
            // Refresh untouched fields only; never discard an in-progress draft.
            if draft == baseline { draft = notes; baseline = notes; baseGame = game }
        }
        .confirmationDialog("As anotações também mudaram no computador", isPresented: $showConflict, titleVisibility: .visible) {
            Button("Manter as anotações do iPhone") { save(force: true) }
            Button("Usar as anotações do launcher", role: .destructive) {
                Task {
                    if await store.useLauncherNotes(gameID: game.id), let latest = store.snapshot.games.first(where: { $0.id == game.id }) {
                        draft = latest.notes; baseline = latest.notes; baseGame = latest
                        status = "Anotações do launcher carregadas."
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func field(_ label: String, value: Binding<String>) -> some View {
        BrumCard { VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.bold()).foregroundStyle(BrumTheme.primary)
            TextEditor(text: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = String($0.prefix(6000)) }))
                .frame(minHeight: 90).scrollContentBackground(.hidden).foregroundStyle(BrumTheme.text).accessibilityLabel(label)
        } }
    }

    private func save(force: Bool) {
        guard !saving else { return }
        saving = true
        Task {
            if await store.saveNotes(game: baseGame, notes: draft, force: force) {
                baseline = draft
                status = store.noteConflicts.contains(game.id) ? "Conflito: seu rascunho está preservado no iPhone." : store.pendingGameIDs.contains(game.id) ? "Salvo no iPhone · envio pendente." : "Sincronizado com o launcher."
            }
            saving = false
        }
    }
}

struct PerformancePanel: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("performance_detailed") private var detailed = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { context in
            let value = store.snapshot.performance
            let live = value?.isLive(gameID: store.snapshot.companion?.gameId, connected: store.connection == .online, receivedUptime: store.performanceReceivedUptime, nowUptime: ProcessInfo.processInfo.systemUptime) == true
                VStack(alignment: .leading, spacing: 12) {
                    HStack { BrumSectionLabel(text: "DESEMPENHO"); Spacer(); Button(detailed ? "VISÃO SIMPLES" : "DETALHES") { detailed.toggle() }.font(.caption2.bold()).foregroundStyle(BrumTheme.primary) }
                    Text(live ? "AO VIVO" : store.connection != .online ? "OFFLINE · conecte ao launcher para receber as medições." : store.activeGame == nil ? "AGUARDANDO JOGO · inicie uma sessão pelo launcher." : "AGUARDANDO MEDIÇÕES · confira o monitor de desempenho em Configurações → MÓVEL no computador.").font(.caption).foregroundStyle(live ? BrumTheme.primary : BrumTheme.muted)
                    LazyVGrid(columns: columns, spacing: 12) {
                        metric("CPU", live && value?.cpu.available == true ? value?.cpu.usagePercent : nil, suffix: "%")
                        metric("TEMP. GPU", live && value?.gpu.available == true ? value?.gpu.temperatureC : nil, suffix: " °C")
                        metric("USO GPU", live && value?.gpu.available == true ? value?.gpu.usagePercent : nil, suffix: "%")
                        metric("FPS", live && value?.fps.available == true ? value?.fps.value : nil)
                        if detailed {
                            metric("RAM", live && value?.memory.available == true ? value?.memory.usedBytes.map { $0 / 1_073_741_824 } : nil, suffix: " GB")
                            metric("VRAM", live && value?.gpu.available == true ? value?.gpu.memoryUsedBytes.map { $0 / 1_073_741_824 } : nil, suffix: " GB")
                            metric("CPU DO JOGO", live && value?.process?.available == true ? value?.process?.cpuPercent : nil, suffix: "%")
                            metric("RAM DO JOGO", live && value?.process?.available == true ? value?.process?.ramBytes.map { $0 / 1_073_741_824 } : nil, suffix: " GB")
                            metric("TEMP. CPU", live ? value?.cpu.temperatureC : nil, suffix: " °C")
                        }
                    }
                    if live, let value {
                        if !value.fps.available { Text("FPS · " + PerformanceState.reasonLabel(value.fps.reason)).font(.caption).foregroundStyle(BrumTheme.muted) }
                        if !value.gpu.available { Text("GPU · " + PerformanceState.reasonLabel(value.gpu.reason)).font(.caption).foregroundStyle(BrumTheme.muted) }
                        if detailed { Text("GPU · \(value.gpu.name)\nSESSÃO · \(Int(max(0, value.sessionSeconds) / 60)) min").font(.caption).foregroundStyle(BrumTheme.muted) }
                        if detailed && value.cpu.temperatureC == nil { Text(PerformanceState.reasonLabel(value.cpu.temperatureReason)).font(.caption).foregroundStyle(BrumTheme.muted) }
                    }
                }
        }
    }

    private func metric(_ label: String, _ value: Double?, suffix: String = "") -> some View {
        StatCard(value: value.flatMap { $0.isFinite ? String(format: "%.1f%@", $0, suffix) : nil } ?? "INDISP.", label: label)
    }
}
