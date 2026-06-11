import Foundation
import SwiftData

enum TransferDirection: String, Codable, CaseIterable, Identifiable {
    case sent
    case received

    var id: Self { self }

    var title: String {
        switch self {
        case .sent: "Sent"
        case .received: "Received"
        }
    }

    var systemImage: String {
        switch self {
        case .sent: "arrow.up.circle.fill"
        case .received: "arrow.down.circle.fill"
        }
    }
}

enum TransferResult: String, Codable, CaseIterable, Identifiable {
    case completed
    case failed

    var id: Self { self }
}

struct TransferHistoryDraft: Equatable {
    let timestamp: Date
    let direction: TransferDirection
    let peerName: String
    let fileNames: [String]
    let totalBytes: Int64
    let result: TransferResult
    let savedPaths: [String]
    let errorMessage: String?
}

@Model
final class TransferHistoryEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var directionRaw: String
    var peerName: String
    var fileNamesData: Data
    var totalBytes: Int64
    var resultRaw: String
    var savedPathsData: Data
    var errorMessage: String?

    init(draft: TransferHistoryDraft) {
        id = UUID()
        timestamp = draft.timestamp
        directionRaw = draft.direction.rawValue
        peerName = draft.peerName
        fileNamesData = (try? JSONEncoder().encode(draft.fileNames)) ?? Data()
        totalBytes = draft.totalBytes
        resultRaw = draft.result.rawValue
        savedPathsData = (try? JSONEncoder().encode(draft.savedPaths)) ?? Data()
        errorMessage = draft.errorMessage
    }

    var direction: TransferDirection {
        TransferDirection(rawValue: directionRaw) ?? .sent
    }

    var result: TransferResult {
        TransferResult(rawValue: resultRaw) ?? .failed
    }

    var fileNames: [String] {
        (try? JSONDecoder().decode([String].self, from: fileNamesData)) ?? []
    }

    var savedPaths: [String] {
        (try? JSONDecoder().decode([String].self, from: savedPathsData)) ?? []
    }
}
