//
//  SendView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/19/26.
//

import SwiftUI
import SwiftData

// MARK: -
struct SendView: View {
    //@State private var shion
    @Environment(CoreStatus.self) private var coreStatus
    @Query private var settingsList: [SettingsModel]
    let selectDevice: (LocalSendDevice) -> Void
    let selectMultiple: () -> Void
    let sendToIP: () -> Void

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
                        Text(coreStatus.isCoreRunning ? "HTTPS server on port \(coreStatus.activePort ?? 53317)" : "Server stopped")
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
                                receivePIN: settings.requirePIN ? settings.receivePIN : nil
                            )
                        }
                    } label: {
                        Image(systemName: coreStatus.isCoreRunning ? "arrow.clockwise" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(coreStatus.isCoreRunning ? "Refresh devices" : "Start server")
                }
                // Error or IP
                HStack {
                    if let error = coreStatus.lastError, !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(coreStatus.isCoreRunning ? .orange : .red)
                            .frame(width: 24, alignment: .center)
                    }
                    else {
                        Label("Network iPs",systemImage: "network")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .labelStyle(.iconOnly)
                    }
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
            if !coreStatus.selectedFileURLs.isEmpty {
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

                    if let progress = coreStatus.sendProgress,
                       progress.status == "sending" || progress.status == "waiting" {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progress.fractionCompleted)
                                .animation(.linear(duration: 0.25), value: progress.fractionCompleted)
                            HStack {
                                Text(progress.currentFile ?? "Waiting for recipient")
                                    .lineLimit(1)
                                Spacer()
                                Text(progress.percentText)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            receivingSection
            // MARK: Nearby Devices
            Section("Nearby Devices") {
                if coreStatus.nearbyDevices.isEmpty {
                    ContentUnavailableView {
                        Label(
                            coreStatus.isCoreRunning ? "No nearby devices" : "LocalSend Core is stopped",
                            systemImage: coreStatus.isCoreRunning ? "antenna.radiowaves.left.and.right" : "stop.circle"
                        )
                    } description: {
                        if coreStatus.isCoreRunning {
                            Text("Pull to refresh or check that both devices are on the same network.")
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
                                    .foregroundStyle(isFavourite(device) ? .yellow : .accentColor)
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
                            if let settings = settingsList.first, !settings.isFavourite(device) {
                                Button("Favourite", systemImage: "star.fill") {
                                    settings.toggleFavourite(device)
                                }
                                .tint(.yellow)
                            }
                        }
                        .swipeActions {
                            if let settings = settingsList.first, settings.isFavourite(device) {
                                Button("Remove", systemImage: "star.slash", role: .destructive) {
                                    settings.toggleFavourite(device)
                                }
                            }
                        }
                    }
                }
            }
            // MARK: Send to IPs
            Section {
                Button(action: sendToIP) {
                    Label("Send to IP Address", systemImage: "network")
                }
                Button(action: selectMultiple) {
                    Label("Choose Multiple Destinations", systemImage: "person.2.badge.plus")
                }
            }
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

    private var sortedNearbyDevices: [LocalSendDevice] {
        guard let settings = settingsList.first else { return coreStatus.nearbyDevices }
        return coreStatus.nearbyDevices.sorted { left, right in
            let leftFavourite = settings.isFavourite(left)
            let rightFavourite = settings.isFavourite(right)
            if leftFavourite != rightFavourite { return leftFavourite }
            return left.alias.localizedCaseInsensitiveCompare(right.alias) == .orderedAscending
        }
    }

    private func isFavourite(_ device: LocalSendDevice) -> Bool {
        settingsList.first?.isFavourite(device) ?? false
    }

    @ViewBuilder
    private var receivingSection: some View {
        if let request = coreStatus.pendingReceiveRequest {
            Section("Receiving") {
                NavigationLink {
                    IncomingReceiveRequestDetailView(request: request) { accepted in
                        coreStatus.decideReceive(accepted: accepted)
                    }
                } label: {
                    ReceiveProgressRow(
                        title: request.senderAlias,
                        status: "Waiting for approval",
                        detail: "\(request.files.count) item(s), \(ByteCountFormatter.string(fromByteCount: Int64(request.totalBytes), countStyle: .file))",
                        fraction: coreStatus.receiveProgress?.fractionCompleted ?? 0,
                        percent: coreStatus.receiveProgress?.percentText ?? "0%",
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
            }
        } else if let progress = coreStatus.receiveProgress,
                  ["waiting", "approved", "receiving", "finished", "failed"].contains(progress.status) {
            Section("Receiving") {
                NavigationLink {
                    TransferProgressDetailView(direction: .received, progress: progress)
                } label: {
                    ReceiveProgressRow(
                        title: progress.senderAlias ?? "LocalSend device",
                        status: receiveStatusText(progress),
                        detail: progress.currentFile ?? "\(progress.completedFiles) of \(progress.totalFiles) item(s)",
                        fraction: progress.fractionCompleted,
                        percent: progress.percentText,
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
            }
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
}

private struct ReceiveProgressRow: View {
    let title: String
    let status: String
    let detail: String
    let fraction: Double
    let percent: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: fraction)
                    .animation(.linear(duration: 0.25), value: fraction)
                HStack {
                    Text(detail)
                        .lineLimit(1)
                    Spacer()
                    Text(percent)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SendView(selectDevice: { _ in }, selectMultiple: {}, sendToIP: {})
        .environment(CoreStatus())
}
