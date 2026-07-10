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
    var activeProtocol: String = "https"
    var localIPv4Addresses: [String] = NetworkInterfaceAddresses.localIPv4
    var receivePIN: String?
    var nearbyDevices: [LocalSendDevice] = LocalSendCoreClient.discoveredDevices
    var selectedFileURLs: [URL] = []
    var selectedFileSizes: [URL: Int64] = [:]
    var selectedTextPreviews: [URL: String] = [:]
    var selectedDevices: [LocalSendDevice] = []
    var transferPIN: String = ""
    var isSending: Bool = false
    var transferMessage: String?
    var transferError: String?
    var pendingReceiveRequest: IncomingLocalSendRequest?
    // Local source paths of the most recent send, retained so the sent row can
    // offer Copy while the originals remain readable in our sandbox.
    var sentSourcePaths: [String] = []
    var sendProgress: LocalSendTransferProgress?
    var receiveProgress: LocalSendTransferProgress?
    private(set) var pendingHistoryDrafts: [TransferHistoryDraft] = []
    private var lastReceiveStatus: String?
    private var lastReceiveRequestID: String?
    private var saveReceivedMediaToGallery = false

    var currentNetworkKey: String {
        NetworkInterfaceAddresses.networkKey(from: localIPv4Addresses)
    }

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
            LocalSendCoreClient.clearLastError()
        }
    }

    func refreshDiscovery() {
        LocalSendCoreClient.refreshDiscovery()
        refresh()
    }

    func selectFiles(_ urls: [URL]) {
        selectedFileURLs = urls
        selectedFileSizes = urls.reduce(into: [:]) { result, url in
            result[url] = fileSize(for: url)
        }
        selectedTextPreviews = [:]
        transferMessage = nil
        transferError = nil
    }

    func addFiles(_ urls: [URL]) {
        let additions = urls.filter { !selectedFileURLs.contains($0) }
        guard !additions.isEmpty else { return }
        selectedFileURLs.append(contentsOf: additions)
        for url in additions {
            selectedFileSizes[url] = fileSize(for: url)
        }
        transferMessage = nil
        transferError = nil
    }

    func addTextFile(_ url: URL, preview: String) {
        addFiles([url])
        selectedTextPreviews[url] = preview
    }

    func selectTextMessage(_ url: URL, preview: String) {
        // LocalSend recognizes an instant text message only when it is the
        // sole text/* item and carries a non-empty preview.
        selectedFileURLs = [url]
        selectedFileSizes = [url: fileSize(for: url)]
        selectedTextPreviews = [url: preview]
        transferMessage = nil
        transferError = nil
    }

    func clearSelectedFile() {
        guard !isSending else { return }
        selectedFileURLs = []
        selectedFileSizes = [:]
        selectedTextPreviews = [:]
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

    @discardableResult
    func validateSendPreconditions(portText: String) -> Bool {
        guard !selectedFileURLs.isEmpty else {
            transferError = String(localized: "Add one or more attachments before sending.")
            return false
        }
        guard !selectedDevices.isEmpty else {
            transferError = String(localized: "Choose at least one destination.")
            return false
        }
        guard (UInt16(portText) ?? 0) > 0 else {
            transferError = String(localized: "Enter a valid local server port in Settings.")
            return false
        }
        return true
    }

    func sendSelectedFiles(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        saveToHistory: Bool
    ) async {
        guard !isSending else { return }
        guard validateSendPreconditions(portText: portText),
              let senderPort = UInt16(portText) else {
            return
        }

        isSending = true
        transferError = nil
        transferMessage = String(localized: "Preparing \(selectedFileURLs.count) items for \(selectedDevices.count) destinations...")

        let files = selectedFileURLs.map { fileURL in
            LocalSendFile(
                filePath: fileURL.path,
                fileName: fileURL.lastPathComponent,
                fileType: UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                    ?? "application/octet-stream",
                preview: selectedTextPreviews[fileURL]
            )
        }
        let senderToken = LocalSendCoreClient.identityToken
        let senderAlias = alias.isEmpty ? "Filz!" : alias
        let senderProtocol = activeProtocol
        let senderModel = deviceModel.isEmpty ? "iPhone" : deviceModel
        let senderDeviceType = deviceIcon.coreDeviceType
        let totalSize = selectedTotalSize
        let isTextOnlyTransfer = selectedFileURLs.count == 1
            && selectedFileURLs.allSatisfy { selectedTextPreviews[$0]?.isEmpty == false }
        let textMessage = isTextOnlyTransfer
            ? selectedFileURLs.compactMap { selectedTextPreviews[$0] }.first
            : nil
        let sourcePaths = isTextOnlyTransfer ? [] : files.map(\.filePath)
        sentSourcePaths = sourcePaths

        let accessedURLs = selectedFileURLs.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        var failedDevices: [LocalSendDevice] = []
        var failureMessages: [String] = []

        for device in selectedDevices {
            transferMessage = String(localized: "Waiting for \(device.alias) to accept...")
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
                    senderProtocol: senderProtocol,
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
                        fileNames: textMessage == nil ? files.map(\.fileName) : [],
                        textMessage: textMessage,
                        totalBytes: totalSize,
                        result: .failed,
                        savedPaths: sourcePaths,
                        errorMessage: error
                    )
                }
            } else if saveToHistory {
                enqueueHistory(
                    direction: .sent,
                    peerName: device.alias,
                    peerFingerprint: device.token,
                    fileNames: textMessage == nil ? files.map(\.fileName) : [],
                    textMessage: textMessage,
                    totalBytes: totalSize,
                    result: .completed,
                    savedPaths: sourcePaths
                )
            }
        }

        isSending = false
        if LocalSendCoreClient.sendProgress?.status == "canceled" {
            transferMessage = String(localized: "Send canceled.")
            transferError = nil
            refresh()
            return
        }
        if failedDevices.isEmpty {
            transferMessage = isTextOnlyTransfer
                ? String(localized: "Sent")
                : String(localized: "Sent \(files.count) items to \(selectedDevices.count) destinations.")
            transferError = nil
            selectedFileURLs = []
            selectedFileSizes = [:]
            selectedTextPreviews = [:]
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
        transferMessage = String(localized: "Send canceled.")
        transferError = nil
        TransferActivityCoordinator.shared.cancelCurrent()
        refresh()
    }

    func cancelReceive() {
        guard pendingReceiveRequest != nil || ["waiting", "approved", "receiving"].contains(receiveProgress?.status) else { return }
        LocalSendCoreClient.cancelReceive()
        pendingReceiveRequest = nil
        transferMessage = String(localized: "Receive canceled.")
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

    private func fileSize(for url: URL) -> Int64 {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .map(Int64.init) ?? 0
    }

    private func recordReceiveCompletionIfNeeded(_ progress: LocalSendTransferProgress?) {
        defer {
            lastReceiveStatus = progress?.status
            lastReceiveRequestID = progress?.requestID
        }
        // Compare the request ID too: back-to-back text messages jump straight
        // to "finished" with no intermediate status the 1s poller could see.
        guard let progress,
              progress.status != lastReceiveStatus || progress.requestID != lastReceiveRequestID,
              progress.status == "finished" || progress.status == "failed" else {
            return
        }
        let paths = progress.savedPaths ?? []
        if progress.status == "finished", saveReceivedMediaToGallery {
            MediaLibrarySaver.saveMediaFiles(at: paths)
        }
        enqueueHistory(
            direction: .received,
            peerName: progress.senderAlias ?? String(localized: "LocalSend device"),
            peerFingerprint: progress.senderFingerprint,
            fileNames: progress.textMessage == nil ? paths.map { URL(fileURLWithPath: $0).lastPathComponent } : [],
            textMessage: progress.textMessage,
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
        textMessage: String? = nil,
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
                textMessage: textMessage,
                totalBytes: totalBytes,
                result: result,
                savedPaths: savedPaths,
                errorMessage: errorMessage
            )
        )
    }

    @discardableResult
    func decideReceive(accepted: Bool) -> Bool {
        guard let request = pendingReceiveRequest else { return false }
        let error = LocalSendCoreClient.decideReceive(requestID: request.id, accepted: accepted)
        if let error {
            transferError = error
            return false
        } else {
            pendingReceiveRequest = nil
            transferError = nil
            transferMessage = accepted
                ? String(localized: "Receiving \(request.files.count) items from \(request.senderAlias)...")
                : String(localized: "Declined files from \(request.senderAlias).")
            refresh()
            return true
        }
    }

    func decideReceive(requestID: String, accepted: Bool) {
        let error = LocalSendCoreClient.decideReceive(requestID: requestID, accepted: accepted)
        if let error {
            transferError = error
        } else {
            pendingReceiveRequest = nil
            transferMessage = accepted
                ? String(localized: "Receiving files...")
                : String(localized: "Declined receive request.")
            refresh()
        }
    }

    @discardableResult
    func start(
        alias: String,
        portText: String,
        deviceModel: String,
        deviceIcon: AppDeviceIcon,
        useEncryption: Bool = true,
        receivePIN: String? = nil
    ) -> Bool {
        guard let port = UInt16(portText), port > 0 else {
            lastError = String(localized: "Enter a valid port between 1 and 65535.")
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
            alias: alias.isEmpty ? "Filz!" : alias,
            deviceModel: deviceModel.isEmpty ? "iPhone" : deviceModel,
            deviceType: deviceIcon.coreDeviceType,
            useTLS: useEncryption
        )

        lastError = error
        activePort = error == nil ? port : nil
        activeProtocol = useEncryption ? "https" : "http"
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
        useEncryption: Bool = true,
        receivePIN: String? = nil
    ) {
        stop()
        start(
            alias: alias,
            portText: portText,
            deviceModel: deviceModel,
            deviceIcon: deviceIcon,
            useEncryption: useEncryption,
            receivePIN: receivePIN
        )
    }

    func stop() {
        LocalSendCoreClient.stopServer()
        activePort = nil
        activeProtocol = "https"
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
