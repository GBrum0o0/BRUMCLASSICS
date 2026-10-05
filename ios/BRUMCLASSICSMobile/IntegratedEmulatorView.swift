import SwiftUI

enum IntegratedEmulatorSupport {
    static func supports(_ rom: ROMFolderGame) -> Bool {
        core(for: rom) != nil
    }

    static func core(for rom: ROMFolderGame) -> CoreDescriptor? {
        system(for: rom).flatMap { CoreRegistry.core(for: $0) }
    }

    static func system(for rom: ROMFolderGame) -> EmulatedSystemID? {
        let ext = (rom.filename as NSString).pathExtension.lowercased()
        switch ext {
        case "gb": return .gameBoy
        case "gbc": return .gameBoyColor
        case "gba": return .gameBoyAdvance
        case "nds": return .nintendoDS
        case "neo": return .neoGeo
        case "sms": return .masterSystem
        case "gg": return .gameGear
        case "nes": return .nintendoEntertainmentSystem
        case "pce": return .pcEngine
        case "sfc", "smc": return .superNintendo
        case "ws": return .wonderSwan
        case "wsc": return .wonderSwanColor
        case "n64", "z64", "v64": return .nintendo64
        case "md", "gen", "smd": return .megaDrive
        case "32x": return .sega32X
        case "a26": return .atari2600
        case "gdi": return .dreamcast
        case "cso": return .playStationPortable
        case "3ds", "3dsx", "z3dsx", "cci", "zcci", "cxi", "zcxi": return .nintendo3DS
        case "rvz", "gcz": return .gameCube
        default: break
        }
        let folders = rom.relativePath.lowercased().replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").dropLast()
        // Nearest recognized directory wins, but only for a supported format.
        for folder in folders.reversed() {
            switch folder {
            case "ps1", "psx": return ["cue", "chd", "pbp", "m3u", "bin", "iso"].contains(ext) ? .playStation : nil
            case "ps2" where ["iso", "bin", "chd", "m3u"].contains(ext): return .playStation2
            case "saturn" where ["cue", "chd", "m3u"].contains(ext): return .saturn
            case "sega cd", "segacd", "mega cd", "megacd": return ["cue", "chd", "iso"].contains(ext) ? .segaCD : nil
            case "arcade", "fbneo", "mame": return ["zip", "7z"].contains(ext) ? .arcade : nil
            case "psp" where ["iso", "pbp"].contains(ext): return .playStationPortable
            case "dreamcast" where ["chd", "cdi", "m3u"].contains(ext): return .dreamcast
            case "3ds" where ["app", "elf", "axf"].contains(ext): return .nintendo3DS
            case "gamecube" where ["iso", "ciso", "gcm"].contains(ext): return .gameCube
            default: continue
            }
        }
        return nil
    }

    static func routeLabel(_ rom: ROMFolderGame) -> String {
        guard let core = core(for: rom) else { return "JOGAR · RETROARCH" }
        return CoreRegistry.experimental.contains(core) ? "TESTAR · BRUM CORE" : "JOGAR · BRUM CORE"
    }
}

struct IntegratedEmulatorView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var launcher: AppStore
    @Environment(\.dismiss) private var dismiss
    let rom: ROMFolderGame
    let returnsToPortrait: Bool
    @State private var launch: EmulationLaunchDescriptor?
    @State private var failure = ""
    @State private var finishing = false
    @State private var choosingROMFolder = false

    init(rom: ROMFolderGame, returnsToPortrait: Bool = true) {
        self.rom = rom
        self.returnsToPortrait = returnsToPortrait
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let launch {
                BrumLibretroController(launch: launch, onExit: finish)
                    .ignoresSafeArea()
            } else if !failure.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                    Text("NÃO FOI POSSÍVEL INICIAR").font(.headline.bold()).foregroundStyle(.white)
                    Text(failure).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: 520)
                    Button("VOLTAR") { dismiss() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 240)
                    Button("REAUTORIZAR PASTA") { choosingROMFolder = true }
                        .font(.caption.bold()).foregroundStyle(BrumTheme.primary)
                }.padding(30)
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(BrumTheme.primary).scaleEffect(1.25)
                    Text("PREPARANDO BRUM CORE").font(.caption.bold()).tracking(2).foregroundStyle(BrumTheme.primary)
                    Text("A ROM continua na pasta escolhida. Nenhuma importação para o RetroArch é necessária.")
                        .font(.caption).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.62)).frame(maxWidth: 440)
                }
            }
        }
        .onAppear { GamingOrientation.request(.landscape) }
        .onDisappear {
            if returnsToPortrait { GamingOrientation.request(.portrait) }
        }
        .task { await prepare() }
        .fileImporter(isPresented: $choosingROMFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let folder):
                Task {
                    await pocket.configureROMFolder(folder)
                    await prepare()
                }
            case .failure(let error): failure = error.localizedDescription
            }
        }
    }

    private func prepare() async {
        failure = ""
        launch = nil
        do { launch = try await pocket.prepareIntegratedROM(rom, launcher: launcher) }
        catch { failure = error.localizedDescription }
    }

    private func finish() {
        guard !finishing else { return }
        finishing = true
        Task {
            await pocket.finishIntegratedPlay(launcher: launcher)
            dismiss()
        }
    }
}

private struct BrumLibretroController: UIViewControllerRepresentable {
    let launch: EmulationLaunchDescriptor
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        BrumLibretroViewController(
            romurl: launch.romURL,
            title: launch.title,
            canonicalGameID: launch.identity.canonicalGameID,
            systemID: launch.identity.systemID.rawValue,
            contentSHA256: launch.identity.contentSHA256,
            coreID: launch.core.id,
            coreVersion: launch.core.version,
            coreDisplayName: launch.core.displayName,
            coreLibraryName: launch.core.libraryName,
            retroAchievementsGameID: launch.retroAchievementsGameID,
            saveIdentifier: launch.saveIdentifier,
            legacySaveBasename: launch.legacySaveBasename,
            onExit: onExit
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
