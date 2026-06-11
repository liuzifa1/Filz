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

    // MARK: Body
    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: coreStatus.isCoreRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(coreStatus.isCoreRunning ? .green : .red)
                        .frame(width: 24, alignment: .center)
                    VStack(alignment: .leading) {
                        Text("Localsend Core")
                        Text(coreStatus.isCoreRunning ? "Server running on port \(coreStatus.activePort ?? 53317)" : "Server stopped")
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
                                deviceIcon: settings.selectedDeviceIcon
                            )
                        }
                    } label: {
                        Image(systemName: coreStatus.isCoreRunning ? "arrow.clockwise" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(coreStatus.isCoreRunning ? "Refresh devices" : "Start server")
                }
                if !coreStatus.isCoreRunning, let error = coreStatus.lastError, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if coreStatus.isCoreRunning {
                    Text(addressSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if let pin = coreStatus.receivePIN {
                        Text("PIN \(pin)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let request = coreStatus.pendingReceiveRequest {
                Section("Incoming Transfer") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.senderAlias)
                                .font(.headline)
                            Text("\(request.files.count) item(s), \(ByteCountFormatter.string(fromByteCount: Int64(request.totalBytes), countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                    }
                    ForEach(request.files.prefix(4)) { file in
                        HStack {
                            Text(file.fileName)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if request.files.count > 4 {
                        Text("and \(request.files.count - 4) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Decline", role: .destructive) {
                            coreStatus.decideReceive(accepted: false)
                        }
                        Spacer()
                        Button("Accept", systemImage: "checkmark") {
                            coreStatus.decideReceive(accepted: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
                            HStack {
                                Text(progress.currentFile ?? "Waiting for recipient")
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(progress.fractionCompleted * 100))%")
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
            if let progress = coreStatus.receiveProgress,
               ["receiving", "finished", "failed"].contains(progress.status) {
                Section("Received Files") {
                    ProgressView(value: progress.fractionCompleted)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(progress.status == "finished" ? "Transfer complete" : "From \(progress.senderAlias ?? "LocalSend device")")
                            Text("\(progress.completedFiles) of \(progress.totalFiles) item(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(progress.fractionCompleted * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    if let currentFile = progress.currentFile {
                        Text(currentFile)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if progress.status == "finished" {
                        Label("Saved in Files > On My iPhone > LiquidSend > Received Files", systemImage: "folder.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let error = progress.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
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
                    ForEach(coreStatus.nearbyDevices) { device in
                        Button {
                            selectDevice(device)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
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
                        }
                        .buttonStyle(.plain)
                        .disabled(coreStatus.isSending)
                    }
                }
            }
            // MARK: Send to IPs
            Section {
                NavigationLink {
                    AddClientOverIP()
                } label: {
                    Label("Send to IP Address", systemImage: "network")
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
}

#Preview {
    SendView { _ in }
        .environment(CoreStatus())
}
