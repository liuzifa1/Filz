import Foundation

public enum TimeUtil {
    public static func unixTimestampU64() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970)
    }
}
