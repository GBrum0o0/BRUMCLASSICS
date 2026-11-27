import AudioToolbox
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

    private static func cacheKey(for dex: Int, mode: PokedexSpriteRenderMode) -> NSString {
        let clamped = max(1, min(809, dex))
        let modeTag: String
        switch mode {
        case .silhouette: modeTag = "silhouette"
        case .normal: modeTag = "normal"
        case .shiny: modeTag = "shiny"
        }
        return "\(modeTag):\(clamped)" as NSString
    }

    /// Rasterizes a pure #000000 black RGBA silhouette using the exact alpha channel of the species sprite.
    static func silhouette(_ image: UIImage) -> UIImage {
        let pixelWidth = image.cgImage?.width ?? max(1, Int((image.size.width * image.scale).rounded()))
        let pixelHeight = image.cgImage?.height ?? max(1, Int((image.size.height * image.scale).rounded()))
        let rect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image.withTintColor(.black, renderingMode: .alwaysOriginal)
        }
        ctx.clear(rect)
        if let cgImage = image.cgImage {
            ctx.draw(cgImage, in: rect)
            ctx.setBlendMode(.sourceIn)
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(rect)
        }
        guard let outCG = ctx.makeImage() else {
            return image.withTintColor(.black, renderingMode: .alwaysOriginal)
        }
        return UIImage(cgImage: outCG, scale: image.scale, orientation: .up).withRenderingMode(.alwaysOriginal)
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
        let renderCacheKey = cacheKey(for: dex, mode: mode)
        if let cached = cache.object(forKey: renderCacheKey) {
            return cached
        }
        let (folder, file) = cacheFileURL(for: dex, mode: mode)
        let diskImage: UIImage? = await Task.detached(priority: highPriority ? .userInitiated : .utility) {
            guard let data = try? Data(contentsOf: file), let img = UIImage(data: data) else { return nil }
            return mode == .silhouette ? silhouette(img) : img.withRenderingMode(.alwaysOriginal)
        }.value
        if Task.isCancelled { return nil }
        if let diskImage {
            cache.setObject(diskImage, forKey: renderCacheKey, cost: Int(diskImage.size.width * diskImage.size.height * 4))
            return diskImage
        }
        let session = highPriority ? highPrioritySession : thumbSession
        let request = URLRequest(url: address, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        do {
            let (data, response) = try await session.data(for: request)
            if Task.isCancelled { return nil }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url?.host == "raw.githubusercontent.com",
                  data.count <= 1_048_576, let rawImage = UIImage(data: data),
                  rawImage.size.width <= 1024, rawImage.size.height <= 1024 else {
                return nil
            }
            let rendered = mode == .silhouette ? silhouette(rawImage) : rawImage.withRenderingMode(.alwaysOriginal)
            cache.setObject(rendered, forKey: renderCacheKey, cost: Int(rendered.size.width * rendered.size.height * 4))
            Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
            }
            return rendered
        } catch {
            return nil
        }
    }
    @discardableResult
    static func load(for dex: Int, mode: PokedexSpriteRenderMode, highPriority: Bool = false,
                     completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let address = url(for: dex, mode: mode)
        let renderCacheKey = cacheKey(for: dex, mode: mode)
        let deliver: (UIImage?) -> Void = { rendered in
            DispatchQueue.main.async {
                completion(rendered)
            }
        }
        if let image = cache.object(forKey: renderCacheKey) { deliver(image); return nil }
        let (folder, file) = cacheFileURL(for: dex, mode: mode)
        if let data = try? Data(contentsOf: file), let rawImage = UIImage(data: data) {
            let rendered = mode == .silhouette ? silhouette(rawImage) : rawImage.withRenderingMode(.alwaysOriginal)
            cache.setObject(rendered, forKey: renderCacheKey, cost: Int(rendered.size.width * rendered.size.height * 4))
            deliver(rendered); return nil
        }
        let request = URLRequest(url: address, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        let session = highPriority ? highPrioritySession : thumbSession
        let task = session.dataTask(with: request) { data, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url?.host == "raw.githubusercontent.com",
                  let data, data.count <= 1_048_576, let rawImage = UIImage(data: data),
                  rawImage.size.width <= 1024, rawImage.size.height <= 1024 else {
                deliver(nil); return
            }
            let rendered = mode == .silhouette ? silhouette(rawImage) : rawImage.withRenderingMode(.alwaysOriginal)
            cache.setObject(rendered, forKey: renderCacheKey, cost: Int(rendered.size.width * rendered.size.height * 4))
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            deliver(rendered)
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
                Image(uiImage: image)
                    .renderingMode(.original)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
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
    @State private var showToolsSheet = false
    @State private var backupJSONText = ""
    @State private var backupMessage = ""
    @State private var lidOpenProgress: Double = 0
    @State private var ledStage: Int = 0
    @State private var openingPulse: Bool = false
    @State private var screenPowerOn: Bool = false

    private let hardwareClick: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if !coordinator.isExtensionEnabled {
                disabledExtensionCard
            } else if !coordinator.isDeviceOpen {
                closedKantoPokedexDevice
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                openKantoPokedexView
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .onAppear {
            coordinator.reload()
            if coordinator.isDeviceOpen {
                lidOpenProgress = 1
                ledStage = 3
                screenPowerOn = true
            }
            if appStore.connection == .online {
                Task { await coordinator.syncWithLauncher(appStore) }
            }
        }
        .sheet(isPresented: $showToolsSheet) {
            pokedexToolsSheet
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBackupSheet) {
            pokedexBackupSheet
                .preferredColorScheme(.dark)
        }
    }

    private func triggerHardwareFeedback(chime: SystemSoundID = 1104) {
        hardwareClick.impactOccurred()
        AudioServicesPlaySystemSound(chime)
    }

    private func openPokedexDevice() {
        triggerHardwareFeedback(chime: 1114)
        openingPulse = true
        withAnimation(.easeOut(duration: 0.12)) { ledStage = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.12)) { ledStage = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            lidOpenProgress = 0.18
            screenPowerOn = false
            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                coordinator.isDeviceOpen = true
            }
            withAnimation(.spring(response: 0.50, dampingFraction: 0.76)) {
                lidOpenProgress = 1.0
                ledStage = 3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                openingPulse = false
                withAnimation(.easeIn(duration: 0.22)) {
                    screenPowerOn = true
                }
            }
        }
    }

    private func closePokedexDevice() {
        triggerHardwareFeedback(chime: 1105)
        withAnimation(.easeOut(duration: 0.14)) {
            screenPowerOn = false
            ledStage = 1
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            lidOpenProgress = 0.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeInOut(duration: 0.18)) {
                coordinator.isDeviceOpen = false
                ledStage = 0
                lidOpenProgress = 0
            }
        }
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
                    Text("Seus registros permanentes continuam preservados neste perfil.")
                        .font(.caption)
                        .foregroundStyle(BrumTheme.muted)
                }
                Spacer()
                Button("Reativar") {
                    coordinator.setExtensionEnabled(true)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: - Closed Kanto Gen-1 Pokédex (Extensions Tab Entry — Item 04)
    private var closedKantoPokedexDevice: some View {
        Button {
            openPokedexDevice()
        } label: {
            HStack(spacing: 0) {
                ZStack {
                    KantoPlasticBody(corners: [.topLeft, .bottomLeft], cornerRadius: 18)

                    VStack(spacing: 0) {
                        // Stepped Kanto top cap with diagonal notch
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.92, green: 0.24, blue: 0.26),
                                            Color(red: 0.81, green: 0.10, blue: 0.13)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            KantoSteppedCornerOverlay()
                                .fill(Color(red: 0.67, green: 0.07, blue: 0.10))
                                .frame(width: 72, height: 18)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .overlay(alignment: .bottomTrailing) {
                                    KantoSteppedCornerStroke()
                                        .stroke(Color(red: 0.48, green: 0.04, blue: 0.06), lineWidth: 2)
                                        .frame(width: 72, height: 18)
                                }

                            HStack(alignment: .top, spacing: 10) {
                                KantoOpticalBlueLens(size: 40, pulsing: openingPulse)
                                KantoStatusLEDs(litStage: openingPulse ? 3 : 1, dotSize: 8)
                                    .padding(.top, 4)
                            }
                            .padding(.leading, 14)
                            .padding(.top, 11)
                        }
                        .frame(height: 62)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color(red: 0.48, green: 0.04, blue: 0.06))
                                .frame(height: 2)
                        }

                        // Front red casing with specular highlight, yellow latch triangle, and bottom grooves
                        ZStack {
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.11))
                                    .frame(width: 5)
                                    .padding(.vertical, 12)
                                    .padding(.leading, 8)
                                Spacer()
                            }

                            HStack {
                                KantoRightTriangleShape()
                                    .fill(Color(red: 0.98, green: 0.80, blue: 0.09))
                                    .frame(width: 17, height: 22)
                                    .shadow(color: Color(red: 0.25, green: 0.02, blue: 0.03).opacity(0.75), radius: 2, y: 1.5)
                                    .padding(.leading, 14)
                                Spacer()
                            }

                            VStack(spacing: 5) {
                                Spacer()
                                Capsule()
                                    .fill(Color(red: 0.48, green: 0.04, blue: 0.06))
                                    .frame(height: 2)
                                    .padding(.horizontal, 26)
                                Capsule()
                                    .fill(Color(red: 0.56, green: 0.05, blue: 0.08))
                                    .overlay(Capsule().stroke(Color(red: 0.36, green: 0.02, blue: 0.04), lineWidth: 1))
                                    .frame(height: 9)
                                    .padding(.horizontal, 18)
                            }
                            .padding(.bottom, 14)
                        }
                    }
                    .clipShape(KantoRoundedRect(corners: [.topLeft, .bottomLeft], radius: 18))
                }
                .frame(width: 158, height: 236)

                KantoCylindricalHinge(knuckleCount: 4)
                    .frame(width: 20, height: 236)
            }
            .shadow(color: .black.opacity(0.58), radius: 16, y: 10)
        }
        .buttonStyle(KantoTactileButtonStyle())
        .accessibilityLabel("Pokédex Universal")
        .accessibilityHint("Toque para abrir a Pokédex")
        .accessibilityIdentifier("pokedex-open-device")
    }

    // MARK: - Open Kanto Gen-1 Pokédex Split View (Item 02)
    private var openKantoPokedexView: some View {
        HStack(spacing: 0) {
            leftKantoShell
                .frame(maxWidth: .infinity)

            KantoCylindricalHinge(knuckleCount: 5)
                .frame(width: 18)

            rightKantoFlipCover
                .frame(maxWidth: .infinity)
                .rotation3DEffect(
                    .degrees((1.0 - lidOpenProgress) * -76.0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.42
                )
        }
        .frame(maxWidth: 880)
        .frame(height: 368)
        .shadow(color: .black.opacity(0.62), radius: 18, y: 10)
    }

    private func navigateSpecies(_ delta: Int) {
        triggerHardwareFeedback(chime: 1104)
        let entries = coordinator.displayedEntries
        guard !entries.isEmpty else { return }
        let index = entries.firstIndex { $0.nationalDexNumber == coordinator.selectedDexNumber } ?? 0
        coordinator.selectedDexNumber = entries[(index + delta + entries.count) % entries.count].nationalDexNumber
    }

    // MARK: Left Half (Top Lens + Chamfered Gray Bezel Specimen Monitor + Physical Controls & D-Pad)
    private var leftKantoShell: some View {
        let entry = coordinator.selectedEntry
        return ZStack {
            KantoPlasticBody(corners: [.topLeft, .bottomLeft], cornerRadius: 18)

            VStack(spacing: 8) {
                // Stepped Kanto Header
                HStack(alignment: .center, spacing: 10) {
                    KantoOpticalBlueLens(size: 36, pulsing: ledStage >= 3)
                    KantoStatusLEDs(litStage: ledStage, dotSize: 8)
                    Spacer()
                    Button {
                        triggerHardwareFeedback()
                        if let bundle = try? coordinator.store.exportBackup(profileID: coordinator.profileID),
                           let data = try? JSONEncoder().encode(bundle),
                           let text = String(data: data, encoding: .utf8) {
                            backupJSONText = text
                        }
                        showToolsSheet = true
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.03, blue: 0.05))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(KantoTactileButtonStyle())
                    .accessibilityLabel("Opções e sincronização da Pokédex")
                    .accessibilityIdentifier("pokedex-sync-pc")
                }
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(red: 0.48, green: 0.04, blue: 0.06)).frame(height: 2)
                }

                // Chamfered Light-Gray Inner Screen Bezel
                ZStack {
                    KantoChamferedBezelShape(chamfer: 18, cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.91, blue: 0.94),
                                    Color(red: 0.78, green: 0.82, blue: 0.87),
                                    Color(red: 0.59, green: 0.65, blue: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            KantoChamferedBezelShape(chamfer: 18, cornerRadius: 10)
                                .stroke(Color(red: 0.32, green: 0.38, blue: 0.45), lineWidth: 1.5)
                        )

                    VStack(spacing: 5) {
                        // Top twin tiny red indicator dots
                        HStack(spacing: 14) {
                            Circle().fill(Color(red: 0.86, green: 0.16, blue: 0.16)).frame(width: 5, height: 5)
                            Circle().fill(Color(red: 0.86, green: 0.16, blue: 0.16)).frame(width: 5, height: 5)
                        }
                        .padding(.top, 5)

                        // Electronic Specimen LCD Display
                        leftSpecimenScreen(entry: entry)
                            .padding(.horizontal, 10)

                        // Bottom Bezel Red LED + Speaker Slits
                        HStack {
                            Circle()
                                .fill(Color(red: 0.88, green: 0.14, blue: 0.14))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color(red: 0.35, green: 0.04, blue: 0.04), lineWidth: 1))
                            Spacer()
                            VStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Capsule()
                                        .fill(Color(red: 0.24, green: 0.29, blue: 0.35))
                                        .frame(width: 24, height: 1.8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 5)
                    }
                }
                .padding(.horizontal, 12)

                // Lower Left Physical Controls (Dark Close Button + R/B Pills + Olive Mini-LCD + Cross D-Pad)
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        closePokedexDevice()
                    } label: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.26, green: 0.31, blue: 0.38), Color(red: 0.07, green: 0.09, blue: 0.13)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .overlay(Image(systemName: "xmark").font(.system(size: 10, weight: .black)).foregroundStyle(.white.opacity(0.72)))
                    }
                    .buttonStyle(KantoTactileButtonStyle())
                    .accessibilityLabel("Fechar Pokédex")
                    .accessibilityIdentifier("pokedex-close-device")

                    VStack(spacing: 5) {
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color(red: 0.90, green: 0.20, blue: 0.20))
                                .overlay(Capsule().stroke(Color(red: 0.45, green: 0.04, blue: 0.04), lineWidth: 1))
                                .frame(width: 30, height: 6)
                            Capsule()
                                .fill(Color(red: 0.12, green: 0.65, blue: 0.94))
                                .overlay(Capsule().stroke(Color(red: 0.04, green: 0.28, blue: 0.45), lineWidth: 1))
                                .frame(width: 30, height: 6)
                        }

                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.42, green: 0.63, blue: 0.35), Color(red: 0.30, green: 0.48, blue: 0.24)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.16, green: 0.28, blue: 0.12), lineWidth: 1.5))
                            .overlay {
                                HStack {
                                    Text(coordinator.isSyncing ? "SYNC…" : (entry?.discovered == true ? "REGISTRADO" : "SILHUETA"))
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                    Spacer()
                                    Text("#\(entry?.formattedNumber ?? "---")")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                }
                                .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.04))
                                .padding(.horizontal, 7)
                                .opacity(screenPowerOn ? 1 : 0.15)
                            }
                    }

                    KantoCrossDPad(
                        onPrevious: { navigateSpecies(-1) },
                        onNext: { navigateSpecies(1) }
                    )
                    .accessibilityIdentifier("pokedex-device-controls")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func leftSpecimenScreen(entry: PokedexProjectedEntry?) -> some View {
        let discovered = entry?.discovered == true
        let isShiny = entry?.isShiny == true && discovered
        let lcdFill: Color = discovered
            ? Color(red: 0.06, green: 0.11, blue: 0.10)
            : Color(red: 0.61, green: 0.73, blue: 0.62)
        let primaryInk: Color = discovered ? Color(red: 0.94, green: 0.97, blue: 0.96) : Color(red: 0.07, green: 0.11, blue: 0.08)
        let secondaryInk: Color = discovered ? Color(red: 0.68, green: 0.78, blue: 0.75) : Color(red: 0.15, green: 0.22, blue: 0.17)
        let badgeAccent: Color = isShiny ? Color(red: 1.0, green: 0.84, blue: 0.25) : (discovered ? BrumTheme.primary : Color(red: 0.12, green: 0.18, blue: 0.14))

        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(screenPowerOn ? lcdFill : Color(red: 0.06, green: 0.08, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.22, green: 0.27, blue: 0.32), lineWidth: 1.5))

            if let entry {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(discovered ? Color.black.opacity(0.28) : Color.black.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.22), lineWidth: 1))
                                PokedexSpeciesImage(
                                    nationalDexNumber: entry.nationalDexNumber,
                                    mode: !entry.discovered ? .silhouette : (entry.isShiny ? .shiny : .normal),
                                    highPriority: true,
                                    interactiveRetry: true
                                )
                                .frame(width: 68, height: 68)
                                .accessibilityIdentifier("pokedex-detail-sprite")
                            }
                            .frame(width: 78, height: 78)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("#\(entry.formattedNumber)")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(discovered ? badgeAccent : primaryInk)
                                    Spacer(minLength: 2)
                                    Text(discovered ? (isShiny ? "✦ SHINY" : "CAPTURADO") : "SILHUETA")
                                        .font(.system(size: 8, weight: .heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            discovered ? badgeAccent.opacity(isShiny ? 1 : 0.20) : Color.black.opacity(0.14),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isShiny ? Color.black : (discovered ? badgeAccent : primaryInk))
                                }

                                Text(discovered ? entry.name : PokedexUniversalStore.unknownText)
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(primaryInk)
                                    .lineLimit(1)
                                    .accessibilityIdentifier("pokedex-detail-name")

                                Text(discovered ? entry.genus : PokedexUniversalStore.unknownText)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(secondaryInk)
                                    .lineLimit(1)

                                if discovered {
                                    HStack(spacing: 4) {
                                        ForEach(entry.types, id: \.self) { typeName in
                                            Text(typeName)
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Color.white.opacity(0.14), in: Capsule())
                                                .foregroundStyle(primaryInk)
                                        }
                                        if let h = entry.heightMeters, let w = entry.weightKg {
                                            Text(String(format: "%.1fm · %.1fkg", h, w))
                                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(secondaryInk)
                                        }
                                    }
                                    .accessibilityIdentifier("pokedex-detail-traits")
                                }
                            }
                        }

                        Rectangle()
                            .fill(discovered ? Color.white.opacity(0.12) : Color.black.opacity(0.15))
                            .frame(height: 1)

                        Text(discovered ? entry.description : PokedexUniversalStore.unknownText)
                            .font(.system(size: 10, weight: discovered ? .medium : .bold))
                            .foregroundStyle(discovered ? primaryInk.opacity(0.94) : secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pokedex-detail-description")

                        if discovered, let capture = entry.capture {
                            VStack(alignment: .leading, spacing: 2) {
                                detailRowLCD(label: "JOGO", value: capture.firstCapturedGame, ink: secondaryInk, valueInk: badgeAccent)
                                detailRowLCD(label: "DATA", value: Self.formatCaptureTimestamp(capture.capturedAt), ink: secondaryInk, valueInk: primaryInk)
                                detailRowLCD(
                                    label: "LOCAL",
                                    value: capture.captureLocation.isEmpty ? PokedexUniversalStore.unknownLocation : capture.captureLocation,
                                    ink: secondaryInk,
                                    valueInk: primaryInk
                                )
                            }
                            .padding(.top, 2)
                            .accessibilityIdentifier("pokedex-detail-capture-info")
                        } else {
                            Text("Informações e características ocultas até a captura confirmada.")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(secondaryInk)
                                .accessibilityIdentifier("pokedex-detail-capture-hidden")
                        }
                    }
                    .padding(8)
                }
                .opacity(screenPowerOn ? 1 : 0)
            } else {
                Text("Nenhuma espécie")
                    .font(.caption.bold())
                    .foregroundStyle(BrumTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 214)
    }

    private func detailRowLCD(label: String, value: String, ink: Color, valueInk: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(ink)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(valueInk)
                .lineLimit(1)
        }
    }

    // MARK: Right Flip Cover (NO G1–G7 bar — Expanded Scrollable List + Ivory Pokémon/Shiny Keys + Counters)
    private var rightKantoFlipCover: some View {
        let entries = coordinator.displayedEntries
        return ZStack {
            KantoPlasticBody(corners: [.topRight, .bottomRight], cornerRadius: 18)

            VStack(spacing: 10) {
                // Mirrored subtle stepped top notch edge
                HStack(spacing: 0) {
                    Color(red: 0.62, green: 0.06, blue: 0.09)
                        .frame(height: 14)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color(red: 0.45, green: 0.04, blue: 0.06)).frame(height: 1.5)
                        }
                }

                // Expanded Electronic LCD List Screen + Compact Search
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.64))
                        TextField("#025 ou nome capturado…", text: $coordinator.searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("pokedex-search-field")
                        if !coordinator.searchQuery.isEmpty {
                            Button {
                                coordinator.searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))

                    if entries.isEmpty {
                        VStack(spacing: 4) {
                            Text("Nenhuma espécie encontrada")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                            Text("Busque pelo nº oficial (#001, #025) ou nome capturado.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 5) {
                                    ForEach(entries) { entry in
                                        speciesRow(entry)
                                            .id(entry.nationalDexNumber)
                                    }
                                }
                            }
                            .onChange(of: coordinator.selectedDexNumber) { nextDex in
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    proxy.scrollTo(nextDex, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.04, green: 0.08, blue: 0.09), Color(red: 0.07, green: 0.12, blue: 0.14)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(red: 0.16, green: 0.22, blue: 0.28), lineWidth: 2))
                .padding(.horizontal, 12)
                .opacity(screenPowerOn ? 1 : 0.25)

                // Ivory-White Tactile Pokémon / Shinies Buttons + Twin Dark Pills + Amber Indicator Light
                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 8) {
                        kantoIvoryTabButton(
                            tab: .pokemon,
                            title: "POKÉMON",
                            identifier: "pokedex-tab-pokemon"
                        )
                        kantoIvoryTabButton(
                            tab: .shinies,
                            title: "✦ SHINIES",
                            identifier: "pokedex-tab-shinies"
                        )
                    }

                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 4) {
                            Capsule().fill(Color(red: 0.10, green: 0.12, blue: 0.16)).frame(width: 18, height: 4)
                            Capsule().fill(Color(red: 0.10, green: 0.12, blue: 0.16)).frame(width: 18, height: 4)
                        }
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(red: 1.0, green: 0.96, blue: 0.65), Color(red: 0.98, green: 0.78, blue: 0.12), Color(red: 0.68, green: 0.42, blue: 0.02)],
                                    center: .topLeading,
                                    startRadius: 1,
                                    endRadius: 10
                                )
                            )
                            .frame(width: 15, height: 15)
                            .overlay(Circle().stroke(Color(red: 0.42, green: 0.24, blue: 0.02), lineWidth: 1))
                            .shadow(color: Color(red: 0.98, green: 0.80, blue: 0.15).opacity(ledStage >= 3 ? 0.85 : 0.2), radius: 5)
                    }
                }
                .padding(.horizontal, 12)

                // Twin Recessed Bottom Electronic Counter Windows
                HStack(spacing: 8) {
                    kantoCounterWindow(
                        label: "NORMAIS",
                        value: "\(coordinator.projectedView.summary.normalDiscovered)/\(coordinator.projectedView.summary.normalAvailableTotal)",
                        tint: BrumTheme.primary
                    )
                    kantoCounterWindow(
                        label: "SHINIES",
                        value: "\(coordinator.projectedView.summary.shinyDiscovered)",
                        tint: Color(red: 1.0, green: 0.84, blue: 0.25)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .clipShape(KantoRoundedRect(corners: [.topRight, .bottomRight], radius: 18))
        }
    }

    private func kantoIvoryTabButton(tab: PokedexDisplayTab, title: String, identifier: String) -> some View {
        let selected = coordinator.selectedTab == tab
        return Button {
            triggerHardwareFeedback(chime: 1104)
            coordinator.selectTab(tab)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .tracking(0.5)
                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.14))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    LinearGradient(
                        colors: selected
                            ? [Color(red: 1.0, green: 0.94, blue: 0.56), Color(red: 0.98, green: 0.80, blue: 0.15)]
                            : [Color.white, Color(red: 0.84, green: 0.87, blue: 0.91)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color(red: 0.62, green: 0.42, blue: 0.02) : Color(red: 0.40, green: 0.46, blue: 0.54), lineWidth: 1.4)
                )
                .shadow(color: Color(red: 0.25, green: 0.02, blue: 0.03).opacity(0.45), radius: 2, y: 1.5)
        }
        .buttonStyle(KantoTactileButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func kantoCounterWindow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 0.60, green: 0.68, blue: 0.72))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.05, green: 0.08, blue: 0.10), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.16, green: 0.22, blue: 0.28), lineWidth: 1.5))
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
            triggerHardwareFeedback(chime: 1104)
            coordinator.selectedDexNumber = entry.nationalDexNumber
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            entry.discovered
                                ? Color(red: 0.08, green: 0.13, blue: 0.16)
                                : Color(red: 0.56, green: 0.65, blue: 0.59)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.4), lineWidth: 1))
                    PokedexSpeciesImage(nationalDexNumber: entry.nationalDexNumber, mode: mode)
                        .frame(width: 26, height: 26)
                }
                .frame(width: 32, height: 32)

                Text("#\(entry.formattedNumber)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(entry.discovered ? accentColor : Color(red: 0.62, green: 0.68, blue: 0.72))

                Text(entry.discovered ? entry.name : PokedexUniversalStore.unknownText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(entry.discovered ? Color.white : Color(red: 0.65, green: 0.70, blue: 0.74))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if entry.discovered {
                    Text(entry.isShiny ? "✦" : "●")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected ? accentColor.opacity(0.18) : Color(red: 0.06, green: 0.10, blue: 0.12),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? accentColor : Color(red: 0.14, green: 0.20, blue: 0.24), lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pokedex-row-\(entry.formattedNumber)")
    }

    private var pokedexToolsSheet: some View {
        NavigationStack {
            Form {
                Section("Sincronização e Backup da Pokédex") {
                    Button(coordinator.isSyncing ? "Sincronizando…" : "Sincronizar coleção com o PC") {
                        Task { await coordinator.syncWithLauncher(appStore) }
                    }
                    .disabled(coordinator.isSyncing)

                    Button("Backup / Restauração SHA-256") {
                        showToolsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showBackupSheet = true
                        }
                    }

                    if !coordinator.syncFeedback.isEmpty {
                        Text(coordinator.syncFeedback)
                            .font(.caption)
                            .foregroundStyle(BrumTheme.primary)
                    }
                }

                Section("Extensão") {
                    Toggle("Ativar Pokédex Universal", isOn: Binding(
                        get: { coordinator.isExtensionEnabled },
                        set: { coordinator.setExtensionEnabled($0) }
                    ))
                    .tint(BrumTheme.primary)
                }
            }
            .navigationTitle("Opções da Pokédex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { showToolsSheet = false }
                }
            }
        }
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

// MARK: - Kanto Gen-1 Pokédex Hardware Visual Components

private struct KantoRoundedRect: Shape {
    let corners: UIRectCorner
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let bezier = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezier.cgPath)
    }
}

