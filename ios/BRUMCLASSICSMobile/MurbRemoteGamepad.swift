import CoreGraphics
import CoreImage.CIFilterBuiltins
import Foundation
import GameController
import SwiftUI
import UIKit

struct MurbPairingPayload: Codable, Equatable {
    var host: String
    var port: Int
    var token: String
    var system: String
    var session: String

    static func parse(_ url: URL) -> MurbPairingPayload? {
        guard url.scheme?.lowercased() == "murb",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        func query(_ name: String) -> String {
            items.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        let host = query("ip").isEmpty ? query("host") : query("ip")
        let token = query("token").uppercased()
        let rawPort = query("port")
        let parsedPort = rawPort.isEmpty ? 8089 : (Int(rawPort) ?? 0)
        guard !host.isEmpty, !token.isEmpty, (1...65535).contains(parsedPort) else { return nil }
        let querySystem = query("sys").lowercased()
        let hostSystem = url.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let resolved = !querySystem.isEmpty ? querySystem : (!hostSystem.isEmpty ? hostSystem : "ds")
        return MurbPairingPayload(
            host: host,
            port: parsedPort,
            token: token,
            system: MurbProtocol.normalizeSystem(resolved),
            session: query("session")
        )
    }

    init(host: String, port: Int = 8089, token: String, system: String = "ds", session: String = "") {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = port
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.system = MurbProtocol.normalizeSystem(system)
        self.session = session
    }

    var streamURL: URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = host
        components.port = port
        components.path = "/stream"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }

