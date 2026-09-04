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
                .onOpenURL { url in Task { await store.pair(from: url) } }
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
                            await pocket.sync(launcher: store)
                            await store.checkForPersonalUpdate()
                        }
                    } else if phase == .background { store.suspend() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var pocket: PocketClassicsStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(selection: $selection) }.tabItem { Label("Início", systemImage: "house.fill") }.tag(0)
            NavigationStack { LibraryView() }.tabItem { Label("Biblioteca", systemImage: "rectangle.grid.2x2.fill") }.tag(1)
            NavigationStack { StatsView() }.tabItem { Label("Estatísticas", systemImage: "chart.bar.fill") }.tag(2)
            NavigationStack { CompanionView() }.tabItem { Label("Companion", systemImage: "note.text") }.tag(3)
            NavigationStack { ProfileView() }.tabItem { Label("Perfil", systemImage: "person.crop.circle.fill") }.tag(4)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .toolbarBackground(BrumTheme.deepBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(item: $store.selectedGame) { GameDetailView(game: $0) }
        .alert("BRUMCLASSICS", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
        .alert("CLASSICS", isPresented: Binding(get: { pocket.message != nil }, set: { if !$0 { pocket.message = nil } })) { Button("OK") { pocket.message = nil } } message: { Text(pocket.message ?? "") }
    }
}
