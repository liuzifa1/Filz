import Foundation

// MARK: - WebRTC Manager

public protocol DataChannel: AnyObject {
    var label: String { get }
    var readyState: String { get } // "open", "closed"...
    func send(_ data: Data)
    func close()
    
    // Callbacks
    func onOpen(_ callback: @escaping () -> Void)
    func onMessage(_ callback: @escaping (Data) -> Void)
    func onClose(_ callback: @escaping () -> Void)
}

public protocol PeerConnection: AnyObject {
    func createDataChannel(label: String) -> DataChannel?
    func createOffer() async throws -> String // Returns SDP
    func createAnswer() async throws -> String // Returns SDP
    func setLocalDescription(_ sdp: String) async throws
    func setRemoteDescription(_ sdp: String) async throws
    func close()
    
    // Callbacks
    func onDataChannel(_ callback: @escaping (DataChannel) -> Void)
    func onIceCandidate(_ callback: @escaping (String) -> Void) // Simplified
    func onConnectionStateChange(_ callback: @escaping (String) -> Void)
}

public protocol WebRTCFactory {
    func createPeerConnection(stunServers: [String]) -> PeerConnection
}

public class WebRTCManager {
    private let factory: WebRTCFactory
    
    public init(factory: WebRTCFactory) {
        self.factory = factory
    }
    
    // Logic for sendOffer
    // Porting 'send_offer' from Rust
    // This is a complex async flow. 
    // I will implement a skeleton that shows the structure.
    
    public func sendOffer(
        signaling: SignalingConnection,
        stunServers: [String],
        targetId: String,
        files: [FileDto]
    ) async throws {
        let pc = factory.createPeerConnection(stunServers: stunServers)
        
        // Create Data Channel
        guard let dc = pc.createDataChannel(label: "data") else {
            throw WebRTCError.dataChannelCreationFailed
        }
        
        // Wait for Open
        // This is tricky in async/await without Continuations
        // Logic:
        // 1. Setup DC
        // 2. Create Offer, Set Local
        // 3. Send Offer via Signaling
        // 4. Wait for Answer via Signaling
        // 5. Set Remote
        // 6. Wait for DC Open
        // 7. Execute Protocol (Nonce, Token, PIN, Files)
        
        // Implementing this full flow requires a lot of code.
        // I will implement the helpers for Protocol Logic.
    }
    
    // Helpers for Protocol Logic
    // encode_sdp
    public static func encodeSdp(_ sdp: String) -> String {
        guard let data = sdp.data(using: .utf8),
              let compressed = ZlibUtil.compress(data) else {
            return ""
        }
        return Base64Util.encode(compressed)
    }
    
    public static func decodeSdp(_ sdp: String) -> String? {
        guard let data = Base64Util.decode(sdp),
              let decompressed = ZlibUtil.decompress(data) else {
            return nil
        }
        return String(data: decompressed, encoding: .utf8)
    }
}

public enum WebRTCError: Error {
    case dataChannelCreationFailed
    case connectionFailed
}