    static func resolve(from info: BridgeClient.MurbRemoteSessionInfo?, fallbackHost: String?, preferFallbackHost: Bool = false) -> MurbPairingPayload? {
        guard let info, info.available == true else { return nil }
        let cleanedFallback = (fallbackHost ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackUsable = !cleanedFallback.isEmpty && cleanedFallback != "127.0.0.1" && cleanedFallback != "0.0.0.0"
        if let rawQR = info.qrUri, let url = URL(string: rawQR), var parsed = parse(url) {
            if fallbackUsable && (preferFallbackHost || parsed.host.isEmpty || parsed.host == "127.0.0.1" || parsed.host == "0.0.0.0") {
                parsed.host = cleanedFallback
            }
            return parsed
        }
        let host = {
            if preferFallbackHost && fallbackUsable { return cleanedFallback }
            let candidate = (info.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty && candidate != "127.0.0.1" && candidate != "0.0.0.0" { return candidate }
            return cleanedFallback
        }()
        let token = (info.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let port = info.port ?? 8089
        guard !host.isEmpty, !token.isEmpty, (1...65535).contains(port) else { return nil }
        return MurbPairingPayload(
            host: host,
            port: port,
            token: token,
            system: MurbProtocol.normalizeSystem(info.system ?? "gamepad"),
            session: info.session ?? ""
        )
    }
}

struct MurbRemoteLaunchTarget: Identifiable {
    let id = UUID()
    let payload: MurbPairingPayload
    let gameTitle: String
    let playerNumber: Int
    let p2Payload: MurbPairingPayload?

    init(payload: MurbPairingPayload, gameTitle: String = "", playerNumber: Int = 1, p2Payload: MurbPairingPayload? = nil) {
        self.payload = payload
        self.gameTitle = gameTitle
        self.playerNumber = max(1, min(4, playerNumber))
        self.p2Payload = p2Payload
    }

    static func from(
        _ info: BridgeClient.MurbRemoteSessionInfo?,
        fallbackHost: String?,
        gameTitle: String,
        playerNumber: Int,
        preferFallbackHost: Bool = false
    ) -> MurbRemoteLaunchTarget? {
        guard let payload = MurbPairingPayload.resolve(from: info, fallbackHost: fallbackHost, preferFallbackHost: preferFallbackHost) else { return nil }
        var p2Payload: MurbPairingPayload?
        if let rawP2 = info?.p2QrUri, let urlP2 = URL(string: rawP2), var parsedP2 = MurbPairingPayload.parse(urlP2) {
            if !payload.host.isEmpty && (preferFallbackHost || parsedP2.host.isEmpty || parsedP2.host == "127.0.0.1" || parsedP2.host == "0.0.0.0") {
                parsedP2.host = payload.host
            }
            p2Payload = parsedP2
        }
        return MurbRemoteLaunchTarget(
            payload: payload,
            gameTitle: gameTitle,
            playerNumber: playerNumber,
            p2Payload: p2Payload
        )
    }
}

enum MurbProtocol {
    static let frameMagic: UInt32 = 0x4D55_5242 // 'MURB' little-endian
    static let buttonA = 0x0001
    static let buttonB = 0x0002
    static let buttonSelect = 0x0004
    static let buttonStart = 0x0008
    static let buttonRight = 0x0010
    static let buttonLeft = 0x0020
    static let buttonUp = 0x0040
    static let buttonDown = 0x0080
    static let buttonR = 0x0100
    static let buttonL = 0x0200
    static let buttonX = 0x0400
    static let buttonY = 0x0800
    static let buttonL2 = 0x1000
    static let buttonR2 = 0x2000
    static let buttonL3 = 0x4000
    static let buttonR3 = 0x8000

    struct DecodedFrame {
        let sequence: UInt32
        let width: Int
        let height: Int
        let image: CGImage
    }

    static func normalizeSystem(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch cleaned {
        case "nds", "nintendo_ds", "ds": return "ds"
        case "n3ds", "3ds", "citra", "azahar": return "3ds"
        case "wiiu", "cemu", "wii_u": return "wiiu"
        case "gc", "gamecube", "dolphin": return "gamecube"
        case "sfc", "snes": return "snes"
        case "psx", "ps1": return "ps1"
        case "": return "gamepad"
        default: return cleaned
        }
    }

    static func supportsDualScreen(_ system: String) -> Bool {
        let normalized = normalizeSystem(system)
        return normalized == "ds" || normalized == "3ds" || normalized == "wiiu"
    }

    static func hasAnalogStick(_ system: String) -> Bool {
        let normalized = normalizeSystem(system)
        return ["3ds", "n64", "gamecube", "wii", "wiiu", "ps1", "ps2", "psp", "dreamcast", "gamepad"].contains(normalized)
    }

    static func isPlayStation(_ system: String) -> Bool {
        let normalized = normalizeSystem(system)
        return normalized == "ps1" || normalized == "ps2" || normalized == "psp"
    }

    static func isTwoButtonClassic(_ system: String) -> Bool {
        let normalized = normalizeSystem(system)
        return ["nes", "gb", "gbc", "sms", "gg", "pce", "atari2600"].contains(normalized)
    }

    static func displaySystemName(_ system: String) -> String {
        switch normalizeSystem(system) {
        case "ds": return "Nintendo DS"
        case "3ds": return "Nintendo 3DS"
        case "wiiu": return "Nintendo Wii U"
        case "wii": return "Nintendo Wii"
        case "gamecube": return "GameCube"
        case "n64": return "Nintendo 64"
        case "snes": return "Super Nintendo"
        case "nes": return "NES"
        case "gba": return "Game Boy Advance"
        case "ps1": return "PlayStation"
        case "ps2": return "PlayStation 2"
        case "psp": return "PSP"
        case "md": return "Mega Drive"
        case "dreamcast": return "Dreamcast"
        default: return system.uppercased()
        }
    }

    static func decodeVideoFrame(_ data: Data) -> DecodedFrame? {
        guard data.count >= 16 else { return nil }
        func readLE16(_ offset: Int) -> UInt16 {
            UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        func readLE32(_ offset: Int) -> UInt32 {
            UInt32(data[offset])
                | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16)
                | (UInt32(data[offset + 3]) << 24)
        }
        let magic = readLE32(0)
        let sequence = readLE32(4)
        let width = Int(readLE16(8))
        let height = Int(readLE16(10))
        guard magic == frameMagic, width > 0, height > 0, width <= 1024, height <= 1024 else { return nil }
        let pixelCount = width * height
        guard data.count >= 16 + pixelCount * 2 else { return nil }

        var rgba = [UInt8](repeating: 255, count: pixelCount * 4)
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            let src = base.advanced(by: 16).assumingMemoryBound(to: UInt8.self)
            for index in 0..<pixelCount {
                let lo = UInt16(src[index * 2])
                let hi = UInt16(src[index * 2 + 1])
                let pixel = lo | (hi << 8)
                let r5 = (pixel >> 11) & 0x1F
                let g6 = (pixel >> 5) & 0x3F
                let b5 = pixel & 0x1F
                let out = index * 4
                rgba[out] = UInt8((r5 << 3) | (r5 >> 2))
                rgba[out + 1] = UInt8((g6 << 2) | (g6 >> 4))
                rgba[out + 2] = UInt8((b5 << 3) | (b5 >> 2))
                rgba[out + 3] = 255
            }
        }
        let cfData = Data(rgba) as CFData
        guard let provider = CGDataProvider(data: cfData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else { return nil }
        return DecodedFrame(sequence: sequence, width: width, height: height, image: image)
    }

    static func physicalControllerMask() -> (buttons: Int, stickX: Int, stickY: Int, deviceName: String?) {
        guard let controller = GCController.controllers().first(where: { !$0.isSnapshot }),
              let pad = controller.extendedGamepad else { return (0, 0, 0, nil) }
        var mask = 0
        if pad.buttonB.isPressed { mask |= buttonA }
        if pad.buttonA.isPressed { mask |= buttonB }
        if pad.buttonOptions?.isPressed == true { mask |= buttonSelect }
        if pad.buttonMenu.isPressed { mask |= buttonStart }
        if pad.dpad.right.isPressed { mask |= buttonRight }
        if pad.dpad.left.isPressed { mask |= buttonLeft }
        if pad.dpad.up.isPressed { mask |= buttonUp }
        if pad.dpad.down.isPressed { mask |= buttonDown }
        if pad.rightShoulder.isPressed { mask |= buttonR }
        if pad.leftShoulder.isPressed { mask |= buttonL }
        if pad.buttonY.isPressed { mask |= buttonX }
        if pad.buttonX.isPressed { mask |= buttonY }
        if pad.leftTrigger.isPressed || pad.leftTrigger.value > 0.25 { mask |= buttonL2 }
        if pad.rightTrigger.isPressed || pad.rightTrigger.value > 0.25 { mask |= buttonR2 }
        if pad.leftThumbstickButton?.isPressed == true { mask |= buttonL3 }
        if pad.rightThumbstickButton?.isPressed == true { mask |= buttonR3 }
        let stickX = Int((Double(pad.leftThumbstick.xAxis.value) * 32767.0).rounded())
        let stickY = Int((-Double(pad.leftThumbstick.yAxis.value) * 32767.0).rounded())
        return (mask, max(-32767, min(32767, stickX)), max(-32767, min(32767, stickY)), controller.vendorName ?? "Controle")
    }
}

@MainActor
final class MurbRemoteStore: ObservableObject {
    private static let savedPayloadKey = "brum_murb_remote_last_target_v1"
    private static let tokenAccount = "murb-remote-token-v1"

    @Published var lastTarget: MurbPairingPayload?

    init() {
        restore()
    }

    func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedPayloadKey),
              var decoded = try? JSONDecoder().decode(MurbPairingPayload.self, from: data) else { return }
        if decoded.token.isEmpty, let savedToken = SecureStore.read(Self.tokenAccount) {
            decoded.token = savedToken
        }
        if !decoded.host.isEmpty && !decoded.token.isEmpty {
            lastTarget = decoded
        }
    }

    func remember(_ payload: MurbPairingPayload) {
        var publicCopy = payload
        publicCopy.token = ""
        if let encoded = try? JSONEncoder().encode(publicCopy) {
            UserDefaults.standard.set(encoded, forKey: Self.savedPayloadKey)
        }
        try? SecureStore.write(payload.token, account: Self.tokenAccount)
        lastTarget = payload
    }
}

@MainActor
final class MurbRemoteSession: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var secondScreenImage: UIImage?
    @Published private(set) var fps = 0
    @Published private(set) var rttMs = 0
    @Published private(set) var activeSystem: String
    @Published private(set) var physicalControllerName: String?

