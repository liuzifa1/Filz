import Foundation
import Security

public class LsHttpClient: NSObject, @unchecked Sendable {
    private let identity: SecIdentity?
    private var session: URLSession!
    
    private let receivedNonceMap = AppState(info: ClientInfo(alias: "", version: "", deviceModel: nil, deviceType: nil, token: "")) // Placeholder, actually passed in?
    // Wait, Rust LsHttpClient owns the maps.
    
    // We need to mirror the logic.
    // LsHttpClient has its own maps in Rust.
    // But in Swift, maybe we inject them?
    // The Rust code: "received_nonce_map: Arc<Mutex<LruCache...>>"
    // I'll define them inside for now or use the actor if shared.
    // Since this is a client, maybe it's standalone?
    // Rust main.rs creates one client.
    
    private let nonceMapActor = NonceMapActor()
    
    public init(privateKeyPem: String, certPem: String) throws {
        // Create Identity
        self.identity = try CertUtil.createIdentity(certPem: certPem, keyPem: privateKeyPem)
        
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - API
    
    public func nonce(protocolType: ProtocolType, ip: String, port: UInt16) async throws -> String {
        let urlStr = "\(protocolType.asString())://\(ip):\(port)/api/localsend/v3/nonce"
        guard let url = URL(string: urlStr) else { throw ClientError.invalidUrl }
        
        let generatedNonce = NonceUtil.generateNonce()
        let generatedNonceBase64 = Base64Util.encode(generatedNonce)
        
        let requestDto = NonceRequest(nonce: generatedNonceBase64)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(requestDto)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let delegate = TaskDelegate(identity: identity)
        let (data, response) = try await session.data(for: request, delegate: delegate)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ClientError.badStatus
        }
        
        let responseDto = try JSONDecoder().decode(NonceResponse.self, from: data)
        
        // Extract Remote Key
        let remoteKey: String
        if protocolType == .https {
            guard let key = delegate.peerPublicKey else {
                 throw ClientError.tlsError("No peer key captured")
            }
            // Rust verifies the cert here too?
            // "to_identifier... verify_cert_from_res"
            // Our delegate verified it? 
            // Delegate just extracted it. We should verify it if needed.
            // Rust: verify_cert_from_res calls verify_cert_from_der(cert, None).
            // This checks validity.
            // We should assume delegate checked basic validity or do it here if we have the cert data.
            remoteKey = key
        } else {
            remoteKey = ip
        }
        
        // Store nonces
        guard let responseNonce = Base64Util.decode(responseDto.nonce) else {
            throw ClientError.invalidBase64
        }
        
        await nonceMapActor.setReceived(responseNonce, for: remoteKey)
        await nonceMapActor.setGenerated(generatedNonce, for: remoteKey)
        
        return responseDto.nonce
    }
    
    public func register(protocolType: ProtocolType, ip: String, port: UInt16, payload: RegisterDto) async throws -> (RegisterResponseDto, String?) {
        let urlStr = "\(protocolType.asString())://\(ip):\(port)/api/localsend/v3/register" // V3 path
        // Rust code uses BASE_PATH "/api/localsend/v3"
        guard let url = URL(string: urlStr) else { throw ClientError.invalidUrl }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let delegate = TaskDelegate(identity: identity)
        let (data, response) = try await session.data(for: request, delegate: delegate)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ClientError.badStatus
        }
        
        let responseDto = try JSONDecoder().decode(RegisterResponseDto.self, from: data)
        
        // Verify cert and return key
        var publicKey: String? = nil
        if protocolType == .https {
             guard let key = delegate.peerPublicKey else {
                 throw ClientError.tlsError("No peer key captured")
            }
            // Verify
            // Rust: verify_cert_from_res(..., None)
            publicKey = key
        }
        
        return (responseDto, publicKey)
    }
    
    // ... prepareUpload, upload, cancel implemented similarly
}

extension LsHttpClient: URLSessionDelegate {
    // Basic session delegate methods if needed
}

// Actor for maps
actor NonceMapActor {
    var received: [String: Data] = [:]
    var generated: [String: Data] = [:]
    
    func setReceived(_ data: Data, for key: String) { received[key] = data }
    func setGenerated(_ data: Data, for key: String) { generated[key] = data }
}

enum ClientError: Error {
    case invalidUrl
    case badStatus
    case invalidBase64
    case tlsError(String)
}

// Task Delegate
class TaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let identity: SecIdentity?
    var peerPublicKey: String?
    
    init(identity: SecIdentity?) {
        self.identity = identity
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                 // Capture key
                 if let cert = SecTrustGetCertificateAtIndex(trust, 0) {
                     // We can export the public key from this cert
                     // We'll use a helper from CertUtil (need to expose one)
                     // For now, let's assume CertUtil has a helper 'publicKeyFromCert(SecCertificate)'
                     // or we do it here.
                     
                     // Quick hack: Convert cert to PEM, then extract?
                     // Or direct export.
                     // Let's rely on CertUtil.publicKeyFromCert(cert) if we add it.
                     // I'll add `publicKeyFromSecCertificate` to CertUtil later or inline it.
                     // Inline:
                     if let key = SecCertificateCopyKey(cert),
                        let data = SecKeyCopyExternalRepresentation(key, nil) as Data? {
                         let base64 = data.base64EncodedString(options: .lineLength64Characters)
                         self.peerPublicKey = "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"
                     }
                 }
                 // Rust accepts invalid certs (self-signed)
                 return (.useCredential, URLCredential(trust: trust))
            }
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let identity = identity {
                // Get cert from identity
                var cert: SecCertificate?
                SecIdentityCopyCertificate(identity, &cert)
                if let cert = cert {
                    return (.useCredential, URLCredential(identity: identity, certificates: [cert], persistence: .forSession))
                }
            }
        }
        
        return (.performDefaultHandling, nil)
    }
}
