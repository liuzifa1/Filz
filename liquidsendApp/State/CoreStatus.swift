//
//  Observables.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/24/26.
//

import Foundation
import UniformTypeIdentifiers

// Observe core status
@Observable
final class CoreStatus {
    var isCoreAvailable: Bool = LocalSendCoreClient.isAvailable
    var isCoreRunning: Bool = LocalSendCoreClient.isServerRunning
    var coreVersion: String = LocalSendCoreClient.version
    var lastError: String?
    var activePort: UInt16?
    var localIPv4Addresses: [String] = NetworkInterfaceAddresses.localIPv4
    var receivePIN: String?
    var nearbyDevices: [LocalSendDevice] = LocalSendCoreClient.discoveredDevices
    var selectedFileURLs: [URL] = []
    var selectedFileSizes: [URL: Int64] = [:]
    var isSending: Bool = false
    var transferMessage: String?
    var transferError: String?
    var pendingReceiveRequest: IncomingLocalSendRequest?
    var sendProgress: LocalSendTransferProgress?
    var receiveProgress: LocalSendTransferProgress?
    private(set) var pendingHistoryDrafts: [TransferHistoryDraft] = []
    private var lastReceiveStatus: String?

    var selectedTotalSize: Int64 {
        selectedFileSizes.values.reduce(0, +)
    }

    func refresh() {
        isCoreAvailable = LocalSendCoreClient.isAvailable
        isCoreRunning = LocalSendCoreClient.isServerRunning
        coreVersion = LocalSendCoreClient.version
        localIPv4Addresses = NetworkInterfaceAddresses.localIPv4
        nearbyDevices = LocalSendCoreClient.discoveredDevices
        pendingReceiveRequest = LocalSendCoreClient.pendingReceiveRequest
        sendProgress = LocalSendCoreClient.sendProgress
        let latestReceiveProgress = LocalSendCoreClient.receiveProgress
        recordReceiveCompletionIfNeeded(latestReceiveProgress)
        receiveProgress = latestReceiveProgress
        TransferActivityCoordinator.shared.update(send: sendProgress, receive: receiveProgress)
        if let error = LocalSendCoreClient.lastError {
            lastError = error
        }
    }

    func refreshDiscovery() {
        LocalSendCoreClient.refreshDiscovery()
        refresh()
    }

    func selectFiles(_ urls: [URL]) {
        selectedFileURLs = urls
        selectedFileSizes = urls.reduce(into: [:]) { result, url in
            result[url] = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                .map(Int64.init) ?? 0
        }
        transferMessage = nil
        transferError = nil
    }

    func addFiles(_ urls: [URL]) {
        let additions = urls.filter { !selectedFileURLs.contains($0) }
        guard !additions.isEmpty else { return }
        selectedFileURLs.append(contentsOf: additions)
        for url in additions {
            selectedFileSizes[url] = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                .map(Int64.init) ?? 0
        }
        transferMessage = nil
        transferError = nil
    }

    func clearSelectedFile() {
        guard !isSending else { return }
        selectedFileURLs = []
        selectedFileSizes = [:]
        transferMessage = nil
        transferError = nil
    }

    func sendSelectedFile(
        to device: LocalSendDevice,
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        saveToHistory: Bool
    ) async {
        guard !isSending else { return }
        guard !selectedFileURLs.isEmpty else {
            transferError = "Choose one or more files before selecting a device."
            return
        }
        guard let senderPort = UInt16(portText), senderPort > 0 else {
            transferError = "Enter a valid local server port in Settings."
            return
        }

        let accessedURLs = selectedFileURLs.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        isSending = true
        transferError = nil
        transferMessage = "Waiting for \(device.alias) to accept \(selectedFileURLs.count) item(s)..."

        let files = selectedFileURLs.map { fileURL in
            LocalSendFile(
                filePath: fileURL.path,
                fileName: fileURL.lastPathComponent,
                fileType: UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                    ?? "application/octet-stream"
            )
        }
        let senderToken = LocalSendCoreClient.identityToken
        let senderAlias = alias.isEmpty ? "LiquidSend" : alias
        let senderModel = deviceModel.isEmpty ? "iPhone" : deviceModel
        let senderDeviceType = deviceIcon.coreDeviceType

        let error = await Task.detached(priority: .userInitiated) {
            LocalSendCoreClient.sendFiles(
                files,
                to: device,
                senderAlias: senderAlias,
                senderPort: senderPort,
                senderDeviceModel: senderModel,
                senderDeviceType: senderDeviceType,
                senderToken: senderToken
            )
        }.value

        isSending = false
        if let error {
            transferMessage = nil
            transferError = error
            if saveToHistory {
                enqueueHistory(
                    direction: .sent,
                    peerName: device.alias,
                    fileNames: files.map(\.fileName),
                    totalBytes: selectedTotalSize,
                    result: .failed,
                    errorMessage: error
                )
            }
        } else {
            transferMessage = "Sent \(files.count) item(s) to \(device.alias)."
            transferError = nil
            if saveToHistory {
                enqueueHistory(
                    direction: .sent,
                    peerName: device.alias,
                    fileNames: files.map(\.fileName),
                    totalBytes: selectedTotalSize,
                    result: .completed
                )
            }
        }
        refresh()
    }