private struct KantoPlasticBody: View {
    let corners: UIRectCorner
    let cornerRadius: CGFloat

    var body: some View {
        KantoRoundedRect(corners: corners, radius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.21, blue: 0.23),
                        Color(red: 0.81, green: 0.09, blue: 0.13),
                        Color(red: 0.68, green: 0.06, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                KantoRoundedRect(corners: corners, radius: cornerRadius)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                    .padding(1.5)
            )
            .overlay(
                KantoRoundedRect(corners: corners, radius: cornerRadius)
                    .stroke(Color(red: 0.48, green: 0.04, blue: 0.06), lineWidth: 1.8)
            )
    }
}

private struct KantoCylindricalHinge: View {
    let knuckleCount: Int

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.54, green: 0.05, blue: 0.07), location: 0.0),
                            .init(color: Color(red: 0.88, green: 0.20, blue: 0.23), location: 0.28),
                            .init(color: Color(red: 0.95, green: 0.36, blue: 0.38), location: 0.48),
                            .init(color: Color(red: 0.71, green: 0.07, blue: 0.10), location: 0.78),
                            .init(color: Color(red: 0.42, green: 0.03, blue: 0.05), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(red: 0.40, green: 0.03, blue: 0.05)).frame(width: 1)
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color(red: 0.40, green: 0.03, blue: 0.05)).frame(width: 1)
                }

            VStack {
                ForEach(0..<knuckleCount, id: \.self) { index in
                    if index > 0 { Spacer() }
                    Rectangle()
                        .fill(Color(red: 0.26, green: 0.02, blue: 0.03).opacity(0.85))
                        .frame(height: 2)
                }
            }
            .padding(.vertical, 26)
        }
    }
}

