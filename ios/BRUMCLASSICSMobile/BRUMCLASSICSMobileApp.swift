import SwiftUI

@main
struct BRUMCLASSICSMobileApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(BrumTheme.primary)
                .onOpenURL { url in Task { await store.pair(from: url) } }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await store.resume()
                            await store.checkForPersonalUpdate()
                        }
                    } else if phase == .background { store.suspend() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
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
    }
}
