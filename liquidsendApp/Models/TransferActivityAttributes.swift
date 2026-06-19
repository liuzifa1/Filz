import ActivityKit
import Foundation

nonisolated struct TransferActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var fileName: String
        var transferredBytes: UInt64
        var totalBytes: UInt64
        var completedFiles: Int
        var totalFiles: Int
        var actionHint: String?
        var deepLink: String?

        var fractionCompleted: Double {
            guard totalBytes > 0 else { return status == "finished" ? 1 : 0 }
            return min(Double(transferredBytes) / Double(totalBytes), 1)
        }
    }

    var peerName: String
    var direction: String
}
