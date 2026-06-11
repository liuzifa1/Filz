import Foundation

public enum NonceUtil {
    public static func generateNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        if status == errSecSuccess {
            return Data(bytes)
        } else {
            // Fallback (should rarely happen)
            return Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        }
    }

    public static func validateNonce(_ nonce: Data) -> Bool {
        return nonce.count >= 16 && nonce.count <= 128
    }
}
