import Foundation
import SwiftUI
import UIKit

enum PokedexSpriteRenderMode: Equatable {
    case silhouette
    case normal
    case shiny
}

// Species artwork is loaded on demand from PokeAPI; the exact same alpha mask
// is used for an undiscovered silhouette. No procedural substitute is generated.
enum PokedexPixelSprite {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 10 * 1024 * 1024
        return cache
    }()
    private static let highPrioritySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    private static let thumbSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    static func url(for dex: Int, mode: PokedexSpriteRenderMode) -> URL {
        let variant = mode == .shiny ? "shiny/" : ""
        return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(variant)\(max(1, min(809, dex))).png")!
    }
    static func silhouette(_ image: UIImage) -> UIImage {
        image.withTintColor(.black, renderingMode: .alwaysOriginal)
    }
    private static func cacheFileURL(for dex: Int, mode: PokedexSpriteRenderMode) -> (folder: URL, file: URL) {
        let clampedDex = max(1, min(809, dex))
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("brum-pokedex-images", isDirectory: true)
        let file = folder.appendingPathComponent("\(clampedDex)-\(mode == .shiny ? "shiny" : "normal").png")
        return (folder, file)
    }
    static func loadAsync(for dex: Int, mode: PokedexSpriteRenderMode, highPriority: Bool = false) async -> UIImage? {
        let address = url(for: dex, mode: mode)
        let key = address.absoluteString as NSString
        if let cached = cache.object(forKey: key) {
            return mode == .silhouette ? silhouette(cached) : cached
        }
        let (folder, file) = cacheFileURL(for: dex, mode: mode)
        let diskImage: UIImage? = await Task.detached(priority: highPriority ? .userInitiated : .utility) {
            guard let data = try? Data(contentsOf: file), let img = UIImage(data: data) else { return nil }
            return img
        }.value
        if Task.isCancelled { return nil }
        if let diskImage {
            cache.setObject(diskImage, forKey: key, cost: Int(diskImage.size.width * diskImage.size.height * 4))
            return mode == .silhouette ? silhouette(diskImage) : diskImage
        }
        let session = highPriority ? highPrioritySession : thumbSession
        let request = URLRequest(url: address, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        do {
            let (data, response) = try await session.data(for: request)
            if Task.isCancelled { return nil }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url?.host == "raw.githubusercontent.com",
                  data.count <= 1_048_576, let image = UIImage(data: data),
                  image.size.width <= 1024, image.size.height <= 1024 else {
                return nil
            }
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
            Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
            }
            return mode == .silhouette ? silhouette(image) : image
        } catch {
            return nil
        }
    }
    @discardableResult
    static func load(for dex: Int, mode: PokedexSpriteRenderMode, highPriority: Bool = false,
                     completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let address = url(for: dex, mode: mode)
        let key = address.absoluteString as NSString
        let deliver: (UIImage?) -> Void = { source in
            DispatchQueue.main.async {
                completion(source.map { mode == .silhouette ? silhouette($0) : $0 })
            }
        }
        if let image = cache.object(forKey: key) { deliver(image); return nil }
        let (folder, file) = cacheFileURL(for: dex, mode: mode)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
            deliver(image); return nil
        }
        let request = URLRequest(url: address, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        let session = highPriority ? highPrioritySession : thumbSession
        let task = session.dataTask(with: request) { data, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url?.host == "raw.githubusercontent.com",
                  let data, data.count <= 1_048_576, let image = UIImage(data: data),
                  image.size.width <= 1024, image.size.height <= 1024 else {
                deliver(nil); return
            }
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            deliver(image)
        }
        task.priority = highPriority ? URLSessionTask.highPriority : URLSessionTask.lowPriority
        task.resume()
        return task
    }
}

