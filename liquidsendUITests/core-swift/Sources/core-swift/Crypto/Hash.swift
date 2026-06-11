import CryptoKit
import Foundation

public enum HashUtil {
    public static func sha256(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}
