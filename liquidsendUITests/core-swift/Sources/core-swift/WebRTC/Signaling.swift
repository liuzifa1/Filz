import Foundation

// MARK: - Signaling DTOs

public enum WsServerMessage: Codable {
    case hello(client: ClientInfo, peers: [ClientInfo])
    case join(peer: ClientInfo)
    case update(peer: ClientInfo)
    case left(peerId: String)
    case offer(WsServerSdpMessage)
    case answer(WsServerSdpMessage)
    case error(code: UInt16)
    
    enum CodingKeys: String, CodingKey {
        case type
        case client, peers
        case peer
        case peerId
        case code
        // fields for offer/answer are flattened in Rust serde?
        // Rust: `Offer(WsServerSdpMessage)` with `type` tag.
        // Wait, Rust enum representation `tag="type"`.
        // So `{ "type": "OFFER", "peer": ..., "sessionId": ..., "sdp": ... }`
        // Swift Codable doesn't handle flattened enum associated values automatically with `type` tag easily.
        // We need custom encoding/decoding.
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "HELLO":
            let client = try container.decode(ClientInfo.self, forKey: .client)
            let peers = try container.decode([ClientInfo].self, forKey: .peers)
            self = .hello(client: client, peers: peers)
        case "JOIN":
            let peer = try container.decode(ClientInfo.self, forKey: .peer)
            self = .join(peer: peer)
        case "UPDATE":
            let peer = try container.decode(ClientInfo.self, forKey: .peer)
            self = .update(peer: peer)
        case "LEFT":
            let peerId = try container.decode(String.self, forKey: .peerId)
            self = .left(peerId: peerId)
        case "OFFER":
            let msg = try WsServerSdpMessage(from: decoder)
            self = .offer(msg)
        case "ANSWER":
             let msg = try WsServerSdpMessage(from: decoder)
             self = .answer(msg)
        case "ERROR":
            let code = try container.decode(UInt16.self, forKey: .code)
            self = .error(code: code)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let client, let peers):
            try container.encode("HELLO", forKey: .type)
            try container.encode(client, forKey: .client)
            try container.encode(peers, forKey: .peers)
        case .join(let peer):
            try container.encode("JOIN", forKey: .type)
            try container.encode(peer, forKey: .peer)
        case .update(let peer):
            try container.encode("UPDATE", forKey: .type)
            try container.encode(peer, forKey: .peer)
        case .left(let peerId):
            try container.encode("LEFT", forKey: .type)
            try container.encode(peerId, forKey: .peerId)
        case .offer(let msg):
            try container.encode("OFFER", forKey: .type)
            try msg.encode(to: encoder) // Flattened
        case .answer(let msg):
            try container.encode("ANSWER", forKey: .type)
            try msg.encode(to: encoder)
        case .error(let code):
            try container.encode("ERROR", forKey: .type)
            try container.encode(code, forKey: .code)
        }
    }
}

public struct WsServerSdpMessage: Codable {
    public let peer: ClientInfo
    public let sessionId: String
    public let sdp: String
}

public struct ClientInfoWithoutId: Codable {
    public let alias: String
    public let version: String
    public let deviceModel: String?
    public let deviceType: DeviceType?
    public let token: String
    
    public static func from(_ info: ClientInfo) -> ClientInfoWithoutId {
        return ClientInfoWithoutId(
            alias: info.alias,
            version: info.version,
            deviceModel: info.deviceModel,
            deviceType: info.deviceType,
            token: info.token
        )
    }
}

public enum WsClientMessage: Codable {
    case update(info: ClientInfoWithoutId)
    case offer(WsClientSdpMessage)
    case answer(WsClientSdpMessage)
    
    enum CodingKeys: String, CodingKey {
        case type, info
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .update(let info):
            try container.encode("UPDATE", forKey: .type)
            try container.encode(info, forKey: .info)
        case .offer(let msg):
            try container.encode("OFFER", forKey: .type)
            try msg.encode(to: encoder)
        case .answer(let msg):
            try container.encode("ANSWER", forKey: .type)
            try msg.encode(to: encoder)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "UPDATE":
            let info = try container.decode(ClientInfoWithoutId.self, forKey: .info)
            self = .update(info: info)
        case "OFFER":
            let msg = try WsClientSdpMessage(from: decoder)
            self = .offer(msg)
        case "ANSWER":
            let msg = try WsClientSdpMessage(from: decoder)
            self = .answer(msg)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
}

public struct WsClientSdpMessage: Codable {
    public let sessionId: String
    public let target: String
    public let sdp: String
}

// MARK: - Signaling Connection

public class SignalingConnection: NSObject, @unchecked Sendable {
    public let client: ClientInfo
    private let webSocket: URLSessionWebSocketTask
    
    public var onMessage: ((WsServerMessage) -> Void)?
    
    private init(client: ClientInfo, webSocket: URLSessionWebSocketTask) {
        self.client = client
        self.webSocket = webSocket
    }
    
    public static func connect(uri: String, info: ClientInfoWithoutId) async throws -> SignalingConnection {
        let json = try JSONEncoder().encode(info)
        let encodedInfo = Base64Util.encode(json) // Using our Base64Util
        
        guard let url = URL(string: "\(uri)?d=\(encodedInfo)") else {
            throw SignalingError.invalidUrl
        }
        
        let session = URLSession(configuration: .default)
        let webSocket = session.webSocketTask(with: url)
        webSocket.resume()
        
        // Wait for Hello
        // Read first message
        let message = try await webSocket.receive()
        
        let data: Data
        switch message {
        case .string(let text):
            data = text.data(using: .utf8) ?? Data()
        case .data(let d):
            data = d
        @unknown default:
             throw SignalingError.unknownMessage
        }
        
        let msg = try JSONDecoder().decode(WsServerMessage.self, from: data)
        
        guard case .hello(let client, _) = msg else {
            throw SignalingError.unexpectedMessage
        }
        
        let connection = SignalingConnection(client: client, webSocket: webSocket)
        connection.startListening()
        return connection
    }
    
    private func startListening() {
        func receive() {
            webSocket.receive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    do {
                        let data: Data
                        switch message {
                        case .string(let text): data = text.data(using: .utf8) ?? Data()
                        case .data(let d): data = d
                        @unknown default: return
                        }
                        
                        let msg = try JSONDecoder().decode(WsServerMessage.self, from: data)
                        self.onMessage?(msg)
                        receive() // Continue listening
                    } catch {
                        print("Signaling decode error: \(error)")
                        receive()
                    }
                case .failure(let error):
                    print("Signaling receive error: \(error)")
                }
            }
        }
        receive()
    }
    
    public func send(message: WsClientMessage) async throws {
        let data = try JSONEncoder().encode(message)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await webSocket.send(.string(text))
    }
    
    public func sendOffer(sessionId: String, target: String, sdp: String) async throws {
        let msg = WsClientMessage.offer(WsClientSdpMessage(sessionId: sessionId, target: target, sdp: sdp))
        try await send(message: msg)
    }
    
    public func sendAnswer(sessionId: String, target: String, sdp: String) async throws {
         let msg = WsClientMessage.answer(WsClientSdpMessage(sessionId: sessionId, target: target, sdp: sdp))
         try await send(message: msg)
    }
}

public enum SignalingError: Error {
    case invalidUrl
    case unknownMessage
    case unexpectedMessage
}
