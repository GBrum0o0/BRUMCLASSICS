import SwiftUI

@main
struct BRUMCLASSICSMobileApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var pocket = PocketClassicsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(pocket)
                .task { await pocket.restore(); await pocket.sync(launcher: store) }
                .preferredColorScheme(.dark)
                .tint(BrumTheme.primary)
                .onOpenURL { url in
                    Task {
                        if url.scheme?.lowercased() == "brumclassics", url.host?.lowercased() == "retroarch" { await pocket.receiveRetroArchLibrary(url, launcher: store) }
                        else { await store.pair(from: url) }
                    }
                }
                .onChange(of: store.connection) { connection in
                    if connection == .online { Task { await pocket.sync(launcher: store) } }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                        await pocket.syncHours(launcher: store)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await store.resume()
                            await pocket.restore()
                            await pocket.finishPlaySession(launcher: store)
                            await pocket.refreshROMFolder()
                            await pocket.sync(launcher: store)
                            await store.checkForPersonalUpdate()
                        }
                    } else if phase == .inactive {
                        // This transition occurs before iOS suspends the process,
                        // so the persisted start time is not lost on app handoff.
                        Task { await pocket.notePlaySessionBackgrounded() }
                    } else if phase == .background {
                        store.suspend()
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var selection = 0

    var body: some View {
        ZStack {
            switch selection {
            case 1: NavigationStack { LibraryView() }
            case 2: NavigationStack { GamingModeView() }
            case 3: NavigationStack { CompanionView() }
            case 4: NavigationStack { ProfileView() }
            default: NavigationStack { HomeView(selection: $selection) }
            }
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { GamingTabBar(selection: $selection) }
        .sheet(item: $store.selectedGame) { GameDetailView(game: $0) }
        .alert("BRUMCLASSICS", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
        .alert("CLASSICS", isPresented: Binding(get: { pocket.message != nil }, set: { if !$0 { pocket.message = nil } })) { Button("OK") { pocket.message = nil } } message: { Text(pocket.message ?? "") }
    }
}

private struct GamingTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            tab(0, "Início", "house.fill")
            tab(1, "Biblioteca", "rectangle.grid.2x2.fill")
            Button { selection = 2 } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(BrumTheme.primary)
                            .shadow(color: BrumTheme.primary.opacity(selection == 2 ? 0.48 : 0.22), radius: selection == 2 ? 14 : 8)
                        Image(systemName: "play.fill").font(.system(size: 20, weight: .black)).foregroundStyle(Color.black).offset(x: 1)
                    }.frame(width: 58, height: 58).scaleEffect(selection == 2 ? 1.08 : 1)
                    Text("JOGAR").font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(BrumTheme.primary)
                }.offset(y: -14).frame(maxWidth: .infinity)
            }.buttonStyle(.plain).accessibilityLabel("Abrir Gaming Mode").accessibilityIdentifier("gaming-mode-tab")
            tab(3, "Companion", "note.text")
            tab(4, "Perfil", "person.crop.circle.fill")
        }
        .padding(.horizontal, 8).padding(.top, 9).padding(.bottom, 3)
        .background(BrumTheme.deepBackground.overlay(alignment: .top) { Rectangle().fill(BrumTheme.line).frame(height: 1) })
    }

    private func tab(_ value: Int, _ title: String, _ icon: String) -> some View {
        Button { selection = value } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                Text(title.uppercased()).font(.system(size: 8, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(selection == value ? BrumTheme.text : BrumTheme.muted)
            .frame(maxWidth: .infinity).frame(height: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("main-tab-\(value)")
    }
}
