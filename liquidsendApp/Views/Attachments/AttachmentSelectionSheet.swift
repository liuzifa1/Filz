import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CoreStatus.self) private var coreStatus
    @Query private var settings: [SettingsModel]

    let target: LocalSendDevice?

    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showTextComposer = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                if let target {
                    Section("Destination") {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.alias).font(.headline)
                                Text(target.deviceModel ?? target.endpoint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: target.systemImage)
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Section("Add") {
                    Button { showPhotoPicker = true } label: {
                        Label("Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    Button { showFileImporter = true } label: {
                        Label("Files", systemImage: "folder")
                    }
                    Button { showTextComposer = true } label: {
                        Label("Text", systemImage: "text.alignleft")
                    }
                }

                Section("Selected") {
                    if coreStatus.selectedFileURLs.isEmpty {
                        ContentUnavailableView(
                            "No Attachments",
                            systemImage: "paperclip",
                            description: Text("Add photos, files, or text to continue.")
                        )
                    } else {
                        ForEach(coreStatus.selectedFileURLs, id: \.self) { url in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: url))
                                    .foregroundStyle(.tint)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent).lineLimit(1)
                                    if let size = coreStatus.selectedFileSizes[url] {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
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
                            Button {
                                coreStatus.clearSelectedFile()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Clear attachments")
                        }
                    }
                }

                if let error = coreStatus.transferError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(target == nil ? "Attachments" : "Send Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let target {
                        Button("Send", systemImage: "paperplane.fill") {
                            send(to: target)
                        }
                        .disabled(coreStatus.selectedFileURLs.isEmpty || coreStatus.isSending || settings.first == nil)
                    } else {
                        Button("Done") { dismiss() }
                            .disabled(coreStatus.selectedFileURLs.isEmpty)
                    }
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Preparing attachments")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                coreStatus.addFiles(urls)
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 20,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, photos in
                guard !photos.isEmpty else { return }
                Task { await importPhotos(photos) }
            }
            .sheet(isPresented: $showTextComposer) {
                TextTransferComposer { url in
                    coreStatus.addFiles([url])
                }
            }
        }
    }

    private func send(to target: LocalSendDevice) {
        guard let setting = settings.first else { return }
        Task {
            await coreStatus.sendSelectedFile(
                to: target,
                alias: setting.userName,
                portText: setting.port,
                deviceModel: setting.deviceModel,
                deviceIcon: setting.selectedDeviceIcon,
                saveToHistory: setting.saveToHistory
            )
            if coreStatus.transferError == nil {
                dismiss()
            }
        }
    }

    private func importPhotos(_ photos: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            selectedPhotos = []
            isImporting = false
        }
        let directory = FileManager.default.temporaryDirectory.appending(path: "LiquidSend Photos", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var urls: [URL] = []
            for photo in photos {
                guard let data = try await photo.loadTransferable(type: Data.self) else { continue }
                let type = photo.supportedContentTypes.first ?? .jpeg
                let url = directory.appending(path: "Photo-\(UUID().uuidString).\(type.preferredFilenameExtension ?? "jpg")")
                try data.write(to: url, options: .atomic)
                urls.append(url)
            }
            if urls.isEmpty {
                coreStatus.transferError = "The selected photos could not be loaded."
            } else {
                coreStatus.addFiles(urls)
            }
        } catch {
            coreStatus.transferError = "Could not prepare photos: \(error.localizedDescription)"
        }
    }

    private func icon(for url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return "doc.fill" }
        if type.conforms(to: .image) { return "photo.fill" }
        if type.conforms(to: .text) { return "doc.text.fill" }
        if type.conforms(to: .movie) { return "video.fill" }
        return "doc.fill"
    }
}