    let target: MurbPairingPayload

    private let urlSession = URLSession(configuration: .ephemeral)
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var pollTimer: Timer?
    private var active = false
    private var frameCounter = 0
    private var lastFPSDate = Date()

    private var virtualButtons = 0
    private var virtualTouching = false
    private var virtualTouchX = 0
    private var virtualTouchY = 0
    private var virtualStickX = 0
    private var virtualStickY = 0
    private var lastSentSignature = ""

    init(target: MurbPairingPayload) {
        self.target = target
        self.activeSystem = target.system
    }

    func start() {
        active = true
        refreshPhysicalController()
        startPollTimer()
        connectSocket()
    }

    func stop() {
        active = false
        reconnectTask?.cancel(); reconnectTask = nil
        pollTimer?.invalidate(); pollTimer = nil
        sendNeutralInput()
        tearDownSocket()
        state = .disconnected
    }

    func reconnectNow() {
        reconnectTask?.cancel(); reconnectTask = nil
        tearDownSocket()
        connectSocket()
    }

    func updateVirtualInput(buttons: Int, touching: Bool, touchX: Int, touchY: Int, stickX: Int, stickY: Int) {
        virtualButtons = buttons
        virtualTouching = touching
        virtualTouchX = touchX
        virtualTouchY = touchY
        virtualStickX = stickX
        virtualStickY = stickY
        dispatchCombinedInput(force: false)
    }

    private func refreshPhysicalController() {
        physicalControllerName = GCController.controllers().first(where: { !$0.isSnapshot })?.vendorName
    }

    private func startPollTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                self.refreshPhysicalController()
                self.dispatchCombinedInput(force: false)
            }
        }
    }

    private func dispatchCombinedInput(force: Bool) {
        guard state == .connected, let task else { return }
        let physical = MurbProtocol.physicalControllerMask()
        let combinedButtons = virtualButtons | physical.buttons
        let stickX = abs(physical.stickX) > abs(virtualStickX) ? physical.stickX : virtualStickX
        let stickY = abs(physical.stickY) > abs(virtualStickY) ? physical.stickY : virtualStickY
        let signature = "\(combinedButtons)|\(virtualTouching ? 1 : 0)|\(virtualTouchX)|\(virtualTouchY)|\(stickX)|\(stickY)"
        guard force || signature != lastSentSignature else { return }
        lastSentSignature = signature
        let payload: [String: Any] = [
            "type": "input",
            "buttons": combinedButtons,
            "touching": virtualTouching,
            "x": virtualTouchX,
            "y": virtualTouchY,
            "stickX": stickX,
            "stickY": stickY
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: json, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func sendNeutralInput() {
        guard let task else { return }
        let payload = "{\"type\":\"input\",\"buttons\":0,\"touching\":false,\"x\":0,\"y\":0,\"stickX\":0,\"stickY\":0}"
        task.send(.string(payload)) { _ in }
    }

    private func tearDownSocket() {
        receiveTask?.cancel(); receiveTask = nil
        pingTask?.cancel(); pingTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func connectSocket() {
        guard active, let streamURL = target.streamURL else {
            state = .error("Endereço M.U.R.B inválido.")
            return
        }
        state = .connecting
        let socket = urlSession.webSocketTask(with: streamURL)
        task = socket
        socket.resume()
        state = .connected
        lastSentSignature = ""
        dispatchCombinedInput(force: true)
        let initPingMs = Int64(Date().timeIntervalSince1970 * 1000)
        socket.send(.string("{\"type\":\"ping\",\"ts\":\(initPingMs)}")) { _ in }

        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    await MainActor.run { self?.handle(message) }
                } catch {
                    await MainActor.run { self?.handleDisconnect(error.localizedDescription) }
                    return
                }
            }
        }

        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                let ping = "{\"type\":\"ping\",\"ts\":\(nowMs)}"
                socket.send(.string(ping)) { _ in }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            guard let decoded = MurbProtocol.decodeVideoFrame(data) else { return }
            secondScreenImage = UIImage(cgImage: decoded.image)
            frameCounter += 1
            let now = Date()
            if now.timeIntervalSince(lastFPSDate) >= 1.0 {
                fps = frameCounter
                frameCounter = 0
                lastFPSDate = now
            }
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let sys = object["sys"] as? String, !sys.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeSystem = MurbProtocol.normalizeSystem(sys)
            }
            if let ts = (object["ts"] as? NSNumber)?.int64Value,
               object["pong"] != nil || (object["type"] as? String) == "pong" {
                let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                rttMs = max(0, Int(nowMs - ts))
            }
        @unknown default:
            break
        }
    }

    private func handleDisconnect(_ reason: String) {
        tearDownSocket()
        guard active else { state = .disconnected; return }
        state = .error("Desconectado do PC (\(reason)). Reconectando…")
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.connectSocket() }
        }
    }
}

struct MurbRemoteGamepadLauncherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var remoteStore = MurbRemoteStore()
    @State private var ip = ""
    @State private var portText = "8089"
    @State private var token = ""
    @State private var system = "ds"
    @State private var scanning = false
    @State private var error = ""
    @State private var activeSessionTarget: MurbPairingPayload?

    private let supportedSystems = [
        ("ds", "Nintendo DS (2ª tela + toque)"),
        ("3ds", "Nintendo 3DS (Circle Pad + 2ª tela)"),
        ("wiiu", "Nintendo Wii U (GamePad)"),
        ("gamepad", "Controle Universal PC (M.U.R.B)")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        ExecutionBadge(kind: .dependsOnPC)
                        Text("Comunica pela rede local via WebSocket (porta 8089).").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Use este modo quando um jogo estiver rodando no PC pela M.U.R.B Engine (ou como segunda tela interativa de DS/3DS).")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let saved = remoteStore.lastTarget {
                    Section("Último PC conectado") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(saved.host):\(saved.port) · \(MurbProtocol.displaySystemName(saved.system))")
                                .font(.subheadline.bold())
                            Text("Token salvo de forma segura para reconexão rápida.").font(.caption).foregroundStyle(.secondary)
                        }
                        Button {
                            launch(saved)
                        } label: {
                            Label("Reconectar ao M.U.R.B PC", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        }
                    }
                }

                Section("Parear por QR Code") {
                    Button {
                        scanning = true
                    } label: {
                        Label("Ler QR Code M.U.R.B do PC", systemImage: "qrcode.viewfinder")
                    }
                    Text("No computador, abra a sessão com Gamepad Mobile ativado e aponte a câmera para o QR `murb://`.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Conexão manual") {
                    TextField("IP do PC na rede local (ex: 192.168.1.50)", text: $ip)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Porta (padrão 8089)", text: $portText)
                        .keyboardType(.numberPad)
                    TextField("Token da sessão", text: $token)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Picker("Perfil do console", selection: $system) {
                        ForEach(supportedSystems, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }
                    Button("Conectar Gamepad ao PC") {
                        let parsedPort = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let cleanedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanedToken = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard !cleanedIP.isEmpty, (1...65535).contains(parsedPort), !cleanedToken.isEmpty else {
                            error = "Preencha IP válido, porta e token exibidos no computador."
                            return
                        }
                        launch(MurbPairingPayload(host: cleanedIP, port: parsedPort, token: cleanedToken, system: system))
                    }
                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Gamepad para PC (M.U.R.B)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
            .onAppear {
                if let saved = remoteStore.lastTarget, ip.isEmpty {
                    ip = saved.host
                    portText = String(saved.port)
                    token = saved.token
                    system = saved.system
                }
            }
            .sheet(isPresented: $scanning) {
                ZStack(alignment: .topTrailing) {
                    PairingScannerView(validator: { url in
                        MurbPairingPayload.parse(url) != nil
                    }, onCode: { url in
                        scanning = false
                        if let parsed = MurbPairingPayload.parse(url) {
                            launch(parsed)
                        } else {
                            error = "QR Code não reconhecido como sessão M.U.R.B."
                        }
                    }, onError: { detail in
                        scanning = false
                        error = detail
                    })
                    Button { scanning = false } label: {
                        Image(systemName: "xmark").font(.headline).padding(14).background(.black.opacity(0.6)).clipShape(Circle())
                    }.foregroundStyle(.white).padding()
                }.ignoresSafeArea()
            }
            .fullScreenCover(item: Binding(
                get: { activeSessionTarget.map { MurbTargetBox(payload: $0) } },
                set: { activeSessionTarget = $0?.payload }
            )) { box in
                MurbRemoteGamepadView(target: box.payload)
            }
        }
    }

    private func launch(_ payload: MurbPairingPayload) {
        error = ""
        remoteStore.remember(payload)
        activeSessionTarget = payload
    }
}

private struct MurbTargetBox: Identifiable {
    let payload: MurbPairingPayload
    var id: String { "\(payload.host):\(payload.port):\(payload.token)" }
}