struct PokedexSpeciesImage: View {
    let nationalDexNumber: Int
    let mode: PokedexSpriteRenderMode
    var highPriority: Bool = false
    var interactiveRetry: Bool = false
    @State private var image: UIImage?
    @State private var failed = false
    @State private var reloadToken = 0
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
            } else if failed {
                if interactiveRetry {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Imagem indisponível")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Button("Tentar novamente") {
                            reloadToken += 1
                        }
                        .font(.caption2.bold())
                        .buttonStyle(.bordered)
                        .tint(BrumTheme.primary)
                        .frame(minHeight: 36)
                        .accessibilityIdentifier("pokedex-retry-image")
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Imagem indisponível. Conecte à internet para carregar.")
                }
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary.opacity(0.45))
                    .accessibilityLabel("Carregando imagem da espécie")
            }
        }
        .accessibilityLabel(mode == .silhouette ? "Silhueta da espécie número \(nationalDexNumber)" : "Imagem da espécie número \(nationalDexNumber)")
        .accessibilityHint(failed ? "A primeira consulta da imagem requer internet; imagens já carregadas ficam em cache." : "")
        .task(id: "\(nationalDexNumber)-\(mode)-\(reloadToken)") {
            image = nil; failed = false
            let loaded = await PokedexPixelSprite.loadAsync(for: nationalDexNumber, mode: mode, highPriority: highPriority)
            guard !Task.isCancelled else { return }
            image = loaded; failed = loaded == nil
        }
    }
}

enum PokedexDisplayTab: String, CaseIterable, Identifiable {
    case pokemon = "pokemon"
    case shinies = "shinies"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pokemon: return "POKÉMON"
        case .shinies: return "SHINIES"
        }
    }
}

extension Notification.Name {
    static let brumPokedexCaptureDetected = Notification.Name("BrumPokedexCaptureDetectedNotification")
    static let brumPokedexCollectionUpdated = Notification.Name("BrumPokedexCollectionUpdatedNotification")
}

@MainActor
final class PokedexUniversalCoordinator: ObservableObject {
    static let shared = PokedexUniversalCoordinator()

    @Published private(set) var projectedView: PokedexProjectedView
    @Published var isDeviceOpen: Bool = false
    @Published var selectedTab: PokedexDisplayTab = .pokemon
    @Published var selectedScope: String = "pilot"
    @Published var selectedDexNumber: Int = 1
    @Published var searchQuery: String = ""
    @Published var isExtensionEnabled: Bool = true
    @Published var syncFeedback: String = ""
    @Published var isSyncing: Bool = false

    let store: PokedexUniversalStore
    let profileID: String
    private var captureObserver: NSObjectProtocol?
    private var updateObserver: NSObjectProtocol?

    init(store: PokedexUniversalStore = .shared, profileID: String = "primary") {
        self.store = store
        self.profileID = profileID
        self.isExtensionEnabled = BrumExtensionRegistry.shared.isEnabled(BrumExtensionManifest.pokedexUniversal.id, profileID: profileID)
        self.projectedView = (try? store.projectedView(profileID: profileID, platform: "ios", scope: "pilot")) ?? Self.emptyProjectedView(profileID: profileID)
        if let firstDiscovered = projectedView.tabs.pokemon.first(where: \.discovered) {
            self.selectedDexNumber = firstDiscovered.nationalDexNumber
        }
        setupObservers()
    }

    private static func emptyProjectedView(profileID: String) -> PokedexProjectedView {
        PokedexProjectedView(
            schemaVersion: 1,
            extensionId: BrumExtensionManifest.pokedexUniversal.id,
            catalogVersion: PokedexUniversalStore.catalogVersion,
            ownerProfileId: profileID,
            platform: "ios",
            syncRevision: 1,
            updatedAt: PokedexUniversalStore.currentIsoTimestamp(),
            contentSha256: PokedexUniversalStore.canonicalRecordsHash([]),
            enabledGenerations: [1],
            summary: PokedexViewSummary(
                normalDiscovered: 0,
                normalAvailableTotal: 151,
                shinyDiscovered: 0,
                totalCatalogSpecies: 809
            ),
            tabs: PokedexViewTabs(pokemon: [], shinies: [])
        )
    }

