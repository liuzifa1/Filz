import Foundation

public enum Base64Util {
    public static func encode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let length = base64.lengthOfBytes(using: .utf8)
        let requiredLength = (length + 3) / 4 * 4
        let paddingLength = requiredLength - length

        if paddingLength > 0 {
            base64 += String(repeating: "=", count: paddingLength)
        }

        return Data(base64Encoded: base64)
    }
}
