import SwiftUI
import UIKit

struct GamingModeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @Binding var selection: Int
    @State private var selectedGame: Game?
    @State private var selectedROM: ROMFolderGame?

    private let columns = [GridItem(.adaptive(minimum: 135), spacing: 16)]
    private var installedGames: [Game] { store.snapshot.games.filter(\.installed).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
    private var localGames: [ROMFolderGame] { pocket.romFolderGames.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Button { GamingOrientation.request(.portrait); selection = 0 } label: {
                        Label("SAIR", systemImage: "arrow.left").font(.caption.bold()).tracking(1)
                            .foregroundStyle(BrumTheme.text).padding(.horizontal, 15).frame(height: 42)
                            .background(BrumTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(BrumTheme.line))
                    }.buttonStyle(.plain).accessibilityIdentifier("gaming-mode-exit")
                    BrumLogo(compact: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BRUMCLASSICS").font(.caption2.bold()).tracking(2).foregroundStyle(BrumTheme.primary)
                        Text("GAMING MODE").font(.headline.bold()).foregroundStyle(BrumTheme.text)
                    }
                    Spacer()
                    ConnectionDot(state: store.connection)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prontos para jogar").font(.system(size: 32, weight: .black)).foregroundStyle(BrumTheme.text)
                    Text("Somente jogos disponíveis agora neste celular ou no computador.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                }

                if !localGames.isEmpty {
                    gameSection(title: "NO CELULAR", count: localGames.count) {
                        ForEach(localGames) { rom in
                            ROMFolderGameTile(
                                rom: rom,
                                launcherGame: pocket.launcherGame(for: rom, launcher: store),
                                retroArchReady: pocket.isImportedIntoRetroArch(rom),
                                integratedCoreName: IntegratedEmulatorSupport.core(for: rom)?.displayName
                            ) {
                                if IntegratedEmulatorSupport.supports(rom) { selectedROM = rom }
                                else { Task { await pocket.launchROM(rom, launcher: store) } }
                            }
                        }
                    }
                }

                if !installedGames.isEmpty {
                    gameSection(title: "INSTALADOS NO COMPUTADOR", count: installedGames.count) {
                        ForEach(installedGames) { game in
                            Button { selectedGame = game } label: { GamingGameTile(game: game) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                if localGames.isEmpty && installedGames.isEmpty {
                    BrumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NENHUM JOGO PRONTO").font(.headline.bold()).foregroundStyle(BrumTheme.text)
                            Text("Escolha uma pasta de ROMs no Perfil ou instale um jogo no computador.").font(.subheadline).foregroundStyle(BrumTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            GamingOrientation.request(.landscape)
            await pocket.refreshROMFolder()
        }
        .fullScreenCover(item: $selectedGame) { GamingGameView(game: $0) }
        .fullScreenCover(item: $selectedROM) { IntegratedEmulatorView(rom: $0, returnsToPortrait: false) }
    }

    private func gameSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                BrumSectionLabel(text: title)
                Spacer()
                Text("\(count) JOGO\(count == 1 ? "" : "S")").font(.caption2.bold()).foregroundStyle(BrumTheme.primary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20, content: content)
        }
    }
}

@MainActor enum GamingOrientation {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard #available(iOS 16.0, *) else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
    }
}

private struct GamingGameTile: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameCoverView(game: game, cornerRadius: 11).aspectRatio(0.72, contentMode: .fit)
            Text(game.platform.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(BrumTheme.primary)
            Text(game.title).font(.subheadline.bold()).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
            Text("NO COMPUTADOR").font(.caption2.bold()).foregroundStyle(BrumTheme.muted)
        }
    }
}

private struct GamingGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var launchState = ""
    @State private var launching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GameCoverView(game: game, cornerRadius: 16).aspectRatio(0.72, contentMode: .fit).frame(maxWidth: 330).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(routeLabel).font(.caption.bold()).tracking(1.5).foregroundStyle(BrumTheme.primary)
                        Text(game.title).font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text(game.description).font(.body).foregroundStyle(BrumTheme.muted)
                    }
                    Button(action: play) { HStack { if launching { ProgressView().tint(.black) }; Text(playLabel) }.frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!canPlay || launching).opacity(canPlay ? 1 : 0.38)
                    if !launchState.isEmpty { Text(launchState).font(.caption).foregroundStyle(launchState.contains("não") ? Color.orange : BrumTheme.primary) }
                    BrumCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { BrumSectionLabel(text: "STREAMING REMOTO"); Spacer(); Text("EM DESENVOLVIMENTO").font(.caption2.bold()).foregroundStyle(.orange) }
                            Text("O jogo pode ser iniciado no computador, mas esta versão ainda não recebe vídeo e áudio nem envia controles pela internet.").font(.caption).foregroundStyle(BrumTheme.muted)
                        }
                    }
                }.padding(20)
            }.background(BrumTheme.background.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) } } }
        }
        .onAppear { GamingOrientation.request(.landscape) }
    }

    private var routeLabel: String { "PC · CANAL SEGURO" }
    private var playLabel: String {
        if !game.installed { return "INSTALAÇÃO NÃO CONFIRMADA" }
        return store.connection == .online ? "INICIAR NO COMPUTADOR" : "COMPUTADOR OFFLINE"
    }
    private var canPlay: Bool { game.installed && store.connection == .online }

    private func play() {
        launching = true
        launchState = "Conectando ao computador e validando a instalação…"
        Task {
            let error = await store.launchBCard(game)
            await MainActor.run {
                launching = false
                launchState = error.map { "Não foi possível iniciar: \($0)" } ?? "Jogo iniciado no computador."
            }
        }
    }
}