    private func setupObservers() {
        captureObserver = NotificationCenter.default.addObserver(
            forName: .brumPokedexCaptureDetected,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let dex = (info["nationalDexNumber"] as? NSNumber)?.intValue ?? 0
            let isShiny = (info["isShiny"] as? NSNumber)?.boolValue ?? false
            let location = (info["captureLocation"] as? String) ?? PokedexUniversalStore.unknownLocation
            let gameTitle = (info["gameTitle"] as? String) ?? "Pokémon FireRed Version"
            let gameID = (info["canonicalGameID"] as? String) ?? ""
            let systemID = (info["systemID"] as? String) ?? "gba"
            Task { @MainActor [weak self] in
                self?.handleDetectedCapture(
                    nationalDexNumber: dex,
                    isShiny: isShiny,
                    gameTitle: gameTitle,
                    gameID: gameID,
                    systemID: systemID,
                    captureLocation: location
                )
            }
        }

        updateObserver = NotificationCenter.default.addObserver(
            forName: .brumPokedexCollectionUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    func reload() {
        isExtensionEnabled = BrumExtensionRegistry.shared.isEnabled(BrumExtensionManifest.pokedexUniversal.id, profileID: profileID)
        if let updated = try? store.projectedView(profileID: profileID, platform: "ios", scope: selectedScope) {
            projectedView = updated
            ensureValidSelection()
        }
    }

    func selectScope(_ scope: String) {
        selectedScope = scope
        reload()
    }

    func setExtensionEnabled(_ enabled: Bool) {
        try? BrumExtensionRegistry.shared.setEnabled(BrumExtensionManifest.pokedexUniversal.id, enabled: enabled, profileID: profileID)
        isExtensionEnabled = enabled
        if !enabled {
            isDeviceOpen = false
        }
    }

    func handleDetectedCapture(
        nationalDexNumber: Int,
        isShiny: Bool,
        gameTitle: String,
        gameID: String,
        systemID: String,
        captureLocation: String
    ) {
        guard isExtensionEnabled, (1...809).contains(nationalDexNumber) else { return }
        guard let result = try? store.recordCapture(
            ownerProfileId: profileID,
            nationalDexNumber: nationalDexNumber,
            isShiny: isShiny,
            gameTitle: gameTitle,
            gameId: gameID,
            systemId: systemID,
            capturedAt: nil,
            captureLocation: captureLocation
        ) else { return }

        reload()
        selectedDexNumber = nationalDexNumber
        if isShiny {
            selectedTab = .shinies
        }
        if result.recorded, let notification = result.notification {
            let popup = BrumAchievementOverlayPayload.fromPokedexDiscovery(notification)
            BrumAchievementOverlayCoordinator.shared.enqueue(popup)
        }
    }

    var displayedEntries: [PokedexProjectedEntry] {
        let base: [PokedexProjectedEntry]
        switch selectedTab {
        case .pokemon:
            base = projectedView.tabs.pokemon
        case .shinies:
            base = projectedView.tabs.shinies
        }
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return base }
        let numericQuery = trimmed.replacingOccurrences(of: "#", with: "")
        return base.filter { entry in
            if entry.formattedNumber.lowercased().contains(numericQuery)
                || String(entry.nationalDexNumber) == numericQuery {
                return true
            }
            // Never match undiscovered species by hidden real name
            guard entry.discovered else { return false }
            return entry.name.lowercased().contains(trimmed)
                || (entry.capture?.firstCapturedGame.lowercased().contains(trimmed) ?? false)
                || (entry.capture?.captureLocation.lowercased().contains(trimmed) ?? false)
        }
    }

    var selectedEntry: PokedexProjectedEntry? {
        let list = displayedEntries
        if let match = list.first(where: { $0.nationalDexNumber == selectedDexNumber }) {
            return match
        }
        return list.first
    }

    func selectTab(_ tab: PokedexDisplayTab) {
        selectedTab = tab
        ensureValidSelection()
    }

    private func ensureValidSelection() {
        let list = displayedEntries
        if !list.contains(where: { $0.nationalDexNumber == selectedDexNumber }),
           let first = list.first {
            selectedDexNumber = first.nationalDexNumber
        }
    }

    func syncWithLauncher(_ appStore: AppStore) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let outcome = await appStore.syncPokedexWithLauncher(profileID: profileID)
        reload()
        syncFeedback = outcome
    }
}

