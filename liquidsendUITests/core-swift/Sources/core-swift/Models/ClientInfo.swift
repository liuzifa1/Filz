import Foundation

public struct ClientInfo: Codable {
    public let alias: String
    public let version: String
    public let deviceModel: String?
    public let deviceType: DeviceType?
    public let token: String
    
    public init(alias: String, version: String, deviceModel: String?, deviceType: DeviceType?, token: String) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.token = token
    }
}
