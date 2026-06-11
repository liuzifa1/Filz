import CryptoKit
import Foundation

// MARK: - Constants for Ed25519 PEM/DER
private let ed25519PrivateKeyPrefix: [UInt8] = [
    0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20
]

private let ed25519PublicKeyPrefix: [UInt8] = [
    0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00
]

public struct SigningTokenKey {
    let inner: Curve25519.Signing.PrivateKey
    
    public init() {
        self.inner = Curve25519.Signing.PrivateKey()
    }
    
    public init(pem: String) throws {
        // Strip PEM header/footer
        let lines = pem.components(separatedBy: .newlines)
        let base64Lines = lines.filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let base64 = base64Lines.joined()
        
        guard let data = Data(base64Encoded: base64) else {
            throw TokenError.invalidPem
        }
        
        // Remove prefix to get raw key
        if data.count == 48 && Array(data.prefix(16)) == ed25519PrivateKeyPrefix {
            let rawData = data.subdata(in: 16..<48)
            self.inner = try Curve25519.Signing.PrivateKey(rawRepresentation: rawData)
        } else {
            // Maybe it's just raw?
             try self.inner = Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }
    }
    
    public func toVerifyingKey() -> VerifyingTokenKey {
        return Ed25519VerifyingKey(inner: self.inner.publicKey)
    }
    
    public func exportPrivateKey() -> String {
        let raw = self.inner.rawRepresentation
        var data = Data(ed25519PrivateKeyPrefix)
        data.append(raw)
        
        let base64 = data.base64EncodedString(options: [.lineLength64Characters])
        return "-----BEGIN PRIVATE KEY-----\n\(base64)\n-----END PRIVATE KEY-----"
    }
    
    public func exportPublicKey() -> String {
        let raw = self.inner.publicKey.rawRepresentation
        var data = Data(ed25519PublicKeyPrefix)
        data.append(raw)
        
        let base64 = data.base64EncodedString(options: [.lineLength64Characters])
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"
    }
}

public protocol VerifyingTokenKey {
    func verify(msg: Data, signature: Data) throws
    func toDer() -> Data
    func signatureMethod() -> String
}

public struct Ed25519VerifyingKey: VerifyingTokenKey {
    let inner: Curve25519.Signing.PublicKey
    
    public func verify(msg: Data, signature: Data) throws {
        if !inner.isValidSignature(signature, for: msg) {
            throw TokenError.invalidSignature
        }
    }
    
    public func toDer() -> Data {
        var data = Data(ed25519PublicKeyPrefix)
        data.append(inner.rawRepresentation)
        return data
    }
    
    public func signatureMethod() -> String {
        return "ed25519"
    }
}

public enum TokenError: Error {
    case invalidPem
    case invalidSignature
    case invalidStructure
    case invalidHashMethod
    case invalidSignMethod
    case invalidSalt
    case fingerprintExpired
    case invalidNonce
    case hashMismatch
    case invalidBase64
}

public enum TokenUtil {
    public static func generateKey() -> SigningTokenKey {
        return SigningTokenKey()
    }
    
    public static func parsePublicKey(pem: String, identifier: String) throws -> VerifyingTokenKey {
         let lines = pem.components(separatedBy: .newlines)
         let base64Lines = lines.filter { !$0.hasPrefix("-----") && !$0.isEmpty }
         let base64 = base64Lines.joined()
         
         guard let data = Data(base64Encoded: base64) else {
             throw TokenError.invalidPem
         }
        
        if identifier == "ed25519" {
            // Remove prefix
             if data.count == 44 && Array(data.prefix(12)) == ed25519PublicKeyPrefix {
                 let rawData = data.subdata(in: 12..<44)
                 let key = try Curve25519.Signing.PublicKey(rawRepresentation: rawData)
                 return Ed25519VerifyingKey(inner: key)
             } else {
                 let key = try Curve25519.Signing.PublicKey(rawRepresentation: data)
                 return Ed25519VerifyingKey(inner: key)
             }
        } else {
            throw TokenError.invalidSignMethod // Only Ed25519 supported for now
        }
    }
    
    public static func generateTokenTimestamp(key: SigningTokenKey) throws -> String {
        let timestamp = TimeUtil.unixTimestampU64()
        var salt = withUnsafeBytes(of: timestamp.littleEndian) { Data($0) }
        // Rust to_le_bytes for u64 is 8 bytes.
        
        return try generateTokenNonce(key: key, salt: salt)
    }
    
    public static func generateTokenNonce(key: SigningTokenKey, salt: Data) throws -> String {
        let publicKeyDer = key.toVerifyingKey().toDer()
        var hashInput = publicKeyDer
        hashInput.append(salt)
        
        let digest = HashUtil.sha256(hashInput)
        let signature = try key.inner.signature(for: digest)
        
        let hashMethod = "sha256"
        let hashBase64 = Base64Util.encode(digest)
        let saltBase64 = Base64Util.encode(salt)
        let signMethod = "ed25519"
        let signatureBase64 = Base64Util.encode(signature)
        
        return "\(hashMethod).\(hashBase64).\(saltBase64).\(signMethod).\(signatureBase64)"
    }
    
    public static func verifyTokenTimestamp(publicKey: VerifyingTokenKey, token: String) -> Bool {
        return (try? verifyTokenWithResult(publicKey: publicKey, token: token) { salt in
            guard salt.count == 8 else { throw TokenError.invalidSalt }
            let timestamp = salt.withUnsafeBytes { $0.load(as: UInt64.self) }.littleEndian
            
            let now = TimeUtil.unixTimestampU64()
            // Check if older than 1h (3600s)
            // Note: Rust code: if now - salt > 3600.
            // Be careful with underflow if clock skewed, but assuming now > timestamp usually.
            if now < timestamp { return } // Future timestamp? 
            if now - timestamp > 3600 {
                throw TokenError.fingerprintExpired
            }
        }) != nil
    }
    
    public static func verifyTokenNonce(publicKey: VerifyingTokenKey, token: String, nonce: Data) -> Bool {
        return (try? verifyTokenWithResult(publicKey: publicKey, token: token) { salt in
            if salt != nonce {
                throw TokenError.invalidNonce
            }
        }) != nil
    }
    
    public static func verifyTokenWithResult(publicKey: VerifyingTokenKey, token: String, verifySalt: (Data) throws -> Void) throws {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 5 else { throw TokenError.invalidStructure }
        
        let hashMethod = parts[0]
        let hashBase64 = parts[1]
        let saltBase64 = parts[2]
        let signMethod = parts[3]
        let signatureBase64 = parts[4]
        
        guard hashMethod == "sha256" else { throw TokenError.invalidHashMethod }
        guard signMethod == publicKey.signatureMethod() else { throw TokenError.invalidSignMethod }
        
        guard let salt = Base64Util.decode(saltBase64) else { throw TokenError.invalidBase64 }
        try verifySalt(salt)
        
        let publicKeyDer = publicKey.toDer()
        var hashInput = publicKeyDer
        hashInput.append(salt)
        let digest = HashUtil.sha256(hashInput)
        
        if Base64Util.encode(digest) != hashBase64 {
            throw TokenError.hashMismatch
        }
        
        guard let signature = Base64Util.decode(signatureBase64) else { throw TokenError.invalidBase64 }
        
        try publicKey.verify(msg: digest, signature: signature)
    }
}
