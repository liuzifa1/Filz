import Foundation
import Compression

public enum ZlibUtil {
    public static func compress(_ data: Data) -> Data? {
        // Use NSData compressed(using:) if available (iOS 13+)
        // This usually produces zlib-wrapped data (RFC 1950) or raw deflate? 
        // Apple's .zlib usually means zlib header.
        
        // Simpler approach for cross-platform Swift:
        // Using `compressed(using: .zlib)`
        
        do {
            return try (data as NSData).compressed(using: .zlib) as Data
        } catch {
            return nil
        }
    }
    
    public static func decompress(_ data: Data) -> Data? {
        do {
            return try (data as NSData).decompressed(using: .zlib) as Data
        } catch {
            return nil
        }
    }
}
