import Foundation

// MARK: - Protocol DTOs from webrtc.rs

public struct RTCNonceMessage: Codable {
    public let nonce: String
}

public struct RTCTokenRequest: Codable {
    public let token: String
}

public enum RTCTokenResponse: Codable {
    case ok(token: String)
    case pinRequired(token: String)
    case invalidSignature
    
    enum CodingKeys: String, CodingKey {
        case status, token
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        switch status {
        case "OK":
            let token = try container.decode(String.self, forKey: .token)
            self = .ok(token: token)
        case "PIN_REQUIRED":
            let token = try container.decode(String.self, forKey: .token)
            self = .pinRequired(token: token)
        case "INVALID_SIGNATURE":
            self = .invalidSignature
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Unknown status")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let token):
            try container.encode("OK", forKey: .status)
            try container.encode(token, forKey: .token)
        case .pinRequired(let token):
            try container.encode("PIN_REQUIRED", forKey: .status)
            try container.encode(token, forKey: .token)
        case .invalidSignature:
            try container.encode("INVALID_SIGNATURE", forKey: .status)
        }
    }
}

public struct RTCPinMessage: Codable {
    public let pin: String
}

public enum RTCPinReceivingResponse: String, Codable {
    case ok = "OK"
    case pinRequired = "PIN_REQUIRED"
    case tooManyAttempts = "TOO_MANY_ATTEMPTS"
    
    enum CodingKeys: String, CodingKey {
        case status
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        guard let value = RTCPinReceivingResponse(rawValue: status) else {
             throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Unknown status")
        }
        self = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .status)
    }
}

public enum RTCPinSendingResponse: Codable {
    case ok(files: [FileDto])
    case pinRequired
    case tooManyAttempts
    
    enum CodingKeys: String, CodingKey {
        case status, files
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        switch status {
        case "OK":
            let files = try container.decode([FileDto].self, forKey: .files)
            self = .ok(files: files)
        case "PIN_REQUIRED":
            self = .pinRequired
        case "TOO_MANY_ATTEMPTS":
            self = .tooManyAttempts
        default:
             throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Unknown status")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let files):
            try container.encode("OK", forKey: .status)
            try container.encode(files, forKey: .files)
        case .pinRequired:
            try container.encode("PIN_REQUIRED", forKey: .status)
        case .tooManyAttempts:
            try container.encode("TOO_MANY_ATTEMPTS", forKey: .status)
        }
    }
}

public enum RTCFileListResponse: Codable {
    case ok(files: [String: String])
    case pair(publicKey: String)
    case declined
    case invalidSignature
    
    enum CodingKeys: String, CodingKey {
        case status, files, publicKey
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        switch status {
        case "OK":
            let files = try container.decode([String: String].self, forKey: .files)
            self = .ok(files: files)
        case "PAIR":
            let key = try container.decode(String.self, forKey: .publicKey)
            self = .pair(publicKey: key)
        case "DECLINED":
            self = .declined
        case "INVALID_SIGNATURE":
            self = .invalidSignature
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Unknown status")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let files):
            try container.encode("OK", forKey: .status)
            try container.encode(files, forKey: .files)
        case .pair(let key):
            try container.encode("PAIR", forKey: .status)
            try container.encode(key, forKey: .publicKey)
        case .declined:
            try container.encode("DECLINED", forKey: .status)
        case .invalidSignature:
            try container.encode("INVALID_SIGNATURE", forKey: .status)
        }
    }
}

public enum RTCPairResponse: Codable {
    case ok(publicKey: String)
    case pairDeclined
    case invalidSignature
    
    enum CodingKeys: String, CodingKey {
        case status, publicKey
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let key):
            try container.encode("OK", forKey: .status)
            try container.encode(key, forKey: .publicKey)
        case .pairDeclined:
            try container.encode("PAIR_DECLINED", forKey: .status)
        case .invalidSignature:
            try container.encode("INVALID_SIGNATURE", forKey: .status)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        switch status {
        case "OK":
             let key = try container.decode(String.self, forKey: .publicKey)
             self = .ok(publicKey: key)
        case "PAIR_DECLINED":
            self = .pairDeclined
        case "INVALID_SIGNATURE":
            self = .invalidSignature
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Unknown status")
        }
    }
}

public struct RTCSendFileHeaderRequest: Codable {
    public let id: String
    public let token: String
}

public struct RTCSendFileResponse: Codable {
    public let id: String
    public let success: Bool
    public let error: String?
}