    func drainHistoryDrafts() -> [TransferHistoryDraft] {
        defer { pendingHistoryDrafts.removeAll() }
        return pendingHistoryDrafts
    }

    private func recordReceiveCompletionIfNeeded(_ progress: LocalSendTransferProgress?) {
        defer { lastReceiveStatus = progress?.status }
        guard let progress,
              progress.status != lastReceiveStatus,
              progress.status == "finished" || progress.status == "failed" else {
            return
        }
        let paths = progress.savedPaths ?? []
        enqueueHistory(
            direction: .received,
            peerName: progress.senderAlias ?? "LocalSend device",
            fileNames: paths.map { URL(fileURLWithPath: $0).lastPathComponent },
            totalBytes: Int64(clamping: progress.totalBytes),
            result: progress.status == "finished" ? .completed : .failed,
            savedPaths: paths,
            errorMessage: progress.error
        )
    }

    private func enqueueHistory(
        direction: TransferDirection,
        peerName: String,
        fileNames: [String],
        totalBytes: Int64,
        result: TransferResult,
        savedPaths: [String] = [],
        errorMessage: String? = nil
    ) {
        pendingHistoryDrafts.append(
            TransferHistoryDraft(
                timestamp: Date(),
                direction: direction,
                peerName: peerName,
                fileNames: fileNames,
                totalBytes: totalBytes,
                result: result,
                savedPaths: savedPaths,
                errorMessage: errorMessage
            )
        )
    }

    func decideReceive(accepted: Bool) {
        guard let request = pendingReceiveRequest else { return }
        let error = LocalSendCoreClient.decideReceive(requestID: request.id, accepted: accepted)
        if let error {
            transferError = error
        } else {
            pendingReceiveRequest = nil
            transferMessage = accepted
                ? "Receiving \(request.files.count) item(s) from \(request.senderAlias)..."
                : "Declined files from \(request.senderAlias)."
        }
    }

    @discardableResult
    func start(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon
    ) -> Bool {
        guard let port = UInt16(portText), port > 0 else {
            lastError = "Enter a valid port between 1 and 65535."
            return false
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let receiveDirectory = documents.appending(path: "Received Files", directoryHint: .isDirectory)
        if let directoryError = LocalSendCoreClient.configureReceiveDirectory(receiveDirectory) {
            lastError = directoryError
            return false
        }

        let error = LocalSendCoreClient.startServer(
            port: port,
            alias: alias.isEmpty ? "LiquidSend" : alias,
            deviceModel: deviceModel.isEmpty ? "iPhone" : deviceModel,
            deviceType: deviceIcon.coreDeviceType
        )

        lastError = error
        activePort = error == nil ? port : nil
        refresh()
        if error == nil {
            LocalSendCoreClient.refreshDiscovery()
        }
        return error == nil
    }

    func restart(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon
    ) {
        stop()
        start(
            alias: alias,
            portText: portText,
            deviceModel: deviceModel,
            deviceIcon: deviceIcon
        )
    }

    func stop() {
        LocalSendCoreClient.stopServer()
        activePort = nil
        lastError = nil
        refresh()
    }
}

extension AppDeviceIcon {
    var coreDeviceType: UInt8 {
        switch self {
        case .iphone: 0
        case .pc: 1
        case .browser: 2
        case .cli: 3
        case .server: 4
        }
    }
}
