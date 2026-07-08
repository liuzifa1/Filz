import SwiftData
import SwiftUI
import UIKit

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case sent
    case received
    case failed

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CoreStatus.self) private var coreStatus
    @Query(sort: \TransferHistoryEntry.timestamp, order: .reverse)
    private var entries: [TransferHistoryEntry]

    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all

    private var activeTransfers: [ActiveTransfer] {
        var transfers: [ActiveTransfer] = []
        if let progress = coreStatus.sendProgress,
           ["waiting", "sending"].contains(progress.status) {
            transfers.append(ActiveTransfer(direction: .sent, progress: progress, request: nil))
        }
        if let request = coreStatus.pendingReceiveRequest {
            transfers.append(ActiveTransfer(
                direction: .received,
                progress: receiveProgress(for: request),
                request: request
            ))
            return transfers
        }
        if let progress = coreStatus.receiveProgress,
           ["waiting", "approved", "receiving"].contains(progress.status) {
            transfers.append(ActiveTransfer(direction: .received, progress: progress, request: nil))
        }
        return transfers
    }

    private var filteredEntries: [TransferHistoryEntry] {
        entries.filter { entry in
            let matchesFilter = switch filter {
            case .all: true
            case .sent: entry.direction == .sent
            case .received: entry.direction == .received
            case .failed: entry.result == .failed
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || entry.peerName.localizedCaseInsensitiveContains(query)
                || (entry.textMessage?.localizedCaseInsensitiveContains(query) == true)
                || entry.fileNames.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesFilter && matchesSearch
        }
    }

    private var groupedEntries: [HistoryTimeGroup] {
        var groups: [HistoryTimeGroup] = []
        for entry in filteredEntries {
            if let last = groups.last,
               let newest = last.entries.first,
               abs(newest.timestamp.timeIntervalSince(entry.timestamp)) <= 15 * 60 {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(HistoryTimeGroup(entries: [entry]))
            }
        }
        return groups
    }

    var body: some View {
        List {
            if !activeTransfers.isEmpty {
                Section("Active Transfers") {
                    ForEach(activeTransfers) { transfer in
                        NavigationLink {
                            if let request = transfer.request {
                                IncomingReceiveRequestDetailView(request: request) { accepted in
                                    coreStatus.decideReceive(accepted: accepted)
                                }
                            } else {
                                TransferProgressDetailView(direction: transfer.direction, progress: transfer.progress)
                            }
                        } label: {
                            ActiveTransferRow(transfer: transfer)
                        }
                        .swipeActions(edge: .leading) {
                            if transfer.request != nil {
                                Button("Accept", systemImage: "checkmark") {
                                    coreStatus.decideReceive(accepted: true)
                                }
                                .tint(.green)
                            } else if transfer.direction == .received,
                                      transfer.progress.status == "waiting",
                                      let requestID = transfer.progress.requestID {
                                Button("Accept", systemImage: "checkmark") {
                                    coreStatus.decideReceive(requestID: requestID, accepted: true)
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions {
                            if transfer.request != nil {
                                Button("Decline", systemImage: "xmark", role: .destructive) {
                                    coreStatus.decideReceive(accepted: false)
                                }
                            } else if transfer.direction == .received,
                                      transfer.progress.status == "waiting",
                                      let requestID = transfer.progress.requestID {
                                Button("Decline", systemImage: "xmark", role: .destructive) {
                                    coreStatus.decideReceive(requestID: requestID, accepted: false)
                                }
                            } else {
                                Button("Cancel", systemImage: "xmark", role: .destructive) {
                                    cancel(transfer)
                                }
                            }
                        }
                    }
                }
            }

            if filteredEntries.isEmpty && activeTransfers.isEmpty {
                ContentUnavailableView {
                    Label(
                        entries.isEmpty ? "No Transfers Yet" : "No Matching Transfers",
                        systemImage: entries.isEmpty ? "clock" : "line.3.horizontal.decrease.circle"
                    )
                } description: {
                    Text(entries.isEmpty ? "Completed sends and receives will appear here." : "Change the search or filter.")
                }
            } else {
                ForEach(groupedEntries) { group in
                    Section(group.title) {
                        ForEach(group.entries) { entry in
                            NavigationLink {
                                HistoryDetailView(entry: entry)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(entry)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Device or file name")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $filter) {
                        ForEach(HistoryFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Filter history")

                Button {
                    FilesLocationOpener.openReceivedFiles()
                } label: {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Open received files")
            }
        }
    }

    private func delete(_ entry: TransferHistoryEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func cancel(_ transfer: ActiveTransfer) {
        switch transfer.direction {
        case .sent: coreStatus.cancelSend()
        case .received: coreStatus.cancelReceive()
        }
    }

    private func receiveProgress(for request: IncomingLocalSendRequest) -> LocalSendTransferProgress {
        coreStatus.receiveProgress ?? LocalSendTransferProgress(
            requestID: request.id,
            status: "waiting",
            startedAtMillis: nil,
            targetAlias: nil,
            targetIP: nil,
            targetPort: nil,
            targetProtocol: nil,
            senderAlias: request.senderAlias,
            senderIP: request.senderIP,
            senderPort: request.senderPort,
            senderProtocol: request.senderProtocol,
            senderFingerprint: request.senderFingerprint,
            currentFile: nil,
            sentBytes: nil,
            receivedBytes: 0,
            totalBytes: request.totalBytes,
            completedFiles: 0,
            totalFiles: request.files.count,
            savedPaths: nil,
            textMessage: request.textMessage,
            error: nil
        )
    }
}

private struct ActiveTransfer: Identifiable {
    let direction: TransferDirection
    let progress: LocalSendTransferProgress
    let request: IncomingLocalSendRequest?

    var id: String { request?.id ?? direction.rawValue }
    var peerName: String {
        switch direction {
        case .sent: progress.targetAlias ?? "LocalSend device"
        case .received: progress.senderAlias ?? "LocalSend device"
        }
    }
}

private struct HistoryTimeGroup: Identifiable {
    var entries: [TransferHistoryEntry]

    var id: UUID {
        entries.first?.id ?? UUID()
    }

    var title: String {
        guard let first = entries.first else { return "Transfers" }
        if entries.count == 1 {
            return first.timestamp.formatted(date: .abbreviated, time: .shortened)
        }
        let last = entries.last ?? first
        return "\(first.timestamp.formatted(date: .abbreviated, time: .shortened)) - \(last.timestamp.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ActiveTransferRow: View {
    let transfer: ActiveTransfer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transfer.direction.systemImage)
                .font(.title3)
                .foregroundStyle(transfer.direction == .sent ? .blue : .green)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(transfer.peerName).font(.headline)
                    Spacer()
                    Text(transfer.progress.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let text = transfer.progress.textMessage, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    Text("Text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: transfer.progress.fractionCompleted)
                        .animation(.linear(duration: 0.25), value: transfer.progress.fractionCompleted)
                    HStack {
                        Text(statusDetail)
                            .lineLimit(1)
                        Spacer()
                        Text(transfer.progress.percentText)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusDetail: String {
        if let currentFile = transfer.progress.currentFile {
            return currentFile
        }
        switch (transfer.direction, transfer.progress.status) {
        case (.received, "waiting"):
            return "Approval required in Send"
        case (.received, "approved"):
            return "Accepted; waiting for upload"
        case (.sent, "waiting"):
            return "Waiting for recipient approval"
        default:
            return transfer.progress.status.capitalized
        }
    }
}

private struct HistoryRow: View {
    let entry: TransferHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.result == .failed ? "exclamationmark.circle.fill" : entry.direction.systemImage)
                .font(.title3)
                .foregroundStyle(entry.result == .failed ? .red : entry.direction == .sent ? .blue : .green)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.peerName)
                    .font(.headline)
                Text(fileSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(entry.textMessage == nil ? 1 : 2)
                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileSummary: String {
        if let text = entry.textMessage, !text.isEmpty {
            return text
        }
        guard let first = entry.fileNames.first else { return entry.direction.title }
        return entry.fileNames.count == 1 ? first : "\(first) +\(entry.fileNames.count - 1)"
    }
}

private struct HistoryDetailView: View {
    let entry: TransferHistoryEntry

    var body: some View {
        List {
            Section("Transfer") {
                LabeledContent("Direction", value: entry.direction.title)
                LabeledContent("Device", value: entry.peerName)
                if let fingerprint = entry.peerFingerprint, !fingerprint.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fingerprint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(fingerprint)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))
                LabeledContent("Date", value: entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Status", value: entry.result.rawValue.capitalized)
            }
            if let text = entry.textMessage, !text.isEmpty {
                Section("Text") {
                    Text(text)
                        .textSelection(.enabled)
                    Button("Copy Text", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = text
                    }
                }
            } else {
                Section("Files") {
                    ForEach(Array(entry.fileNames.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Image(systemName: FileIcon.systemImage(forFileName: name))
                                .foregroundStyle(.secondary)
                            Text(name)
                                .lineLimit(2)
                            Spacer()
                            if index < entry.savedPaths.count {
                                Text(URL(fileURLWithPath: entry.savedPaths[index]).deletingLastPathComponent().lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !entry.savedPaths.isEmpty {
                        Button("Open in Files", systemImage: "escape") {
                            FilesLocationOpener.openReceivedFiles()
                        }
                    }
                }
            }
            if let error = entry.errorMessage {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Transfer Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: TransferHistoryEntry.self, inMemory: true)
}
