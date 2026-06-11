import SwiftData
import SwiftUI

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
    @Query(sort: \TransferHistoryEntry.timestamp, order: .reverse)
    private var entries: [TransferHistoryEntry]

    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all
    @State private var showClearConfirmation = false

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
                || entry.fileNames.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        List {
            if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label(
                        entries.isEmpty ? "No Transfers Yet" : "No Matching Transfers",
                        systemImage: entries.isEmpty ? "clock" : "line.3.horizontal.decrease.circle"
                    )
                } description: {
                    Text(entries.isEmpty ? "Completed sends and receives will appear here." : "Change the search or filter.")
                }
            } else {
                ForEach(filteredEntries) { entry in
                    NavigationLink {
                        HistoryDetailView(entry: entry)
                    } label: {
                        HistoryRow(entry: entry)
                    }
                }
                .onDelete(perform: delete)
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

                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(entries.isEmpty)
                .accessibilityLabel("Clear history")
            }
        }
        .confirmationDialog(
            "Clear all transfer history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                entries.forEach(modelContext.delete)
                try? modelContext.save()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredEntries[index])
        }
        try? modelContext.save()
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
                    .lineLimit(1)
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
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))
                LabeledContent("Date", value: entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Status", value: entry.result.rawValue.capitalized)
            }
            Section("Files") {
                ForEach(Array(entry.fileNames.enumerated()), id: \.offset) { index, name in
                    HStack {
                        Image(systemName: "doc")
                        Text(name)
                            .lineLimit(2)
                        Spacer()
                        if index < entry.savedPaths.count {
                            ShareLink(item: URL(fileURLWithPath: entry.savedPaths[index])) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share \(name)")
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
