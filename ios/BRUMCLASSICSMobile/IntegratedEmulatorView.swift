import SwiftUI

enum IntegratedEmulatorSupport {
    static func supports(_ rom: ROMFolderGame) -> Bool {
        core(for: rom) != nil
    }

    static func core(for rom: ROMFolderGame) -> CoreDescriptor? {
        let system: EmulatedSystemID?
        switch (rom.filename as NSString).pathExtension.lowercased() {
        case "gb": system = .gameBoy
        case "gbc": system = .gameBoyColor
        case "gba": system = .gameBoyAdvance
        default: system = nil
        }
        return system.flatMap(CoreRegistry.core(for:))
    }

    static func routeLabel(_ rom: ROMFolderGame) -> String {
        core(for: rom).map { "JOGAR · BRUM CORE · \($0.displayName.uppercased())" } ?? "JOGAR · RETROARCH"
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
            saveIdentifier: launch.saveIdentifier,
            legacySaveBasename: launch.legacySaveBasename,
            onExit: onExit
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
