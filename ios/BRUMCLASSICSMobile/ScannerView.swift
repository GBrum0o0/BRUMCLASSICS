import SwiftUI
import AVFoundation

struct PairingScannerView: UIViewControllerRepresentable {
    var validator: ((URL) -> Bool)? = nil
    let onCode: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.validator = validator ?? { PairingPayload(url: $0) != nil }
        controller.onCode = onCode
        controller.onError = onError
        return controller
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var validator: ((URL) -> Bool)?
    var onCode: ((URL) -> Void)?
    var onError: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var overlayFrameLayer: CAShapeLayer?
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
        let frame = CAShapeLayer()
        frame.borderColor = UIColor(red: 0.616, green: 1, blue: 0.231, alpha: 1).cgColor
        frame.borderWidth = 3
        frame.cornerRadius = 18
        view.layer.addSublayer(frame)
        overlayFrameLayer = frame
        layoutScannerLayers()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    private func layoutScannerLayers() {
        let bounds = view.bounds
        preview?.frame = bounds
        if let connection = preview?.connection, connection.isVideoOrientationSupported {
            let interfaceOrientation = view.window?.windowScene?.interfaceOrientation
            switch interfaceOrientation {
            case .landscapeLeft: connection.videoOrientation = .landscapeLeft
            case .landscapeRight: connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
            default: connection.videoOrientation = .portrait
            }
        }
        let side = max(140, min(bounds.width, bounds.height) * 0.62)
        overlayFrameLayer?.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutScannerLayers()
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); if session.isRunning { session.stopRunning() } }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed, let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let raw = code.stringValue, let url = URL(string: raw), (validator?(url) ?? (PairingPayload(url: url) != nil)) else { return }
        completed = true; session.stopRunning(); AppHaptics.success(); onCode?(url)
    }
}
