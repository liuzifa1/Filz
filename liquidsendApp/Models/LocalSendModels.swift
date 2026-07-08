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
    let pin: String?

    init(
        alias: String,
        version: String,
        deviceModel: String?,
        deviceType: String,
        token: String,
        ip: String,
        port: UInt16,
        protocol: String,
        download: Bool,
        pin: String? = nil
    ) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.token = token
        self.ip = ip
        self.port = port
        self.protocol = `protocol`
        self.download = download
        self.pin = pin
    }

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
    let preview: String?

    var id: String { filePath }
}

struct IncomingLocalSendFile: Decodable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let size: UInt64
    let fileType: String
    let preview: String?
}

struct IncomingLocalSendRequest: Decodable, Identifiable, Hashable {
    let id: String
    let senderAlias: String
    let senderIP: String
    let senderPort: UInt16
    let senderProtocol: String
    let senderToken: String
    let senderFingerprint: String?
    let files: [IncomingLocalSendFile]
    let totalBytes: UInt64

    // Mirrors the core's text_message() rule: exactly one text/* file with a
    // non-empty preview. Any file may carry a preview per the protocol, so
    // grabbing the first preview alone would misclassify multi-file batches.
    var textMessage: String? {
        guard files.count == 1,
              let file = files.first,
              file.fileType.hasPrefix("text/"),
              let preview = file.preview,
              !preview.isEmpty else {
            return nil
        }
        return preview
    }

    enum CodingKeys: String, CodingKey {
        case id
        case senderAlias
        case senderIP = "senderIp"
        case senderPort
        case senderProtocol
        case senderToken
        case senderFingerprint
        case files
        case totalBytes
    }
}

struct LocalSendTransferProgress: Decodable, Equatable {
    let requestID: String?
    let status: String
    let startedAtMillis: UInt64?
    let targetAlias: String?
    let targetIP: String?
    let targetPort: UInt16?
    let targetProtocol: String?
    let senderAlias: String?
    let senderIP: String?
    let senderPort: UInt16?
    let senderProtocol: String?
    let senderFingerprint: String?
    let currentFile: String?
    let sentBytes: UInt64?
    let receivedBytes: UInt64?
    let totalBytes: UInt64
    let completedFiles: Int
    let totalFiles: Int
    let savedPaths: [String]?
    let textMessage: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case status
        case startedAtMillis
        case targetAlias
        case targetIP = "targetIp"
        case targetPort
        case targetProtocol
        case senderAlias
        case senderIP = "senderIp"
        case senderPort
        case senderProtocol
        case senderFingerprint
        case currentFile
        case sentBytes
        case receivedBytes
        case totalBytes
        case completedFiles
        case totalFiles
        case savedPaths
        case textMessage
        case error
    }

    var transferredBytes: UInt64 {
        sentBytes ?? receivedBytes ?? 0
    }

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return status == "finished" ? 1 : 0 }
        return min(Double(transferredBytes) / Double(totalBytes), 1)
    }

    var percentText: String {
        "\(Int((fractionCompleted * 100).rounded()))%"
    }

    var isTextMessage: Bool {
        textMessage?.isEmpty == false
    }

    var elapsedSeconds: TimeInterval? {
        guard let startedAtMillis else { return nil }
        return max(Date().timeIntervalSince1970 - (Double(startedAtMillis) / 1000), 0)
    }

    var bytesPerSecond: Double? {
        guard let elapsedSeconds, elapsedSeconds > 0.2 else { return nil }
        let bytes = status == "finished" ? totalBytes : transferredBytes
        return Double(bytes) / elapsedSeconds
    }

    var averageBytesPerSecond: Double? {
        guard status == "finished" else { return nil }
        return bytesPerSecond
    }

    var estimatedRemainingSeconds: TimeInterval? {
        guard ["sending", "receiving"].contains(status),
              let bytesPerSecond,
              bytesPerSecond > 0,
              totalBytes > transferredBytes else {
            return nil
        }
        return Double(totalBytes - transferredBytes) / bytesPerSecond
    }
}
