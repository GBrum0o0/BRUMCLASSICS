import SwiftUI

enum IntegratedEmulatorSupport {
    static let supportedExtensions: Set<String> = ["gb", "gbc", "gba"]

    static func supports(_ rom: ROMFolderGame) -> Bool {
        supportedExtensions.contains((rom.filename as NSString).pathExtension.lowercased())
    }

    static func routeLabel(_ rom: ROMFolderGame) -> String {
        supports(rom) ? "JOGAR · BRUM CORE" : "JOGAR · RETROARCH"
    }
}

struct IntegratedEmulatorView: View {
    @EnvironmentObject private var pocket: PocketClassicsStore
    @EnvironmentObject private var launcher: AppStore
    @Environment(\.dismiss) private var dismiss
    let rom: ROMFolderGame
    @State private var stagedURL: URL?
    @State private var failure = ""
    @State private var finishing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let stagedURL {
                BrumLibretroController(romURL: stagedURL, title: rom.title, onExit: finish)
                    .ignoresSafeArea()
            } else if !failure.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                    Text("NÃO FOI POSSÍVEL INICIAR").font(.headline.bold()).foregroundStyle(.white)
                    Text(failure).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: 520)
                    Button("VOLTAR") { dismiss() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 240)
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
        .task {
            do { stagedURL = try await pocket.prepareIntegratedROM(rom, launcher: launcher) }
            catch { failure = error.localizedDescription }
        }
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
    let romURL: URL
    let title: String
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        BrumLibretroViewController(romurl: romURL, title: title, onExit: onExit)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
