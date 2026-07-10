import SwiftUI
import UIKit

struct PendingReceiveRequestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CoreStatus.self) private var coreStatus

    let request: IncomingLocalSendRequest
    @State private var didAccept = false

    var body: some View {
        Group {
            if didAccept, let progress = acceptedProgress {
                TransferProgressDetailView(direction: .received, progress: progress)
                    .transition(.opacity)
            } else if didAccept {
                acceptedWaitingView
                    .transition(.opacity)
            } else {
                IncomingReceiveRequestDetailView(request: request, decision: decide)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: detailPhase)
    }

    private var acceptedProgress: LocalSendTransferProgress? {
        guard let progress = coreStatus.receiveProgress else { return nil }
        if progress.requestID == request.id {
            return progress
        }
        if progress.requestID == nil, progress.senderAlias == request.senderAlias {
            return progress
        }
        return nil
    }

    private var detailPhase: String {
        if !didAccept { return "pending" }
        return acceptedProgress == nil ? "accepted" : "progress"
    }

    private var acceptedWaitingView: some View {
        List {
            Section("Transfer") {
                LabeledContent("Status", value: String(localized: "Accepted"))
                LabeledContent("Device", value: request.senderAlias)
                LabeledContent("Items", value: request.files.count.formatted())
                LabeledContent(
                    "Size",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(request.totalBytes),
                        countStyle: .file
                    )
                )
            }

            Section("Progress") {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Waiting for sender...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Transfer Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decide(_ accepted: Bool) {
        guard coreStatus.decideReceive(accepted: accepted) else { return }
        if accepted {
            didAccept = true
        } else {
            dismiss()
        }
    }
}

struct IncomingReceiveRequestDetailView: View {
    let request: IncomingLocalSendRequest
    var decision: ((Bool) -> Void)?

    var body: some View {
        List {
            Section("Sender") {
                LabeledContent("Device", value: request.senderAlias)
                LabeledContent("Address", value: request.senderIP)
                if request.senderPort > 0 {
                    LabeledContent("Port", value: request.senderPort.formatted())
                }
                LabeledContent("Protocol", value: request.senderProtocol.uppercased())
                LabeledContent("Status", value: "Waiting for approval")
                fingerprintView(request.senderFingerprint ?? request.senderToken)
            }

            Section("Transfer") {
                LabeledContent("Items", value: request.files.count.formatted())
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(request.totalBytes), countStyle: .file))
            }

            Section("Files") {
                ForEach(request.files) { file in
                    HStack {
                        Image(systemName: FileIcon.systemImage(forFileName: file.fileName, mimeType: file.fileType))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .lineLimit(2)
                            Text(file.fileType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let preview = file.preview, !preview.isEmpty {
                                Text(preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                                    .textSelection(.enabled)
                            }
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let decision {
                Section {
                    HStack {
                        Button("Decline", role: .destructive) { decision(false) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Accept", systemImage: "checkmark") { decision(true) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Receive Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TransferProgressDetailView: View {
    let direction: TransferDirection
    let progress: LocalSendTransferProgress

    var body: some View {
        List {
            Section("Transfer") {
                LabeledContent("Direction", value: direction.title)
                LabeledContent("Status", value: progress.localizedStatus)
                LabeledContent("Device", value: peerName)
                if let address {
                    LabeledContent("Address", value: address)
                }
                if let port {
                    LabeledContent("Port", value: port.formatted())
                }
                if let transferProtocol {
                    LabeledContent("Protocol", value: transferProtocol.uppercased())
                }
                if let fingerprint = progress.senderFingerprint, !fingerprint.isEmpty {
                    fingerprintView(fingerprint)
                }
            }

            Section("Progress") {
                ProgressView(value: progress.fractionCompleted)
                    .animation(.linear(duration: 0.25), value: progress.fractionCompleted)
                LabeledContent("Progress", value: progress.percentText)
                LabeledContent("Transferred", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: progress.transferredBytes), countStyle: .file))
                LabeledContent("Total", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: progress.totalBytes), countStyle: .file))
                LabeledContent(
                    "Files",
                    value: progress.isTextMessage
                        ? String(localized: "Text")
                        : String(localized: "\(progress.completedFiles) of \(progress.totalFiles) items")
                )
                if let speed = progress.bytesPerSecond {
                    LabeledContent(progress.status == "finished" ? "Average Speed" : "Speed", value: speedText(speed))
                }
                if let remaining = progress.estimatedRemainingSeconds {
                    LabeledContent("Estimated Time", value: durationText(remaining))
                }
                if let currentFile = progress.currentFile {
                    LabeledContent("Current", value: currentFile)
                }
            }

            if let text = progress.textMessage, !text.isEmpty {
                Section("Text") {
                    Text(text)
                        .textSelection(.enabled)
                    Button("Copy Text", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = text
                    }
                }
            }

            if let savedPaths = progress.savedPaths, !savedPaths.isEmpty {
                Section("Saved Files") {
                    ForEach(savedPaths, id: \.self) { path in
                        let name = URL(fileURLWithPath: path).lastPathComponent
                        HStack {
                            Image(systemName: FileIcon.systemImage(forFileName: name))
                                .foregroundStyle(.secondary)
                            Text(name)
                                .lineLimit(2)
                        }
                    }
                    Button("Open in Files", systemImage: "escape") {
                        FilesLocationOpener.openReceivedFiles()
                    }
                }
            }

            if let error = progress.error {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Transfer Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var peerName: String {
        switch direction {
        case .sent: progress.targetAlias ?? String(localized: "LocalSend device")
        case .received: progress.senderAlias ?? String(localized: "LocalSend device")
        }
    }

    private var address: String? {
        switch direction {
        case .sent: progress.targetIP
        case .received: progress.senderIP
        }
    }

    private var port: UInt16? {
        switch direction {
        case .sent: progress.targetPort
        case .received: progress.senderPort
        }
    }

    private var transferProtocol: String? {
        switch direction {
        case .sent: progress.targetProtocol
        case .received: progress.senderProtocol
        }
    }

    private func speedText(_ bytesPerSecond: Double) -> String {
        "\(ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file))/s"
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval.rounded()), 0)
        if seconds < 60 { return String(localized: "\(seconds) seconds") }
        return String(localized: "\(seconds / 60) minutes \(seconds % 60) seconds")
    }
}

@ViewBuilder
private func fingerprintView(_ fingerprint: String) -> some View {
    if !fingerprint.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fingerprint")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fingerprint)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
