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
    var selectedDevices: [LocalSendDevice] = []
    var transferPIN: String = ""
    var isSending: Bool = false
    var transferMessage: String?
    var transferError: String?
    var pendingReceiveRequest: IncomingLocalSendRequest?
    var sendProgress: LocalSendTransferProgress?
    var receiveProgress: LocalSendTransferProgress?
    private(set) var pendingHistoryDrafts: [TransferHistoryDraft] = []
    private var lastReceiveStatus: String?
    private var saveReceivedMediaToGallery = false

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
        TransferActivityCoordinator.shared.update(
            send: sendProgress,
            receive: receiveProgress,
            pendingReceive: pendingReceiveRequest
        )
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

    func selectDestination(_ device: LocalSendDevice, replacingExisting: Bool = false) {
        if replacingExisting {
            selectedDevices = [device]
        } else if !selectedDevices.contains(where: { $0.id == device.id }) {
            selectedDevices.append(device)
        }
        transferError = nil
    }

    func removeDestination(_ device: LocalSendDevice) {
        guard !isSending else { return }
        selectedDevices.removeAll { $0.id == device.id }
    }

    func clearDestinations() {
        guard !isSending else { return }
        selectedDevices = []
        transferPIN = ""
    }

    func sendSelectedFile(
        to device: LocalSendDevice,
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        saveToHistory: Bool
    ) async {
        selectDestination(device, replacingExisting: true)
        await sendSelectedFiles(
            alias: alias,
            portText: portText,
            deviceModel: deviceModel,
            deviceIcon: deviceIcon,
            saveToHistory: saveToHistory
        )
    }

    func sendSelectedFiles(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        saveToHistory: Bool
    ) async {
        guard !isSending else { return }
        guard !selectedFileURLs.isEmpty else {
            transferError = "Add one or more attachments before sending."
            return
        }
        guard !selectedDevices.isEmpty else {
            transferError = "Choose at least one destination."
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
        transferMessage = "Preparing \(selectedFileURLs.count) item(s) for \(selectedDevices.count) destination(s)..."

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
        let totalSize = selectedTotalSize
        var failedDevices: [LocalSendDevice] = []
        var failureMessages: [String] = []

        for device in selectedDevices {
            transferMessage = "Waiting for \(device.alias) to accept..."
            let devicePIN = device.pin?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sharedPIN = transferPIN.trimmingCharacters(in: .whitespacesAndNewlines)
            let pin = devicePIN?.isEmpty == false ? devicePIN : (sharedPIN.isEmpty ? nil : sharedPIN)
            let error = await Task.detached(priority: .userInitiated) {
                LocalSendCoreClient.sendFiles(
                    files,
                    to: device,
                    recipientPIN: pin,
                    senderAlias: senderAlias,
                    senderPort: senderPort,
                    senderDeviceModel: senderModel,
                    senderDeviceType: senderDeviceType,
                    senderToken: senderToken
                )
            }.value

            if let error {
                if error.localizedCaseInsensitiveContains("canceled") {
                    break
                }
                failedDevices.append(device)
                failureMessages.append("\(device.alias): \(error)")
                if saveToHistory {
                    enqueueHistory(
                        direction: .sent,
                        peerName: device.alias,
                        peerFingerprint: device.token,
                        fileNames: files.map(\.fileName),
                        totalBytes: totalSize,
                        result: .failed,
                        errorMessage: error
                    )
                }
            } else if saveToHistory {
                enqueueHistory(
                    direction: .sent,
                    peerName: device.alias,
                    peerFingerprint: device.token,
                    fileNames: files.map(\.fileName),
                    totalBytes: totalSize,
                    result: .completed
                )
            }
        }

        isSending = false
        if LocalSendCoreClient.sendProgress?.status == "canceled" {
            transferMessage = "Send canceled."
            transferError = nil
            refresh()
            return
        }
        if failedDevices.isEmpty {
            transferMessage = "Sent \(files.count) item(s) to \(selectedDevices.count) destination(s)."
            transferError = nil
            selectedFileURLs = []
            selectedFileSizes = [:]
            selectedDevices = []
            transferPIN = ""
        } else {
            transferMessage = nil
            selectedDevices = failedDevices
            transferError = failureMessages.joined(separator: "\n")
        }
        refresh()
    }

    func applyReceivePolicy(
        quickSave: Bool,
        quickSaveFavourites: Bool,
        favouriteDeviceTokens: Set<String>
    ) {
        guard let request = pendingReceiveRequest else { return }
        let shouldAccept = quickSave || (
            quickSaveFavourites && (
                favouriteDeviceTokens.contains(request.senderToken)
                || favouriteDeviceTokens.contains(request.senderFingerprint ?? "")
            )
        )
        if shouldAccept {
            decideReceive(accepted: true)
        }
    }

    func configureReceiveOptions(saveMediaToGallery: Bool) {
        saveReceivedMediaToGallery = saveMediaToGallery
    }

    func cancelSend() {
        guard isSending || ["waiting", "sending"].contains(sendProgress?.status) else { return }
        LocalSendCoreClient.cancelSend()
        transferMessage = "Send canceled."
        transferError = nil
        TransferActivityCoordinator.shared.cancelCurrent()
        refresh()
    }

    func cancelReceive() {
        guard pendingReceiveRequest != nil || ["waiting", "approved", "receiving"].contains(receiveProgress?.status) else { return }
        LocalSendCoreClient.cancelReceive()
        pendingReceiveRequest = nil
        transferMessage = "Receive canceled."
        transferError = nil
        TransferActivityCoordinator.shared.cancelCurrent()
        refresh()
    }

    func configureReceivePIN(_ pin: String?) {
        let normalized = pin?.trimmingCharacters(in: .whitespacesAndNewlines)
        let activePIN = normalized?.isEmpty == false ? normalized : nil
        if let error = LocalSendCoreClient.configureReceivePIN(activePIN) {
            lastError = error
        } else {
            receivePIN = activePIN
        }
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
        if progress.status == "finished", saveReceivedMediaToGallery {
            MediaLibrarySaver.saveMediaFiles(at: paths)
        }
        enqueueHistory(
            direction: .received,
            peerName: progress.senderAlias ?? "LocalSend device",
            peerFingerprint: progress.senderFingerprint,
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
        peerFingerprint: String? = nil,
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
                peerFingerprint: peerFingerprint,
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

    func decideReceive(requestID: String, accepted: Bool) {
        let error = LocalSendCoreClient.decideReceive(requestID: requestID, accepted: accepted)
        if let error {
            transferError = error
        } else {
            pendingReceiveRequest = nil
            transferMessage = accepted ? "Receiving files..." : "Declined receive request."
            refresh()
        }
    }

    @discardableResult
    func start(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        receivePIN: String? = nil
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
        configureReceivePIN(receivePIN)

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
        deviceIcon: AppDeviceIcon,
        receivePIN: String? = nil
    ) {
        stop()
        start(
            alias: alias,
            portText: portText,
            deviceModel: deviceModel,
            deviceIcon: deviceIcon,
            receivePIN: receivePIN
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