struct PokedexGamingExtensionView: View {
    @EnvironmentObject private var appStore: AppStore
    @ObservedObject private var coordinator = PokedexUniversalCoordinator.shared
    @State private var showBackupSheet = false
    @State private var backupJSONText = ""
    @State private var backupMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            extensionHeaderCard

            if !coordinator.isExtensionEnabled {
                disabledExtensionCard
            } else if !coordinator.isDeviceOpen {
                closedPokedexDeviceCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .scale(scale: 1.03).combined(with: .opacity)
                    ))
            } else {
                openPokedexSplitView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.80), value: coordinator.isDeviceOpen)
        .onAppear {
            coordinator.reload()
            if appStore.connection == .online {
                Task { await coordinator.syncWithLauncher(appStore) }
            }
        }
        .sheet(isPresented: $showBackupSheet) {
            pokedexBackupSheet
                .preferredColorScheme(.dark)
        }
    }

    private var extensionHeaderCard: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BrumTheme.elevated)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrumTheme.primary.opacity(0.45), lineWidth: 1))
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [BrumTheme.primary, BrumTheme.primary.opacity(0.25), .clear],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 18
                                )
                            )
                            .frame(width: 28, height: 28)
                        Circle()
                            .stroke(BrumTheme.primary, lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("EXTENSÃO 001")
                                .font(.caption2.bold())
                                .tracking(1.3)
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(BrumTheme.primary, in: Capsule())
                            Text("GAMEPAD & GAMING MODE")
                                .font(.caption2.bold())
                                .tracking(1.1)
                                .foregroundStyle(BrumTheme.muted)
                        }
                        Text("Pokédex Universal")
                            .font(.title3.weight(.black))
                            .foregroundStyle(BrumTheme.text)
                        Text("Coleção permanente vinculada ao perfil · Independente dos saves · Piloto em teste: FireRed (BPRE/GBA)")
                            .font(.caption)
                            .foregroundStyle(BrumTheme.muted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 10) {
                        pokedexCounterBadge(
                            label: "POKÉMON",
                            value: "\(coordinator.projectedView.summary.normalDiscovered)/\(coordinator.projectedView.summary.normalAvailableTotal)",
                            accent: BrumTheme.primary
                        )
                        pokedexCounterBadge(
                            label: "✦ SHINIES",
                            value: "\(coordinator.projectedView.summary.shinyDiscovered)",
                            accent: Color(red: 1.0, green: 0.84, blue: 0.25)
                        )
                    }
                }

                Divider().overlay(BrumTheme.line)

                HStack(spacing: 10) {
                    if coordinator.isExtensionEnabled {
                        Button {
                            withAnimation(.spring(response: 0.52, dampingFraction: 0.80)) {
                                coordinator.isDeviceOpen.toggle()
                            }
                        } label: {
                            Label(
                                coordinator.isDeviceOpen ? "FECHAR POKÉDEX" : "ABRIR POKÉDEX",
                                systemImage: coordinator.isDeviceOpen ? "book.closed.fill" : "book.fill"
                            )
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrumTheme.primary)
                        .foregroundStyle(Color.black)
                        .accessibilityIdentifier("pokedex-toggle-device")
                    }

                    Button {
                        Task { await coordinator.syncWithLauncher(appStore) }
                    } label: {
                        HStack(spacing: 6) {
                            if coordinator.isSyncing {
                                ProgressView().tint(BrumTheme.primary).controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(coordinator.isSyncing ? "SINCRONIZANDO…" : "SINCRONIZAR COM PC")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(BrumTheme.primary)
                    .disabled(coordinator.isSyncing)
                    .accessibilityIdentifier("pokedex-sync-pc")

                    Button {
                        if let bundle = try? coordinator.store.exportBackup(profileID: coordinator.profileID),
                           let data = try? JSONEncoder().encode(bundle),
                           let text = String(data: data, encoding: .utf8) {
                            backupJSONText = text
                        }
                        backupMessage = ""
                        showBackupSheet = true
                    } label: {
                        Label("BACKUP SHA-256", systemImage: "externaldrive.badge.checkmark")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .frame(minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(BrumTheme.text)
                    .accessibilityIdentifier("pokedex-backup-button")

                    Spacer(minLength: 4)

                    Toggle(isOn: Binding(
                        get: { coordinator.isExtensionEnabled },
                        set: { coordinator.setExtensionEnabled($0) }
                    )) {
                        Text(coordinator.isExtensionEnabled ? "Ativa" : "Desativada")
                            .font(.caption.bold())
                            .foregroundStyle(coordinator.isExtensionEnabled ? BrumTheme.primary : BrumTheme.muted)
                    }
                    .labelsHidden()
                    .tint(BrumTheme.primary)
                    .accessibilityIdentifier("pokedex-enable-toggle")
                }

                if !coordinator.syncFeedback.isEmpty {
                    Text(coordinator.syncFeedback)
                        .font(.caption)
                        .foregroundStyle(BrumTheme.primary)
                }
            }
        }
    }

    private func pokedexCounterBadge(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(BrumTheme.muted)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.28), lineWidth: 1))
    }

    private var disabledExtensionCard: some View {
        BrumCard {
            HStack(spacing: 14) {
                Image(systemName: "power.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(BrumTheme.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extensão Pokédex Universal desativada")
                        .font(.headline)
                        .foregroundStyle(BrumTheme.text)
                    Text("Seus registros permanentes continuam preservados com segurança neste perfil. Ative a chave acima para abrir a Pokédex e detectar novas capturas.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }
                Spacer()
            }
        }
    }

    // MARK: - Section 9: Closed Pokédex Device Initial State & Open Animation
    private var closedPokedexDeviceCard: some View {
        Button {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                coordinator.isDeviceOpen = true
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.09, blue: 0.11),
                                Color(red: 0.04, green: 0.05, blue: 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(BrumTheme.primary.opacity(0.45), lineWidth: 1.5)
                    )

                // Center magnetic hinge seam
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(BrumTheme.line)
                        .frame(width: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(BrumTheme.elevated)
                                .frame(width: 18, height: 68)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(BrumTheme.primary.opacity(0.65), lineWidth: 1.2)
                                )
                        )
                    Spacer()
                }

                HStack(spacing: 24) {
                    // Left closed cover: Optical scanner lens & status LEDs
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 74, height: 74)
                                .overlay(Circle().stroke(BrumTheme.line, lineWidth: 3))
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            BrumTheme.primary,
                                            BrumTheme.primary.opacity(0.40),
                                            Color(red: 0.05, green: 0.16, blue: 0.08)
                                        ],
                                        center: .topLeading,
                                        startRadius: 4,
                                        endRadius: 36
                                    )
                                )
                                .frame(width: 58, height: 58)
                            Circle()
                                .fill(Color.white.opacity(0.65))
                                .frame(width: 12, height: 12)
                                .offset(x: -10, y: -10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle().fill(BrumTheme.primary).frame(width: 10, height: 10)
                                Circle().fill(Color(red: 1.0, green: 0.82, blue: 0.24)).frame(width: 10, height: 10)
                                Circle().fill(Color(red: 0.29, green: 0.82, blue: 1.0)).frame(width: 10, height: 10)
                                Text("UNIDADE ÓPTICA BRUM · DEX-001")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(BrumTheme.muted)
                            }
                            Text("POKÉDEX UNIVERSAL")
                                .font(.title2.weight(.black))
                                .tracking(1.4)
                                .foregroundStyle(BrumTheme.text)
                            Text("DISPOSITIVO FECHADO · \(coordinator.projectedView.summary.normalDiscovered) DE \(coordinator.projectedView.summary.normalAvailableTotal) ESPÉCIES REGISTRADAS")
                                .font(.caption.bold())
                                .foregroundStyle(BrumTheme.primary)
                        }
                    }

                    Spacer(minLength: 24)

                    // Right closed cover: Call to action to tap and unfold
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("TOQUE PARA ABRIR A POKÉDEX")
                                .font(.subheadline.weight(.black))
                                .tracking(1.0)
                                .foregroundStyle(Color.black)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(BrumTheme.primary, in: RoundedRectangle(cornerRadius: 10))

                        Text("Abra, consulte as espécies e navegue pelos botões do dispositivo")
                            .font(.caption2)
                            .foregroundStyle(BrumTheme.muted)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, minHeight: 156)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pokedex-open-device")
    }

    // MARK: - Section 9: Horizontal Split View (Left Detail Panel + Right Species List & Tabs)
    private var openPokedexSplitView: some View {
        HStack(alignment: .top, spacing: 16) {
            leftDetailPanel
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 390)
            rightListPanel
                .frame(maxWidth: .infinity)
        }
    }

    private func navigateSpecies(_ delta: Int) {
        let entries = coordinator.displayedEntries
        guard !entries.isEmpty else { return }
        let index = entries.firstIndex { $0.nationalDexNumber == coordinator.selectedDexNumber } ?? 0
        coordinator.selectedDexNumber = entries[(index + delta + entries.count) % entries.count].nationalDexNumber
    }

    private var leftDetailPanel: some View {
        let entry = coordinator.selectedEntry
        return BrumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(entry.map { "#\($0.formattedNumber)" } ?? "#---")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(BrumTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(BrumTheme.elevated, in: Capsule())

                    Spacer()

                    if let entry {
                        if entry.isShiny && entry.discovered {
                            Label("✦ SHINY", systemImage: "sparkles")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(red: 1.0, green: 0.84, blue: 0.25), in: Capsule())
                        } else if entry.discovered {
                            Label("CAPTURADO", systemImage: "checkmark.circle.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(BrumTheme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(BrumTheme.primary.opacity(0.14), in: Capsule())
                        } else {
                            Label("NÃO DESCOBERTO", systemImage: "questionmark.circle")
                                .font(.caption2.bold())
                                .foregroundStyle(BrumTheme.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(BrumTheme.elevated, in: Capsule())
                        }
                    }
                }

                // Optical Specimen Screen (Black Silhouette for undiscovered, Pixel Art for discovered)
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    (entry?.isShiny == true && entry?.discovered == true)
                                        ? Color(red: 1.0, green: 0.84, blue: 0.25).opacity(0.75)
                                        : BrumTheme.primary.opacity(0.35),
                                    lineWidth: 1.4
                                )
                        )

                    // Scanner grid backdrop so pure black silhouettes stand out with high contrast
                    VStack(spacing: 14) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 1)
                        }
                    }
                    .padding(10)

                    if let entry {
                        let mode: PokedexSpriteRenderMode = !entry.discovered
                            ? .silhouette
                            : (entry.isShiny ? .shiny : .normal)
                        PokedexSpeciesImage(nationalDexNumber: entry.nationalDexNumber, mode: mode, highPriority: true, interactiveRetry: true)
                            .frame(width: 122, height: 122)
                            .accessibilityIdentifier("pokedex-detail-sprite")
                    } else {
                        Text("Nenhuma espécie nesta aba")
                            .font(.caption.bold())
                            .foregroundStyle(BrumTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 164)

                HStack(spacing: 10) {
                    Button { navigateSpecies(-1) } label: {
                        Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Espécie anterior")
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { coordinator.isDeviceOpen = false }
                    } label: {
                        Text("VOLTAR").font(.caption2.weight(.heavy)).padding(.horizontal, 10).frame(minHeight: 44)
                    }.accessibilityLabel("Voltar e fechar Pokédex")
                    Spacer()
                    Button { navigateSpecies(1) } label: {
                        Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Próxima espécie")
                }
                .buttonStyle(.bordered)
                .tint(BrumTheme.primary)
                .accessibilityIdentifier("pokedex-device-controls")

                if let entry {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("#\(entry.formattedNumber)")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(BrumTheme.primary)
                            Text(entry.discovered ? entry.name : PokedexUniversalStore.unknownText)
                                .font(.title2.weight(.black))
                                .foregroundStyle(BrumTheme.text)
                                .accessibilityIdentifier("pokedex-detail-name")
                        }

                        Text(entry.discovered ? entry.genus : PokedexUniversalStore.unknownText)
                            .font(.caption.bold())
                            .foregroundStyle(BrumTheme.muted)

                        Text(entry.discovered ? entry.description : PokedexUniversalStore.unknownText)
                            .font(.subheadline)
                            .foregroundStyle(entry.discovered ? BrumTheme.text.opacity(0.92) : BrumTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .accessibilityIdentifier("pokedex-detail-description")
                    }

                    Divider().overlay(BrumTheme.line)

                    if entry.discovered, let capture = entry.capture {
                        VStack(alignment: .leading, spacing: 8) {
                            BrumSectionLabel(text: "REGISTRO DA PRIMEIRA CAPTURA")
                            detailRow(label: "JOGO DE ORIGEM", value: capture.firstCapturedGame)
                            detailRow(label: "DATA E HORÁRIO", value: Self.formatCaptureTimestamp(capture.capturedAt))
                            detailRow(
                                label: "LOCALIZAÇÃO",
                                value: capture.captureLocation.isEmpty
                                    ? PokedexUniversalStore.unknownLocation
                                    : capture.captureLocation
                            )
                            detailRow(label: "CATEGORIA", value: entry.isShiny ? "Shiny (Independente)" : "Normal")
                        }
                        .accessibilityIdentifier("pokedex-detail-capture-info")
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(BrumTheme.muted)
                            Text("Informações de captura ocultas até a primeira captura confirmada.")
                                .font(.caption)
                                .foregroundStyle(BrumTheme.muted)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityIdentifier("pokedex-detail-capture-hidden")
                    }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(BrumTheme.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrumTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private var rightListPanel: some View {
        BrumCard {
            VStack(alignment: .leading, spacing: 12) {
                // Top Tabs: Pokémon vs Shinies
                HStack(spacing: 10) {
                    tabButton(
                        tab: .pokemon,
                        title: "POKÉMON (\(coordinator.projectedView.summary.normalDiscovered)/\(coordinator.projectedView.summary.normalAvailableTotal))",
                        identifier: "pokedex-tab-pokemon"
                    )
                    tabButton(
                        tab: .shinies,
                        title: "✦ SHINIES (\(coordinator.projectedView.summary.shinyDiscovered))",
                        identifier: "pokedex-tab-shinies"
                    )
                }

                // Generation / Scope filter (Piloto G1 151 vs Catálogo G1–G7 809)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        scopeChip("Piloto G1 (151)", scope: "pilot")
                        scopeChip("G1–G7 (809)", scope: "all")
                        ForEach(1...7, id: \.self) { g in
                            scopeChip("G\(g)", scope: "gen\(g)")
                        }
                    }
                }

                // Safe search field (filters by # number or discovered name only)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(BrumTheme.muted)
                    TextField("Buscar por número (#025) ou espécie descoberta…", text: $coordinator.searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .foregroundStyle(BrumTheme.text)
                        .accessibilityIdentifier("pokedex-search-field")
                    if !coordinator.searchQuery.isEmpty {
                        Button {
                            coordinator.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BrumTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrumTheme.line, lineWidth: 1))

                let entries = coordinator.displayedEntries
                if entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(coordinator.selectedTab == .shinies ? "Nenhum Pokémon shiny registrado ainda" : "Nenhuma espécie corresponde à busca")
                            .font(.subheadline.bold())
                            .foregroundStyle(BrumTheme.text)
                        Text(coordinator.selectedTab == .shinies
                             ? "A aba Shinies exibe exclusivamente Pokémon shiny capturados. Capturar um shiny preserva um registro independente sem sobrescrever a Pokédex normal."
                             : "Digite o número oficial da Pokédex Nacional (ex.: 001, 025) ou o nome de um Pokémon já capturado.")
                            .font(.caption)
                            .foregroundStyle(BrumTheme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 10))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                speciesRow(entry)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 280, maxHeight: 420)
                }
            }
        }
    }

    private func scopeChip(_ title: String, scope: String) -> some View {
        let active = coordinator.selectedScope == scope
        return Button {
            coordinator.selectScope(scope)
        } label: {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(active ? Color.black : BrumTheme.text)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(active ? BrumTheme.primary : BrumTheme.elevated, in: Capsule())
                .overlay(Capsule().stroke(active ? BrumTheme.primary : BrumTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func tabButton(tab: PokedexDisplayTab, title: String, identifier: String) -> some View {
        let selected = coordinator.selectedTab == tab
        let accent: Color = (tab == .shinies) ? Color(red: 1.0, green: 0.84, blue: 0.25) : BrumTheme.primary
        return Button {
            coordinator.selectTab(tab)
        } label: {
            Text(title)
                .font(.caption.weight(.black))
                .tracking(0.8)
                .foregroundStyle(selected ? Color.black : BrumTheme.text)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(selected ? accent : BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? accent : BrumTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func speciesRow(_ entry: PokedexProjectedEntry) -> some View {
        let isSelected = coordinator.selectedEntry?.nationalDexNumber == entry.nationalDexNumber
        let mode: PokedexSpriteRenderMode = !entry.discovered
            ? .silhouette
            : (entry.isShiny ? .shiny : .normal)
        let accentColor: Color = entry.isShiny && entry.discovered
            ? Color(red: 1.0, green: 0.84, blue: 0.25)
            : BrumTheme.primary

        return Button {
            coordinator.selectedDexNumber = entry.nationalDexNumber
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? accentColor : BrumTheme.line, lineWidth: 1)
                        )
                    PokedexSpeciesImage(nationalDexNumber: entry.nationalDexNumber, mode: mode)
                        .frame(width: 34, height: 34)
                }
                .frame(width: 44, height: 44)

                Text("#\(entry.formattedNumber)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(entry.discovered ? accentColor : BrumTheme.muted)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.discovered ? entry.name : PokedexUniversalStore.unknownText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(entry.discovered ? BrumTheme.text : BrumTheme.muted)
                    if entry.discovered, let capture = entry.capture {
                        Text("\(capture.firstCapturedGame) · \(capture.captureLocation)")
                            .font(.caption2)
                            .foregroundStyle(BrumTheme.muted)
                            .lineLimit(1)
                    } else {
                        Text("Silhueta · Não capturado")
                            .font(.caption2)
                            .foregroundStyle(BrumTheme.muted.opacity(0.75))
                    }
                }

                Spacer(minLength: 4)

                if entry.discovered {
                    Text(entry.isShiny ? "✦ SHINY" : "CAPTURADO")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(entry.isShiny ? Color.black : accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            entry.isShiny ? accentColor : accentColor.opacity(0.14),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? accentColor.opacity(0.14) : BrumTheme.elevated,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accentColor : BrumTheme.line, lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pokedex-row-\(entry.formattedNumber)")
    }

    private var pokedexBackupSheet: some View {
        NavigationStack {
            Form {
                Section("Backup Verificado SHA-256 da Pokédex Universal") {
                    Text("O pacote JSON abaixo inclui todos os registros permanentes (normais e shinies) do seu perfil com verificação de integridade SHA-256 para sobreviver à reinstalação do aplicativo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Copiar Backup JSON") {
                        UIPasteboard.general.string = backupJSONText
                        backupMessage = "Backup copiado para a área de transferência."
                    }
                    Button("Restaurar do JSON abaixo") {
                        do {
                            guard let data = backupJSONText.data(using: .utf8) else {
                                throw PokedexUniversalError.invalidBackup("JSON inválido.")
                            }
                            let bundle = try JSONDecoder().decode(PokedexBackupBundle.self, from: data)
                            let merged = try coordinator.store.restoreBackup(profileID: coordinator.profileID, bundle: bundle)
                            coordinator.reload()
                            backupMessage = "Backup restaurado com sucesso (\(merged.totalRecords) registros verificados)."
                        } catch {
                            backupMessage = error.localizedDescription
                        }
                    }
                    if !backupMessage.isEmpty {
                        Text(backupMessage)
                            .font(.caption)
                            .foregroundStyle(BrumTheme.primary)
                    }
                }
                Section("Conteúdo JSON (SHA-256)") {
                    TextEditor(text: $backupJSONText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("Backup da Pokédex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { showBackupSheet = false }
                }
            }
        }
    }

    static func formatCaptureTimestamp(_ iso: String) -> String {
        guard !iso.isEmpty else { return "Data desconhecida" }
        let clean = iso.replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: " UTC")
        if let dotRange = clean.range(of: ".") {
            return String(clean[..<dotRange.lowerBound]) + " UTC"
        }
        return clean
    }
}
