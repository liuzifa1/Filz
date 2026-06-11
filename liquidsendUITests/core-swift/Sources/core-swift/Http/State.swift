import Foundation

public actor AppState {
    public var info: ClientInfo
    
    // Simple cache maps
    private var receivedNonceMap: [String: Data] = [:]
    private var generatedNonceMap: [String: Data] = [:]
    private let limit = 200
    
    public init(info: ClientInfo) {
        self.info = info
    }
    
    public func updateInfo(_ info: ClientInfo) {
        self.info = info
    }
    
    public func getReceivedNonce(for id: String) -> Data? {
        return receivedNonceMap[id]
    }
    
    public func setReceivedNonce(_ nonce: Data, for id: String) {
        if receivedNonceMap.count >= limit {
            // Simple eviction: remove first key
            if let key = receivedNonceMap.keys.first {
                receivedNonceMap.removeValue(forKey: key)
            }
        }
        receivedNonceMap[id] = nonce
    }
    
    public func getGeneratedNonce(for id: String) -> Data? {
        return generatedNonceMap[id]
    }
    
    public func setGeneratedNonce(_ nonce: Data, for id: String) {
        if generatedNonceMap.count >= limit {
            if let key = generatedNonceMap.keys.first {
                generatedNonceMap.removeValue(forKey: key)
            }
        }
        generatedNonceMap[id] = nonce
    }
}
