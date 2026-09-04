import Foundation
import CryptoKit
import Security
import UIKit

enum BridgeError: LocalizedError, Equatable {
    case notPaired
    case invalidPairing
    case unreachable
    case unauthorized
    case invalidCertificate
    case conflict
    case server(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notPaired: return "Conecte este iPhone ao launcher primeiro."
        case .invalidPairing: return "QR Code de pareamento inválido ou expirado."
        case .unreachable: return "Launcher não encontrado. Confirme o Wi-Fi e abra Configurações → MÓVEL no computador."
        case .unauthorized: return "A autorização deste iPhone foi revogada. Faça um novo pareamento."
        case .invalidCertificate: return "A identidade segura do launcher não corresponde ao QR Code."
        case .conflict: return "As anotações mudaram no launcher. Escolha qual versão manter."
        case .server(let message), .invalidResponse(let message): return message
        }
    }
}

private final class PinnedSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    var expectedFingerprint = ""

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    private func evaluate(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(trust, 0) else {
            completionHandler(.performDefaultHandling, nil); return
        }
        let data = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: data).map { String(format: "%02X", $0) }.joined()
        let expected = expectedFingerprint.uppercased().filter(\.isHexDigit)
        guard !expected.isEmpty, digest == expected else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

actor BridgeClient {
    struct PairResponse: Decodable { let token: String; let device: Device; let protocolVersion: Int }
    struct Device: Codable { let id: String; let name: String }
    struct ServerEnvelope<T: Decodable>: Decodable { let ok: Bool?; let result: T?; let message: String?; let error: String? }
    struct EmptyResult: Codable {}
    struct MomentResponse: Decodable { let id: String; let gameId: String; let gameTitle: String; let capturedAt: String; let imagePath: String }

    private let delegate = PinnedSessionDelegate()
    private lazy var session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    private var configuration: PairingConfiguration?
    private var token = ""
    private var socket: URLSessionWebSocketTask?

    func configure(_ configuration: PairingConfiguration?, token: String?) {
        self.configuration = configuration
        self.token = token ?? ""
        delegate.expectedFingerprint = configuration?.fingerprint ?? ""
    }

    func pair(_ payload: PairingPayload) async throws -> (PairingConfiguration, String) {
        delegate.expectedFingerprint = payload.pin
        let body: [String: Any] = ["code": payload.code, "deviceName": UIDevice.current.name]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: PairResponse = try await request(path: "/v1/pair", method: "POST", body: data, authenticated: false, overrideHost: payload.host, overridePort: payload.port)
        guard response.protocolVersion >= 8 else { throw BridgeError.invalidResponse("O launcher precisa ser atualizado para o protocolo móvel atual.") }
        let config = PairingConfiguration(host: payload.host, port: payload.port, fingerprint: payload.pin, deviceID: response.device.id, deviceName: response.device.name)
        configuration = config
        token = response.token
        return (config, response.token)
    }

    func snapshot() async throws -> LibrarySnapshot { try await request(path: "/v1/snapshot") }

    func artwork(for game: Game) async throws -> Data {
        guard !game.artworkPath.isEmpty else { throw BridgeError.invalidResponse("Capa indisponível.") }
        return try await dataRequest(path: game.artworkPath, maximumBytes: 20 * 1024 * 1024)
    }

    func captureMoment(gameID: String) async throws -> (MomentResponse, Data) {
        let body = try JSONSerialization.data(withJSONObject: ["gameId": gameID])
        let metadata: MomentResponse = try await request(path: "/v1/companion/capture", method: "POST", body: body)
        guard metadata.imagePath.hasPrefix("/v1/moments/") else { throw BridgeError.invalidResponse("A captura retornou um endereço inválido.") }
        let image = try await dataRequest(path: metadata.imagePath, maximumBytes: 40 * 1024 * 1024)
        return (metadata, image)
    }

    func unpair() async throws { let _: [String: Bool] = try await request(path: "/v1/unpair", method: "POST", body: Data()) }

    func remote(command: String, payload: [String: Any] = [:], requestID: String? = nil) async throws {
        var body: [String: Any] = ["command": command, "payload": payload]
        if let requestID { body["requestId"] = requestID; body["issuedAt"] = Int(Date().timeIntervalSince1970 * 1000) }
        let data = try JSONSerialization.data(withJSONObject: body)
        let _: ServerEnvelope<EmptyResult> = try await request(path: "/v1/remote", method: "POST", body: data)
    }

    func save(_ mutation: PendingMutation) async throws {
        var body: [String: Any] = ["gameId": mutation.gameID, "revision": mutation.revision, "force": mutation.force]
        let path: String
        if mutation.kind == .notes {
            path = "/v1/companion/notes"
            if let notes = mutation.notes { body["notes"] = notes.dictionary; body["base"] = (mutation.baseNotes ?? notes).dictionary }
        } else {
            path = "/v1/companion/library-state"
            body["favorite"] = mutation.favorite ?? false; body["wantToPlay"] = mutation.wantToPlay ?? false
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let _: ServerEnvelope<EmptyResult> = try await request(path: path, method: "POST", body: data)
    }

    func openEvents(onEvent: @escaping @Sendable (String) async -> Void) async throws {
        guard let request = try makeRequest(path: "/v1/ws", authenticated: true, webSocket: true) else { throw BridgeError.notPaired }
        let task = session.webSocketTask(with: request)
        socket = task
        try await withTaskCancellationHandler {
            task.resume()
            while !Task.isCancelled {
                let message = try await task.receive()
                switch message {
                case .string(let value): await onEvent(value)
                case .data(let value): await onEvent(String(data: value, encoding: .utf8) ?? "")
                @unknown default: break
                }
            }
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    func closeEvents() { socket?.cancel(with: .goingAway, reason: nil); socket = nil }

    private func request<T: Decodable>(path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true, overrideHost: String? = nil, overridePort: Int? = nil) async throws -> T {
        let data = try await dataRequest(path: path, method: method, body: body, authenticated: authenticated, overrideHost: overrideHost, overridePort: overridePort)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch let error as DecodingError {
            let context: DecodingError.Context
            switch error {
            case .typeMismatch(_, let value), .valueNotFound(_, let value), .keyNotFound(_, let value), .dataCorrupted(let value): context = value
            @unknown default: throw BridgeError.invalidResponse("Dados da biblioteca incompatíveis.")
            }
            let field = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw BridgeError.invalidResponse("Não foi possível ler os dados do launcher (\(field.isEmpty ? "biblioteca" : field)). Seu cache foi preservado.")
        }
    }

    private func dataRequest(path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true, overrideHost: String? = nil, overridePort: Int? = nil, maximumBytes: Int = 24 * 1024 * 1024) async throws -> Data {
        guard var request = try makeRequest(path: path, authenticated: authenticated, overrideHost: overrideHost, overridePort: overridePort) else { throw BridgeError.notPaired }
        request.httpMethod = method; request.httpBody = body
        if body != nil { request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type") }
        do {
            let (data, response) = try await session.data(for: request)
            guard data.count <= maximumBytes else { throw BridgeError.invalidResponse("A resposta excede o limite de segurança.") }
            guard let http = response as? HTTPURLResponse else { throw BridgeError.invalidResponse("Resposta de rede inválida.") }
            if http.statusCode == 401 { throw BridgeError.unauthorized }
            if http.statusCode == 409 { throw BridgeError.conflict }
            guard (200...299).contains(http.statusCode) else {
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                throw BridgeError.server((object?["message"] as? String) ?? pairingMessage(object?["error"] as? String) ?? "O launcher recusou a solicitação (\(http.statusCode)).")
            }
            return data
        } catch let error as BridgeError { throw error }
        catch let error as URLError where error.code == .cancelled || error.code == .serverCertificateUntrusted { throw BridgeError.invalidCertificate }
        catch { throw BridgeError.unreachable }
    }

    private func makeRequest(path: String, authenticated: Bool, overrideHost: String? = nil, overridePort: Int? = nil, webSocket: Bool = false) throws -> URLRequest? {
        let host = overrideHost ?? configuration?.host
        let port = overridePort ?? configuration?.port
        guard let host, let port else { return nil }
        let scheme = webSocket ? "wss" : "https"
        guard let url = URL(string: "\(scheme)://\(host):\(port)\(path)") else { throw BridgeError.invalidResponse("Endereço local inválido.") }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BRUMCLASSICS-MOVEL/0.3.1 iOS", forHTTPHeaderField: "User-Agent")
        if authenticated { guard !token.isEmpty else { throw BridgeError.notPaired }; request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func pairingMessage(_ code: String?) -> String? {
        switch code {
        case "PAIRING_CODE_INVALID": return "Código incorreto. Gere um novo no launcher."
        case "PAIRING_EXPIRED": return "O código expirou. Gere outro no launcher."
        case "PAIRING_RATE_LIMIT": return "Muitas tentativas. Aguarde alguns minutos."
        default: return nil
        }
    }
}

private extension Game.Notes {
    var dictionary: [String: Any] { ["whereStopped": whereStopped, "objectives": objectives, "tips": tips, "commands": commands, "revision": revision, "updatedAt": updatedAt] }
}
