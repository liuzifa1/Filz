import Foundation

public enum DeviceType: String, Codable {
    case mobile = "MOBILE"
    case desktop = "DESKTOP"
    case web = "WEB"
    case headless = "HEADLESS"
    case server = "SERVER"
}
