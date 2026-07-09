//
//  SendView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/19/26.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: -
struct SendView: View {
    //@State private var shion
    @Environment(CoreStatus.self) private var coreStatus
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [SettingsModel]
    @Query private var favouriteDevices: [FavouriteDevice]
    @Query(sort: \TransferHistoryEntry.timestamp, order: .reverse)
    private var historyEntries: [TransferHistoryEntry]
    let selectDevice: (LocalSendDevice) -> Void

    private let activeSendStatuses = ["waiting", "sending"]
    private let activeReceiveStatuses = ["waiting", "approved", "receiving"]

    // Body
    var body: some View {
        List {
            // core status & ip detail for send view, at top of the screen
            Section {
                // localsend core status
                HStack(spacing: 8) {
                    Image(systemName: coreStatus.isCoreRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(coreStatus.isCoreRunning ? .green : .red)
                        .frame(width: 24, alignment: .center)
                    VStack(alignment: .leading) {
                        Text("Localsend Core")
                        Text(coreStatus.isCoreRunning ? "\(coreStatus.activeProtocol.uppercased()) server on port \(coreStatus.activePort ?? 53317)" : "Server stopped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if coreStatus.isCoreRunning {
                            coreStatus.refreshDiscovery()
                        } else if let settings = settingsList.first {
                            coreStatus.start(
                                alias: settings.userName,
                                portText: settings.port,
                                deviceModel: settings.deviceModel,
                                deviceIcon: settings.selectedDeviceIcon,
                                useEncryption: settings.usesEncryption,
                                receivePIN: settings.requirePIN ? settings.receivePIN : nil
                            )
                        }
                    } label: {
                        Image(systemName: coreStatus.isCoreRunning ? "arrow.clockwise" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(coreStatus.isCoreRunning ? "Refresh devices" : "Start server")
                }
                // Server IP
                HStack {
                    Label("Network IPs", systemImage: "network")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .labelStyle(.iconOnly)
                        .frame(width: 24, alignment: .center)
                    if coreStatus.isCoreRunning {
                        Text(addressSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                // Pins if any
                if let pin = coreStatus.receivePIN {
                    Text("PIN \(pin)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if !coreStatus.selectedFileURLs.isEmpty && !hasSendingTask {
                Section("Selected Items") {
                    ForEach(coreStatus.selectedFileURLs, id: \.self) { url in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.tint)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                if let fileSize = coreStatus.selectedFileSizes[url] {
                                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    HStack {
                        Text("\(coreStatus.selectedFileURLs.count) item(s)")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: coreStatus.selectedTotalSize, countStyle: .file))
                            .foregroundStyle(.secondary)
                        if coreStatus.isSending {
                            ProgressView()
                        } else {
                            Button {
                                coreStatus.clearSelectedFile()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Clear selected files")
                        }
                    }

                    if let message = coreStatus.transferMessage {
                        Label(message, systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let error = coreStatus.transferError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            transfersSection
            favouritesSection
            nearbyDevicesSection
        }
        .refreshable {
            coreStatus.refreshDiscovery()
            try? await Task.sleep(for: .milliseconds(500))
            coreStatus.refresh()
        }
        .onAppear {
            coreStatus.refreshDiscovery()
        }
    }

    private var addressSummary: String {
        guard !coreStatus.localIPv4Addresses.isEmpty else { return "IP unavailable" }
        let port = coreStatus.activePort ?? UInt16(settingsList.first?.port ?? "") ?? 53317
        return coreStatus.localIPv4Addresses.map { "\($0):\(port)" }.joined(separator: "  ")
    }

    // MARK: Favourites

    private var networkFavourites: [FavouriteDevice] {
        let key = coreStatus.currentNetworkKey
        return favouriteDevices
            .filter { $0.networkKey == key }
            .sorted { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
    }

    private var nearbyByToken: [String: LocalSendDevice] {
        Dictionary(coreStatus.nearbyDevices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    @ViewBuilder
    private var favouritesSection: some View {
        let favourites = networkFavourites
        if !favourites.isEmpty {
            Section("Favourites") {
                ForEach(favourites) { favourite in
                    let liveDevice = nearbyByToken[favourite.token]
                    let isOnline = liveDevice != nil
                    Button {
                        selectDevice(liveDevice ?? favourite.makeDevice())
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: favourite.systemImage)
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(favourite.alias)
                                    .font(.headline)
                                Text(favourite.deviceModel ?? favourite.endpoint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isOnline ? Color.green : Color.secondary)
                                    .frame(width: 8, height: 8)
                                Text(isOnline ? "Online" : "Offline")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(coreStatus.isSending)
                    .swipeActions(edge: .leading) {
                        Button("Unfavourite", systemImage: "star.slash") {
                            removeFavourite(token: favourite.token)
                        }
                        .tint(.gray)
                    }
                }
            }
        }
    }

    // MARK: Nearby Devices

    private var sortedNearbyDevices: [LocalSendDevice] {
        // Favourites are shown in their own section; keep only the rest here so
        // an online favourite isn't listed twice.
        let favouriteTokens = Set(settingsList.first?.favouriteDeviceTokens ?? [])
        return coreStatus.nearbyDevices
            .filter { !favouriteTokens.contains($0.id) }
            .sorted { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
    }

    @ViewBuilder
    private var nearbyDevicesSection: some View {
        Section("Nearby Devices") {
            if sortedNearbyDevices.isEmpty {
                ContentUnavailableView {
                    Label(
                        coreStatus.isCoreRunning ? "No nearby devices" : "LocalSend Core is stopped",
                        systemImage: coreStatus.isCoreRunning ? "antenna.radiowaves.left.and.right" : "stop.circle"
                    )
                } description: {
                    if coreStatus.isCoreRunning {
                        Text("Check if both devices are on the same network.")
                    } else {
                        Text("Tap the play button above to start the server.")
                    }
                }
            } else {
                ForEach(sortedNearbyDevices) { device in
                    Button {
                        selectDevice(device)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: device.systemImage)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.alias)
                                    .font(.headline)
                                Text(device.deviceModel ?? device.endpoint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(device.protocol.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(coreStatus.isSending)
                    .swipeActions(edge: .leading) {
                        Button("Favourite", systemImage: "star.fill") {
                            addFavourite(device)
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
    }

    private func addFavourite(_ device: LocalSendDevice) {
        guard let settings = settingsList.first, !settings.isFavourite(device) else { return }
        settings.toggleFavourite(device)
        // Snapshot immediately so it appears in Favourites without waiting for
        // the next poll tick.
        FavouriteStore.syncSnapshots(
            devices: [device],
            favouriteTokens: [device.id],
            networkKey: coreStatus.currentNetworkKey,
            context: modelContext
        )
    }

    private func removeFavourite(token: String) {
        if let settings = settingsList.first,
           let index = settings.favouriteDeviceTokens.firstIndex(of: token) {
            settings.favouriteDeviceTokens.remove(at: index)
        }
        FavouriteStore.removeSnapshots(token: token, context: modelContext)
    }

    // Only an in-flight send hides the selection; terminal statuses persist in
    // the core forever, so including them would hide newly selected files (and
    // the transferError label) for the rest of the session.
    private var hasSendingTask: Bool {
        guard let status = coreStatus.sendProgress?.status else { return coreStatus.isSending }
        return coreStatus.isSending || activeSendStatuses.contains(status)
    }

    // MARK: Transfers (combined send + receive)

    private enum TransferItem: Identifiable {
        case pending(IncomingLocalSendRequest)
        case receive(LocalSendTransferProgress)
        case send(LocalSendTransferProgress)
        case history(TransferHistoryEntry)

        var id: String {
            switch self {
            case .pending(let request): "pending-\(request.id)"
            case .receive(let progress): "receive-\(progress.requestID ?? "active")"
            case .send: "send"
            case .history(let entry): "history-\(entry.id.uuidString)"
            }
        }
    }

    // Active transfers come live from the core (keeping their accept/cancel
    // controls); any remaining slots — up to 2 rows total — are filled with the
    // most recent History entries the user hasn't hidden. Only the 2 newest
    // entries are ever eligible, so hiding the visible rows empties the section
    // instead of pulling older history up one at a time.
    private var transferItems: [TransferItem] {
        var items: [TransferItem] = []
        if let request = coreStatus.pendingReceiveRequest {
            items.append(.pending(request))
        } else if let progress = coreStatus.receiveProgress,
                  activeReceiveStatuses.contains(progress.status) {
            items.append(.receive(progress))
        }
        if let progress = coreStatus.sendProgress,
           activeSendStatuses.contains(progress.status) {
            items.append(.send(progress))
        }
        if items.count < 2 {
            let recent = historyEntries
                .prefix(2)
                .filter { !$0.hiddenFromRecents }
                .prefix(2 - items.count)
            items.append(contentsOf: recent.map(TransferItem.history))
        }
        return Array(items.prefix(2))
    }

    @ViewBuilder
    private var transfersSection: some View {
        let items = transferItems
        if !items.isEmpty {
            Section("Transfers") {
                ForEach(items) { item in
                    transferRow(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func transferRow(for item: TransferItem) -> some View {
        switch item {
        case .pending(let request):
            NavigationLink {
                IncomingReceiveRequestDetailView(request: request) { accepted in
                    coreStatus.decideReceive(accepted: accepted)
                }
            } label: {
                TransferRow(
                    direction: .receive,
                    title: request.senderAlias,
                    status: "Waiting for approval",
                    detail: "\(request.files.count) item(s), \(ByteCountFormatter.string(fromByteCount: Int64(request.totalBytes), countStyle: .file))",
                    fraction: coreStatus.receiveProgress?.fractionCompleted ?? 0,
                    percent: coreStatus.receiveProgress?.percentText ?? "0%",
                    textMessage: nil,
                    icon: "hand.raised.circle.fill",
                    color: .orange
                )
            }
            .swipeActions(edge: .leading) {
                Button("Accept", systemImage: "checkmark") {
                    coreStatus.decideReceive(accepted: true)
                }
                .tint(.green)
            }
            .swipeActions {
                Button("Decline", systemImage: "xmark", role: .destructive) {
                    coreStatus.decideReceive(accepted: false)
                }
            }

        case .receive(let progress):
            NavigationLink {
                TransferProgressDetailView(direction: .received, progress: progress)
            } label: {
                TransferRow(
                    direction: .receive,
                    title: progress.senderAlias ?? "LocalSend device",
                    status: receiveStatusText(progress),
                    detail: transferDetailText(progress),
                    fraction: progress.fractionCompleted,
                    percent: progress.percentText,
                    textMessage: progress.textMessage,
                    icon: receiveStatusIcon(progress),
                    color: receiveStatusColor(progress)
                )
            }
            .swipeActions(edge: .leading) {
                if progress.status == "waiting", let requestID = progress.requestID {
                    Button("Accept", systemImage: "checkmark") {
                        coreStatus.decideReceive(requestID: requestID, accepted: true)
                    }
                    .tint(.green)
                } else if hasTransferContentAction(text: progress.textMessage, paths: progress.savedPaths ?? []) {
                    transferContentButton(text: progress.textMessage, paths: progress.savedPaths ?? [])
                }
            }
            .swipeActions {
                if progress.status == "waiting", let requestID = progress.requestID {
                    Button("Decline", systemImage: "xmark", role: .destructive) {
                        coreStatus.decideReceive(requestID: requestID, accepted: false)
                    }
                } else if ["approved", "receiving"].contains(progress.status) {
                    Button("Cancel", systemImage: "xmark", role: .destructive) {
                        coreStatus.cancelReceive()
                    }
                }
            }
            if let error = progress.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

        case .send(let progress):
            NavigationLink {
                TransferProgressDetailView(direction: .sent, progress: progress)
            } label: {
                TransferRow(
                    direction: .send,
                    title: progress.targetAlias ?? "LocalSend device",
                    status: sendStatusText(progress),
                    detail: transferDetailText(progress),
                    fraction: progress.fractionCompleted,
                    percent: progress.percentText,
                    textMessage: progress.textMessage,
                    icon: sendStatusIcon(progress),
                    color: sendStatusColor(progress)
                )
            }
            .swipeActions(edge: .leading) {
                if hasTransferContentAction(text: progress.textMessage, paths: coreStatus.sentSourcePaths) {
                    transferContentButton(text: progress.textMessage, paths: coreStatus.sentSourcePaths)
                }
            }
            .swipeActions {
                if activeSendStatuses.contains(progress.status) {
                    Button("Cancel", systemImage: "xmark", role: .destructive) {
                        coreStatus.cancelSend()
                    }
                }
            }
            if let error = progress.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

        case .history(let entry):
            NavigationLink {
                HistoryDetailView(entry: entry)
            } label: {
                TransferRow(
                    direction: entry.direction == .sent ? .send : .receive,
                    title: entry.peerName,
                    status: historyStatusText(entry),
                    detail: historyDetailText(entry),
                    fraction: nil,
                    percent: nil,
                    textMessage: entry.textMessage,
                    icon: historyIcon(entry),
                    color: historyColor(entry)
                )
            }
            .swipeActions(edge: .leading) {
                if hasTransferContentAction(text: entry.textMessage, paths: entry.savedPaths) {
                    transferContentButton(text: entry.textMessage, paths: entry.savedPaths)
                }
            }
            .swipeActions {
                Button("Hide", systemImage: "eye.slash") {
                    entry.hiddenFromRecents = true
                    try? modelContext.save()
                }
                .tint(.gray)
            }
        }
    }

    private func historyStatusText(_ entry: TransferHistoryEntry) -> String {
        if entry.result == .failed { return "Failed" }
        return entry.direction == .sent ? "Sent" : "Received"
    }

    private func historyIcon(_ entry: TransferHistoryEntry) -> String {
        entry.result == .failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private func historyColor(_ entry: TransferHistoryEntry) -> Color {
        entry.result == .failed ? .red : .green
    }

    private func historyDetailText(_ entry: TransferHistoryEntry) -> String {
        if let text = entry.textMessage, !text.isEmpty { return "Text" }
        guard let first = entry.fileNames.first else { return entry.direction.title }
        return entry.fileNames.count == 1 ? first : "\(first) +\(entry.fileNames.count - 1)"
    }

    private func sendStatusText(_ progress: LocalSendTransferProgress) -> String {
        switch progress.status {
        case "waiting":
            return "Waiting for approval"
        case "sending":
            return "Sending files"
        case "finished":
            return "Transfer complete"
        case "failed":
            if progress.error?.localizedCaseInsensitiveContains("accept") == true {
                return "Rejected"
            }
            return "Transfer failed"
        case "canceled":
            return "Canceled"
        default:
            return progress.status.capitalized
        }
    }

    private func sendStatusIcon(_ progress: LocalSendTransferProgress) -> String {
        switch progress.status {
        case "waiting": return "hourglass.circle.fill"
        case "finished": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.triangle.fill"
        case "canceled": return "xmark.circle.fill"
        default: return "arrow.up.circle.fill"
        }
    }

    private func sendStatusColor(_ progress: LocalSendTransferProgress) -> Color {
        switch progress.status {
        case "waiting": return .orange
        case "failed", "canceled": return .red
        default: return .blue
        }
    }

    private func receiveStatusText(_ progress: LocalSendTransferProgress) -> String {
        switch progress.status {
        case "waiting":
            return "Waiting for approval"
        case "approved":
            return "Accepted; waiting for upload"
        case "receiving":
            return "Receiving files"
        case "finished":
            return "Transfer complete"
        case "failed":
            return "Transfer failed"
        default:
            return progress.status.capitalized
        }
    }

    private func receiveStatusIcon(_ progress: LocalSendTransferProgress) -> String {
        switch progress.status {
        case "waiting": return "hand.raised.circle.fill"
        case "finished": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.triangle.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private func receiveStatusColor(_ progress: LocalSendTransferProgress) -> Color {
        switch progress.status {
        case "waiting": return .orange
        case "failed": return .red
        default: return .green
        }
    }

    private func transferDetailText(_ progress: LocalSendTransferProgress) -> String {
        if let text = progress.textMessage, !text.isEmpty {
            return "Text"
        }
        return progress.currentFile ?? "\(progress.completedFiles) of \(progress.totalFiles) item(s)"
    }

}

private struct TransferRow: View {
    enum Direction {
        case send, receive

        var badge: String {
            switch self {
            case .send: "arrow.up"
            case .receive: "arrow.down"
            }
        }

        var label: String {
            switch self {
            case .send: "Sending"
            case .receive: "Receiving"
            }
        }
    }

    let direction: Direction
    let title: String
    let status: String
    let detail: String
    // nil fraction = a completed (history) row: no progress bar, just detail.
    let fraction: Double?
    let percent: String?
    let textMessage: String?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: direction.badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(color, in: Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        .offset(x: 4, y: 2)
                }
                .accessibilityLabel(direction.label)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let textPreview {
                    Text(textPreview)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let fraction {
                    ProgressView(value: fraction)
                        .animation(.linear(duration: 0.25), value: fraction)
                    HStack {
                        Text(detail)
                            .lineLimit(1)
                        Spacer()
                        if let percent {
                            Text(percent)
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var textPreview: String? {
        guard let textMessage, !textMessage.isEmpty else { return nil }
        let preview = textMessage.singleLineTransferPreview
        return preview.isEmpty ? nil : preview
    }
}

private extension String {
    var singleLineTransferPreview: String {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

#Preview {
    SendView(selectDevice: { _ in })
        .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self, FavouriteDevice.self], inMemory: true)
        .environment(CoreStatus())
}