private struct KantoOpticalBlueLens: View {
    let size: CGFloat
    let pulsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.96, blue: 0.97), Color(red: 0.80, green: 0.84, blue: 0.88), Color(red: 0.40, green: 0.46, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color(red: 0.28, green: 0.33, blue: 0.41), lineWidth: 1.5))

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.88, green: 0.97, blue: 1.0), location: 0.0),
                            .init(color: Color(red: 0.36, green: 0.88, blue: 1.0), location: 0.22),
                            .init(color: Color(red: 0.05, green: 0.65, blue: 0.91), location: 0.56),
                            .init(color: Color(red: 0.01, green: 0.41, blue: 0.63), location: 0.84),
                            .init(color: Color(red: 0.03, green: 0.18, blue: 0.29), location: 1.0)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 1,
                        endRadius: size * 0.44
                    )
                )
                .padding(size * 0.11)

            Ellipse()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.24, height: size * 0.14)
                .rotationEffect(.degrees(-25))
                .offset(x: -size * 0.14, y: -size * 0.15)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.22, green: 0.82, blue: 0.99).opacity(pulsing ? 0.9 : 0.45), radius: pulsing ? 10 : 5)
    }
}

private struct KantoStatusLEDs: View {
    let litStage: Int
    let dotSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            led(active: litStage >= 1, light: Color(red: 0.99, green: 0.78, blue: 0.78), mid: Color(red: 0.94, green: 0.27, blue: 0.27), dark: Color(red: 0.60, green: 0.11, blue: 0.11))
            led(active: litStage >= 2, light: Color(red: 0.99, green: 0.98, blue: 0.76), mid: Color(red: 0.98, green: 0.80, blue: 0.09), dark: Color(red: 0.63, green: 0.38, blue: 0.03))
            led(active: litStage >= 3, light: Color(red: 0.86, green: 0.99, blue: 0.90), mid: Color(red: 0.13, green: 0.77, blue: 0.37), dark: Color(red: 0.09, green: 0.40, blue: 0.20))
        }
    }

    private func led(active: Bool, light: Color, mid: Color, dark: Color) -> some View {
        Circle()
            .fill(RadialGradient(colors: [light, mid, dark], center: UnitPoint(x: 0.32, y: 0.30), startRadius: 0.5, endRadius: dotSize * 0.6))
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1))
            .shadow(color: active ? mid.opacity(0.85) : .clear, radius: active ? 4 : 0)
    }
}