struct MurbRemoteGamepadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: MurbRemoteSession
    private let gameTitle: String
    private let playerNumber: Int
    private let p2Payload: MurbPairingPayload?
    @State private var showControls = true
    @State private var fillScreen = false
    @State private var showP2Invite = false

    init(target: MurbPairingPayload, gameTitle: String = "", playerNumber: Int = 1, p2Payload: MurbPairingPayload? = nil) {
        _session = StateObject(wrappedValue: MurbRemoteSession(target: target))
        self.gameTitle = gameTitle
        self.playerNumber = max(1, min(4, playerNumber))
        self.p2Payload = p2Payload
    }

    private var isDualScreen: Bool { MurbProtocol.supportsDualScreen(session.activeSystem) }

    var body: some View {
        ZStack {
            BrumTheme.deepBackground.ignoresSafeArea()
            MurbRemotePadCanvas(
                system: session.activeSystem,
                screenImage: session.secondScreenImage,
                showControls: isDualScreen ? showControls : true,
                fillScreen: fillScreen
            ) { buttons, touching, tx, ty, sx, sy in
                session.updateVirtualInput(buttons: buttons, touching: touching, touchX: tx, touchY: ty, stickX: sx, stickY: sy)
            }
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 10) {
                    Button {
                        session.stop()
                        dismiss()
                    } label: {
                        Label("Sair", systemImage: "chevron.left")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(BrumTheme.surface.opacity(0.9), in: Capsule())
                            .overlay(Capsule().stroke(BrumTheme.line))
                    }.foregroundStyle(BrumTheme.text)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(session.state == .connected ? BrumTheme.primary : .orange)
                            .frame(width: 8, height: 8)
                        Text(gameTitle.isEmpty
                             ? "P\(playerNumber) · M.U.R.B \(session.activeSystem.uppercased()) · PC"
                             : "P\(playerNumber) · \(gameTitle)")
                            .font(.caption2.bold()).foregroundStyle(BrumTheme.text).lineLimit(1)
                        Text(telemetryText).font(.caption2.monospacedDigit()).foregroundStyle(BrumTheme.muted)
                        if let controller = session.physicalControllerName {
                            Text("· \(controller)").font(.caption2.bold()).foregroundStyle(BrumTheme.primary).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10).frame(height: 36)
                    .background(BrumTheme.surface.opacity(0.86), in: Capsule())
                    .overlay(Capsule().stroke(BrumTheme.line))

                    Spacer()

                    if p2Payload != nil {
                        Button {
                            showP2Invite = true
                        } label: {
                            Text("P2 QR")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10).frame(height: 36)
                                .background(BrumTheme.surface.opacity(0.9), in: Capsule())
                                .overlay(Capsule().stroke(BrumTheme.line))
                        }.foregroundStyle(BrumTheme.primary)
                    }

                    if isDualScreen {
                        Button {
                            fillScreen.toggle()
                        } label: {
                            Text(fillScreen ? "4:3" : "Tela cheia")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10).frame(height: 36)
                                .background(BrumTheme.surface.opacity(0.9), in: Capsule())
                                .overlay(Capsule().stroke(BrumTheme.line))
                        }.foregroundStyle(BrumTheme.text)

                        Button {
                            showControls.toggle()
                        } label: {
                            Text(showControls ? "Touch puro" : "Controles")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10).frame(height: 36)
                                .background(showControls ? BrumTheme.surface.opacity(0.9) : BrumTheme.primary, in: Capsule())
                                .foregroundStyle(showControls ? BrumTheme.text : Color.black)
                        }
                    }

                    Button {
                        session.reconnectNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                            .frame(width: 36, height: 36)
                            .background(BrumTheme.surface.opacity(0.9), in: Circle())
                            .overlay(Circle().stroke(BrumTheme.line))
                    }.foregroundStyle(BrumTheme.text).accessibilityLabel("Reconectar")
                }
                .padding(.horizontal, 14).padding(.top, 8)
                Spacer()
            }
        }
        .onAppear {
            GamingOrientation.request(.landscape)
            session.start()
        }
        .onDisappear { session.stop() }
        .sheet(isPresented: $showP2Invite) {
            if let p2 = p2Payload {
                MurbP2InviteSheet(payload: p2)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var telemetryText: String {
        switch session.state {
        case .connected:
            return isDualScreen ? "· \(session.fps) FPS · \(session.rttMs) ms" : "· \(session.rttMs) ms"
        case .connecting:
            return "· Conectando…"
        case .disconnected:
            return "· Desconectado"
        case .error:
            return "· Reconectando…"
        }
    }
}

private struct MurbP2InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let payload: MurbPairingPayload

    private var uriString: String {
        "murb://\(payload.system)?ip=\(payload.host)&port=\(payload.port)&token=\(payload.token)&session=\(payload.session)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Convidar Jogador 2 no Wi-Fi").font(.headline.bold())
                Text("No segundo celular, abra Controles → Gamepad M.U.R.B para PC e escaneie este QR ou digite os dados abaixo.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let image = qrImage(for: uriString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("IP: \(payload.host)").font(.caption.monospaced())
                    Text("Porta: \(payload.port)").font(.caption.monospaced())
                    Text("Token P2: \(payload.token)").font(.caption.monospaced().bold()).foregroundStyle(BrumTheme.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrumTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
            .navigationTitle("Jogador 2 · LAN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        }
    }

    private func qrImage(for text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct MurbRemotePadCanvas: UIViewRepresentable {
    let system: String
    let screenImage: UIImage?
    let showControls: Bool
    let fillScreen: Bool
    let onInput: (Int, Bool, Int, Int, Int, Int) -> Void

    func makeUIView(context: Context) -> MurbRemotePadUIView {
        let view = MurbRemotePadUIView()
        view.onInput = onInput
        view.apply(system: system, image: screenImage, showControls: showControls, fillScreen: fillScreen)
        return view
    }

    func updateUIView(_ uiView: MurbRemotePadUIView, context: Context) {
        uiView.onInput = onInput
        uiView.apply(system: system, image: screenImage, showControls: showControls, fillScreen: fillScreen)
    }
}

private final class MurbRemotePadUIView: UIView {
    var onInput: ((Int, Bool, Int, Int, Int, Int) -> Void)?

    private struct Zone {
        let bit: Int
        let label: String
        var rect: CGRect
    }

    private var system = "ds"
    private var showControls = true
    private var fillScreen = false
    private var useStickForAnalog = true
    private var screenImage: UIImage?
    private var screenRect = CGRect.zero
    private var zones: [Zone] = []
    private var dpadRect = CGRect.zero
    private var stickRect = CGRect.zero
    private var modeSwitchRect = CGRect.zero

    private var activeButtonTouches: [ObjectIdentifier: Int] = [:]
    private var dpadTouchID: ObjectIdentifier?
    private var dpadMask = 0
    private var stickTouchID: ObjectIdentifier?
    private var stickVector = CGPoint.zero
    private var screenTouchID: ObjectIdentifier?
    private var screenTouchNormalized = CGPoint.zero
    private var lastTouchRipple: CGPoint?

    private let haptics = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = UIColor(red: 0.02, green: 0.024, blue: 0.03, alpha: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(system: String, image: UIImage?, showControls: Bool, fillScreen: Bool) {
        let layoutChanged = self.system != system || self.showControls != showControls || self.fillScreen != fillScreen
        self.system = system
        self.screenImage = image
        self.showControls = showControls
        self.fillScreen = fillScreen
        if layoutChanged {
            rebuildZones()
        }
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildZones()
    }

    private func rebuildZones() {
        zones.removeAll()
        dpadRect = .zero
        stickRect = .zero
        modeSwitchRect = .zero

        let safe = bounds.inset(by: safeAreaInsets)
        if MurbProtocol.supportsDualScreen(system) {
            if fillScreen {
                screenRect = bounds
            } else {
                let targetAspect: CGFloat = MurbProtocol.normalizeSystem(system) == "wiiu" ? (16.0 / 9.0) : (4.0 / 3.0)
                let availW = max(0, bounds.width)
                let availH = max(0, bounds.height)
                let w = min(availW, availH * targetAspect)
                let h = w / targetAspect
                screenRect = CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
            }
        } else {
            screenRect = .zero
        }

        guard showControls else {
            activeButtonTouches.removeAll()
            dpadTouchID = nil; dpadMask = 0
            stickTouchID = nil; stickVector = .zero
            emit()
            return
        }

        let hasAnalog = MurbProtocol.hasAnalogStick(system)
        let isPcGamepad = MurbProtocol.normalizeSystem(system) == "gamepad"
        let leftCenter = CGPoint(x: safe.minX + 104, y: safe.maxY - 106)
        if hasAnalog && useStickForAnalog {
            stickRect = CGRect(x: leftCenter.x - 68, y: leftCenter.y - 68, width: 136, height: 136)
        } else {
            dpadRect = CGRect(x: leftCenter.x - 72, y: leftCenter.y - 72, width: 144, height: 144)
        }
        if hasAnalog {
            modeSwitchRect = CGRect(x: leftCenter.x - 36, y: leftCenter.y - 112, width: 72, height: 28)
        }

        // Shoulder triggers
        zones.append(Zone(bit: MurbProtocol.buttonL, label: isPcGamepad ? "LB" : "L", rect: CGRect(x: safe.minX + 18, y: safe.minY + 56, width: 74, height: 42)))
        zones.append(Zone(bit: MurbProtocol.buttonR, label: isPcGamepad ? "RB" : "R", rect: CGRect(x: safe.maxX - 92, y: safe.minY + 56, width: 74, height: 42)))
        if hasAnalog {
            zones.append(Zone(bit: MurbProtocol.buttonL2, label: isPcGamepad ? "LT" : "L2", rect: CGRect(x: safe.minX + 100, y: safe.minY + 56, width: 62, height: 42)))
            zones.append(Zone(bit: MurbProtocol.buttonR2, label: isPcGamepad ? "RT" : "R2", rect: CGRect(x: safe.maxX - 162, y: safe.minY + 56, width: 62, height: 42)))
        }

        // Menu buttons
        zones.append(Zone(bit: MurbProtocol.buttonSelect, label: isPcGamepad ? "BACK" : "SELECT", rect: CGRect(x: safe.midX - 88, y: safe.maxY - 46, width: 78, height: 36)))
        zones.append(Zone(bit: MurbProtocol.buttonStart, label: "START", rect: CGRect(x: safe.midX + 10, y: safe.maxY - 46, width: 78, height: 36)))

        // Face diamond
        let rightCenter = CGPoint(x: safe.maxX - 112, y: safe.maxY - 106)
        let psLabels = MurbProtocol.isPlayStation(system)
        let size: CGFloat = 56
        let dist: CGFloat = 54
        if MurbProtocol.isTwoButtonClassic(system) {
            zones.append(Zone(bit: MurbProtocol.buttonB, label: "B", rect: CGRect(x: rightCenter.x - 56, y: rightCenter.y - 16, width: 60, height: 60)))
            zones.append(Zone(bit: MurbProtocol.buttonA, label: "A", rect: CGRect(x: rightCenter.x + 16, y: rightCenter.y - 36, width: 60, height: 60)))
        } else if isPcGamepad {
            zones.append(Zone(bit: MurbProtocol.buttonX, label: "Y", rect: CGRect(x: rightCenter.x - size / 2, y: rightCenter.y - dist - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonB, label: "A", rect: CGRect(x: rightCenter.x - size / 2, y: rightCenter.y + dist - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonY, label: "X", rect: CGRect(x: rightCenter.x - dist - size / 2, y: rightCenter.y - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonA, label: "B", rect: CGRect(x: rightCenter.x + dist - size / 2, y: rightCenter.y - size / 2, width: size, height: size)))
        } else {
            zones.append(Zone(bit: MurbProtocol.buttonX, label: psLabels ? "△" : "X", rect: CGRect(x: rightCenter.x - size / 2, y: rightCenter.y - dist - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonB, label: psLabels ? "×" : "B", rect: CGRect(x: rightCenter.x - size / 2, y: rightCenter.y + dist - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonY, label: psLabels ? "□" : "Y", rect: CGRect(x: rightCenter.x - dist - size / 2, y: rightCenter.y - size / 2, width: size, height: size)))
            zones.append(Zone(bit: MurbProtocol.buttonA, label: psLabels ? "○" : "A", rect: CGRect(x: rightCenter.x + dist - size / 2, y: rightCenter.y - size / 2, width: size, height: size)))
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if !screenRect.isEmpty {
            ctx.setFillColor(UIColor(white: 0.06, alpha: 1).cgColor)
            ctx.fill(screenRect)
            if let cgImage = screenImage?.cgImage {
                ctx.saveGState()
                ctx.translateBy(x: 0, y: screenRect.minY + screenRect.maxY)
                ctx.scaleBy(x: 1, y: -1)
                ctx.interpolationQuality = .none
                ctx.draw(cgImage, in: screenRect)
                ctx.restoreGState()
            } else {
                let placeholder = "AGUARDANDO SEGUNDA TELA DO PC" as NSString
                placeholder.draw(
                    at: CGPoint(x: max(screenRect.minX + 12, screenRect.midX - 115), y: screenRect.midY - 8),
                    withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                                     .foregroundColor: UIColor(white: 0.55, alpha: 1)]
                )
            }
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.16).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(screenRect)
            if let ripple = lastTouchRipple, screenTouchID != nil {
                ctx.setStrokeColor(UIColor(red: 0.62, green: 1, blue: 0.23, alpha: 0.95).cgColor)
                ctx.setLineWidth(2.5)
                ctx.strokeEllipse(in: CGRect(x: ripple.x - 16, y: ripple.y - 16, width: 32, height: 32))
            }
        } else if showControls {
            let banner = "M.U.R.B GAMEPAD · \(MurbProtocol.displaySystemName(system).uppercased()) · PC" as NSString
            banner.draw(
                at: CGPoint(x: max(16, bounds.midX - 140), y: bounds.midY - 8),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold),
                                 .foregroundColor: UIColor(red: 0.62, green: 1, blue: 0.23, alpha: 0.45)]
            )
        }

        guard showControls else { return }

        if !dpadRect.isEmpty {
            drawDPad(in: ctx, rect: dpadRect)
        }
        if !stickRect.isEmpty {
            drawStick(in: ctx, rect: stickRect)
        }
        if !modeSwitchRect.isEmpty {
            drawButton(in: ctx, rect: modeSwitchRect, title: useStickForAnalog ? "D-PAD" : "STICK", pressed: false, radius: 10)
        }
        let heldMask = activeButtonTouches.values.reduce(0, |)
        for zone in zones {
            let isCircle = zone.rect.width == zone.rect.height
            drawButton(in: ctx, rect: zone.rect, title: zone.label, pressed: (heldMask & zone.bit) != 0,
                       radius: isCircle ? zone.rect.width / 2 : 14)
        }
    }

    private func drawDPad(in ctx: CGContext, rect: CGRect) {
        let circle = UIBezierPath(ovalIn: rect)
        ctx.addPath(circle.cgPath)
        ctx.setFillColor(UIColor(white: 0.08, alpha: 0.80).cgColor)
        ctx.fillPath()
        ctx.addPath(circle.cgPath)
        ctx.setStrokeColor(UIColor(white: 1, alpha: 0.22).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokePath()

        let items: [(Int, String, CGPoint)] = [
            (MurbProtocol.buttonUp, "▲", CGPoint(x: rect.midX, y: rect.minY + 26)),
            (MurbProtocol.buttonDown, "▼", CGPoint(x: rect.midX, y: rect.maxY - 26)),
            (MurbProtocol.buttonLeft, "◀", CGPoint(x: rect.minX + 26, y: rect.midY)),
            (MurbProtocol.buttonRight, "▶", CGPoint(x: rect.maxX - 26, y: rect.midY))
        ]
        for (bit, text, point) in items {
            let on = (dpadMask & bit) != 0
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: on ? UIColor(red: 0.62, green: 1, blue: 0.23, alpha: 1) : UIColor(white: 0.9, alpha: 0.9)
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), withAttributes: attrs)
        }
    }

    private func drawStick(in ctx: CGContext, rect: CGRect) {
        ctx.setFillColor(UIColor(white: 0.08, alpha: 0.80).cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setStrokeColor(UIColor(white: 1, alpha: 0.25).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: rect)
        let radius = rect.width / 2 - 26
        let knob = CGRect(x: rect.midX + stickVector.x * radius - 22, y: rect.midY + stickVector.y * radius - 22, width: 44, height: 44)
        ctx.setFillColor(UIColor(red: 0.62, green: 1, blue: 0.23, alpha: 0.92).cgColor)
        ctx.fillEllipse(in: knob)
    }

    private func drawButton(in ctx: CGContext, rect: CGRect, title: String, pressed: Bool, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(pressed ? UIColor(red: 0.62, green: 1, blue: 0.23, alpha: 0.95).cgColor : UIColor(white: 0.10, alpha: 0.82).cgColor)
        ctx.fillPath()
        ctx.addPath(path.cgPath)
        ctx.setStrokeColor(pressed ? UIColor.white.cgColor : UIColor(white: 1, alpha: 0.18).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: title.count > 2 ? 10 : 15, weight: .black),
            .foregroundColor: pressed ? UIColor.black : UIColor.white
        ]
        let textSize = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attrs)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let id = ObjectIdentifier(touch)
            if showControls && !modeSwitchRect.isEmpty && modeSwitchRect.contains(point) {
                useStickForAnalog.toggle()
                dpadTouchID = nil; dpadMask = 0
                stickTouchID = nil; stickVector = .zero
                rebuildZones()
                setNeedsDisplay()
                emit()
                continue
            }
            if showControls, let matched = zones.first(where: { $0.rect.insetBy(dx: -6, dy: -6).contains(point) }) {
                activeButtonTouches[id] = matched.bit
                haptics.impactOccurred()
                continue
            }
            if showControls && !dpadRect.isEmpty && dpadRect.insetBy(dx: -10, dy: -10).contains(point) {
                dpadTouchID = id
                updateDPad(at: point)
                haptics.impactOccurred()
                continue
            }
            if showControls && !stickRect.isEmpty && stickRect.insetBy(dx: -10, dy: -10).contains(point) {
                stickTouchID = id
                updateStick(at: point)
                continue
            }
            if !screenRect.isEmpty && screenRect.contains(point) {
                screenTouchID = id
                updateScreenTouch(at: point)
            }
        }
        setNeedsDisplay()
        emit()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let id = ObjectIdentifier(touch)
            if id == dpadTouchID { updateDPad(at: point); continue }
            if id == stickTouchID { updateStick(at: point); continue }
            if id == screenTouchID { updateScreenTouch(at: point); continue }
            if activeButtonTouches[id] != nil {
                if let matched = zones.first(where: { $0.rect.insetBy(dx: -8, dy: -8).contains(point) }) {
                    activeButtonTouches[id] = matched.bit
                } else {
                    activeButtonTouches.removeValue(forKey: id)
                }
            }
        }
        setNeedsDisplay()
        emit()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            activeButtonTouches.removeValue(forKey: id)
            if id == dpadTouchID { dpadTouchID = nil; dpadMask = 0 }
            if id == stickTouchID { stickTouchID = nil; stickVector = .zero }
            if id == screenTouchID { screenTouchID = nil; lastTouchRipple = nil }
        }
        setNeedsDisplay()
        emit()
    }

    private func updateDPad(at point: CGPoint) {
        let dx = point.x - dpadRect.midX
        let dy = point.y - dpadRect.midY
        let threshold = (dpadRect.width / 2) * 0.22
        var mask = 0
        if dx < -threshold { mask |= MurbProtocol.buttonLeft }
        if dx > threshold { mask |= MurbProtocol.buttonRight }
        if dy < -threshold { mask |= MurbProtocol.buttonUp }
        if dy > threshold { mask |= MurbProtocol.buttonDown }
        dpadMask = mask
    }

    private func updateStick(at point: CGPoint) {
        let radius = max(1, stickRect.width / 2 - 22)
        let dx = (point.x - stickRect.midX) / radius
        let dy = (point.y - stickRect.midY) / radius
        let mag = hypot(dx, dy)
        if mag > 1 {
            stickVector = CGPoint(x: dx / mag, y: dy / mag)
        } else {
            stickVector = CGPoint(x: dx, y: dy)
        }
    }

    private func updateScreenTouch(at point: CGPoint) {
        let u = max(0, min(1, (point.x - screenRect.minX) / max(1, screenRect.width)))
        let v = max(0, min(1, (point.y - screenRect.minY) / max(1, screenRect.height)))
        screenTouchNormalized = CGPoint(x: u, y: v)
        lastTouchRipple = point
    }

    private func emit() {
        let buttonMask = activeButtonTouches.values.reduce(dpadMask, |)
        let nativeWidth = MurbProtocol.normalizeSystem(system) == "3ds" ? 319.0 : 255.0
        let nativeHeight = MurbProtocol.normalizeSystem(system) == "3ds" ? 239.0 : 191.0
        let tx = screenTouchID == nil ? 0 : Int((screenTouchNormalized.x * nativeWidth).rounded())
        let ty = screenTouchID == nil ? 0 : Int((screenTouchNormalized.y * nativeHeight).rounded())
        let sx = Int((stickVector.x * 32767.0).rounded())
        let sy = Int((stickVector.y * 32767.0).rounded())
        onInput?(buttonMask, screenTouchID != nil, tx, ty, sx, sy)
    }
}
