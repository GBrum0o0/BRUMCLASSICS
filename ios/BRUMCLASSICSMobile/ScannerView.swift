import SwiftUI
import AVFoundation

struct PairingScannerView: UIViewControllerRepresentable {
    let onCode: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        controller.onError = onError
        return controller
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((URL) -> Void)?
    var onError: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var completed = false

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async { granted ? self?.configure() : self?.onError?("Permita o uso da câmera para ler o QR Code.") }
        }
    }

    private func configure() {
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { onError?("Câmera indisponível."); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { onError?("Leitor de QR Code indisponível."); return }
        session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer); preview = layer
        let frame = CAShapeLayer(); frame.borderColor = UIColor(red: 0.616, green: 1, blue: 0.231, alpha: 1).cgColor; frame.borderWidth = 3; frame.cornerRadius = 18; frame.frame = CGRect(x: 48, y: 150, width: view.bounds.width - 96, height: view.bounds.width - 96); view.layer.addSublayer(frame)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); if session.isRunning { session.stopRunning() } }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed, let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let raw = code.stringValue, let url = URL(string: raw), PairingPayload(url: url) != nil else { return }
        completed = true; session.stopRunning(); AppHaptics.success(); onCode?(url)
    }
}