private struct KantoCrossDPad: View {
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        let darkFill = LinearGradient(
            colors: [Color(red: 0.20, green: 0.25, blue: 0.33), Color(red: 0.06, green: 0.09, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        ZStack {
            VStack(spacing: 0) {
                Button(action: onPrevious) {
                    Color.clear.overlay(Rectangle().fill(darkFill)).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(KantoTactileButtonStyle())
                .frame(width: 18, height: 18)

                Rectangle().fill(Color(red: 0.12, green: 0.16, blue: 0.23)).frame(width: 18, height: 18)

                Button(action: onNext) {
                    Color.clear.overlay(Rectangle().fill(darkFill)).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(KantoTactileButtonStyle())
                .frame(width: 18, height: 18)
            }

            HStack(spacing: 0) {
                Button(action: onPrevious) {
                    ZStack {
                        Rectangle().fill(darkFill).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                        Image(systemName: "arrowtriangle.left.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .buttonStyle(KantoTactileButtonStyle())
                .frame(width: 18, height: 18)
                .accessibilityLabel("Espécie anterior")

                Circle()
                    .fill(Color(red: 0.07, green: 0.10, blue: 0.15))
                    .frame(width: 9, height: 9)
                    .frame(width: 18, height: 18)
                    .background(Color(red: 0.12, green: 0.16, blue: 0.23))

                Button(action: onNext) {
                    ZStack {
                        Rectangle().fill(darkFill).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .buttonStyle(KantoTactileButtonStyle())
                .frame(width: 18, height: 18)
                .accessibilityLabel("Próxima espécie")
            }
        }
        .frame(width: 54, height: 54)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
    }
}

private struct KantoChamferedBezelShape: Shape {
    let chamfer: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cornerRadius, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: cornerRadius), control: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: chamfer, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY - chamfer))
        p.addLine(to: CGPoint(x: 0, y: cornerRadius))
        p.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: .zero)
        p.closeSubpath()
        return p
    }
}

private struct KantoRightTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct KantoSteppedCornerOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 16, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct KantoSteppedCornerStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: 16, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        return p
    }
}

private struct KantoTactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
