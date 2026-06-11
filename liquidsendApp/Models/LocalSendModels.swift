//
//  LocalSendModels.swift
//  liquidsend
//
//  Data models exchanged with LocalSend Core. Pure value types with no FFI
//  dependency — the bridging lives in LocalSendCoreClient.
//

import Foundation

struct LocalSendDevice: Decodable, Identifiable, Hashable, Sendable {
    let alias: String
    let version: String
    let deviceModel: String?
    let deviceType: String
    let token: String
    let ip: String
    let port: UInt16
    let `protocol`: String
    let download: Bool

    var id: String {
        token.isEmpty ? "\(ip):\(port)" : token
    }

    var endpoint: String {
        "\(`protocol`.lowercased())://\(ip):\(port)"
    }

    var systemImage: String {
        switch deviceType.lowercased() {
        case "mobile": "iphone"
        case "web": "globe"
        case "headless": "terminal"
        case "server": "server.rack"
        default: "desktopcomputer"
        }
    }
}

struct LocalSendFile: Codable, Identifiable, Sendable {
    let filePath: String
    let fileName: String
    let fileType: String

    var id: String { filePath }
}

struct IncomingLocalSendFile: Decodable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let size: UInt64
    let fileType: String
}

struct IncomingLocalSendRequest: Decodable, Identifiable, Hashable {
    let id: String
    let senderAlias: String
    let senderIP: String
    let files: [IncomingLocalSendFile]
    let totalBytes: UInt64
}

struct LocalSendTransferProgress: Decodable, Equatable {
    let status: String
    let targetAlias: String?
    let senderAlias: String?
    let currentFile: String?
    let sentBytes: UInt64?
    let receivedBytes: UInt64?
    let totalBytes: UInt64
    let completedFiles: Int
    let totalFiles: Int
    let savedPaths: [String]?
    let error: String?

    var transferredBytes: UInt64 {
        sentBytes ?? receivedBytes ?? 0
    }

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return status == "finished" ? 1 : 0 }
        return min(Double(transferredBytes) / Double(totalBytes), 1)
    }
}
