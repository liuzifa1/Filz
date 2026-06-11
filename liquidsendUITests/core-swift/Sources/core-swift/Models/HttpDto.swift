import Foundation

public struct NonceRequest: Codable {
    public let nonce: String
    
    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct NonceResponse: Codable {
    public let nonce: String
    
    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct ErrorResponse: Codable {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

public enum ProtocolType: String, Codable {
    case http = "http"
    case https = "https"
    
    public enum CodingKeys: String, CodingKey {
        case http = "HTTP"
        case https = "HTTPS"
    }
    
    // Rust serde rename_all = "SCREAMING_SNAKE_CASE"
    // So HTTP -> "HTTP", HTTPS -> "HTTPS"
    // But usage is protocol.as_str() -> "http"/"https" for URL.
    
    public func asString() -> String {
        return self.rawValue
    }
}

public struct RegisterDto: Codable {
    public let alias: String
    public let version: String
    public let deviceModel: String?
    public let deviceType: DeviceType?
    public let token: String
    public let port: UInt16
    public let protocolType: ProtocolType
    public let hasWebInterface: Bool
    
    enum CodingKeys: String, CodingKey {
        case alias, version, deviceModel, deviceType, token, port
        case protocolType = "protocol"
        case hasWebInterface
    }
    
    public init(alias: String, version: String, deviceModel: String?, deviceType: DeviceType?, token: String, port: UInt16, protocolType: ProtocolType, hasWebInterface: Bool = false) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.token = token
        self.port = port
        self.protocolType = protocolType
        self.hasWebInterface = hasWebInterface
    }
}

public struct RegisterResponseDto: Codable {
    public let alias: String
    public let version: String
    public let deviceModel: String?
    public let deviceType: DeviceType?
    public let token: String
    public let hasWebInterface: Bool
    
    public init(alias: String, version: String, deviceModel: String?, deviceType: DeviceType?, token: String, hasWebInterface: Bool = false) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.token = token
        self.hasWebInterface = hasWebInterface
    }
}

public struct PrepareUploadRequestDto: Codable {
    public let info: RegisterDto
    public let files: [String: FileDto]
    
    public init(info: RegisterDto, files: [String: FileDto]) {
        self.info = info
        self.files = files
    }
}

public struct PrepareUploadResponseDto: Codable {
    public let sessionId: String
    public let files: [String: String]
    
    public init(sessionId: String, files: [String: String]) {
        self.sessionId = sessionId
        self.files = files
    }
}
