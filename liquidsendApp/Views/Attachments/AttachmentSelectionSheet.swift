import CoreTransferable
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CoreStatus.self) private var coreStatus
    @Query private var settings: [SettingsModel]

    var showDestinationPickerOnAppear = false
    var showManualDestinationOnAppear = false
    var allowsMultipleDestinations = false

    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showTextComposer = false
    @State private var showDestinationPicker = false
    @State private var showManualDestination = false
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var didPresentInitialPanel = false

    var body: some View {
        NavigationStack {
            List {
                destinationSection
                attachmentSection

                if !coreStatus.selectedDevices.isEmpty {
                    Section {
                        TextField(
                            "PIN, if required",
                            text: Binding(
                                get: { coreStatus.transferPIN },
                                set: { coreStatus.transferPIN = $0 }
                            )
                        )
                            .textContentType(.oneTimeCode)
                            .keyboardType(.asciiCapable)
                    } header: {
                        Text("Recipient PIN")
                    } footer: {
                        Text("The same PIN is used for discovered destinations. A manual destination can provide its own PIN.")
                    }
                }

                if let error = coreStatus.transferError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { closeDraft() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", systemImage: "paperplane.fill") {
                        send()
                    }
                    .disabled(
                        coreStatus.selectedFileURLs.isEmpty
                        || coreStatus.selectedDevices.isEmpty
                        || coreStatus.isSending
                        || settings.first == nil
                    )
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
                selection: $selectedMedia,
                maxSelectionCount: 20,
                matching: .any(of: [.images, .videos]),
                preferredItemEncoding: .current
            )
            .onChange(of: selectedMedia) { _, media in
                guard !media.isEmpty else { return }
                Task { await importMedia(media) }
            }
            .sheet(isPresented: $showTextComposer) {
                TextTransferComposer { url, preview in
                    coreStatus.selectTextMessage(url, preview: preview)
                }
            }
            .sheet(isPresented: $showDestinationPicker) {
                DestinationSelectionSheet(allowsMultipleDestinations: allowsMultipleDestinations)
            }
            .sheet(isPresented: $showManualDestination) {
                NavigationStack {
                    AddClientOverIP(showsCancelButton: true) { device in
                        coreStatus.selectDestination(device, replacingExisting: !allowsMultipleDestinations)
                    }
                }
            }
            .onAppear {
                guard !didPresentInitialPanel else { return }
                didPresentInitialPanel = true
                showDestinationPicker = showDestinationPickerOnAppear
                showManualDestination = showManualDestinationOnAppear
            }
        }
    }

    private var destinationSection: some View {
        Section(allowsMultipleDestinations ? "Destinations" : "Destination") {
            if coreStatus.selectedDevices.isEmpty {
                ContentUnavailableView(
                    "No Destination",
                    systemImage: "person.2",
                    description: Text("Choose one or more devices to receive these items.")
                )
            } else {
                ForEach(coreStatus.selectedDevices) { device in
                    destinationRow(device)
                }
            }

            if coreStatus.selectedDevices.isEmpty || allowsMultipleDestinations {
                Button {
                    showDestinationPicker = true
                } label: {
                    Label(
                        coreStatus.selectedDevices.isEmpty ? "Choose Destination" : "Add Another Device",
                        systemImage: "person.badge.plus"
                    )
                }
            }

        }
    }

    private var attachmentSection: some View {
        Section("Attachments") {
            Button { showPhotoPicker = true } label: {
                Label("Photos & Videos", systemImage: "photo.on.rectangle.angled")
            }
            Button { showFileImporter = true } label: {
                Label("Files", systemImage: "folder")
            }
            Button { showTextComposer = true } label: {
                Label("Text", systemImage: "text.alignleft")
            }

            if coreStatus.selectedFileURLs.isEmpty {
                ContentUnavailableView(
                    "No Attachments",
                    systemImage: "paperclip",
                    description: Text("Add photos, videos, files, or text to continue.")
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
                    Button(role: .destructive) {
                        coreStatus.clearSelectedFile()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear attachments")
                }
            }
        }
    }

    private func destinationRow(_ device: LocalSendDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.alias).font(.headline)
                Text(device.deviceModel ?? device.endpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let setting = settings.first {
                Button {
                    setting.toggleFavourite(device)
                } label: {
                    Image(systemName: setting.isFavourite(device) ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(setting.isFavourite(device) ? "Remove favourite" : "Add favourite")
            }
            Button(role: .destructive) {
                coreStatus.removeDestination(device)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(device.alias)")
        }
    }

    private func send() {
        guard let setting = settings.first else { return }
        // Validate before dismissing so failures stay visible in this sheet.
        guard coreStatus.validateSendPreconditions(portText: setting.port) else { return }
        dismiss()
        Task {
            await coreStatus.sendSelectedFiles(
                alias: setting.userName,
                portText: setting.port,
                deviceModel: setting.deviceModel,
                deviceIcon: setting.selectedDeviceIcon,
                saveToHistory: setting.saveToHistory
            )
        }
    }

    private func closeDraft() {
        dismiss()
    }

    private func importMedia(_ media: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            selectedMedia = []
            isImporting = false
        }
        do {
            var urls: [URL] = []
            for item in media {
                guard let file = try await item.loadTransferable(type: PickedMediaFile.self) else { continue }
                urls.append(file.url)
            }
            if urls.isEmpty {
                coreStatus.transferError = String(localized: "The selected media could not be loaded.")
            } else {
                coreStatus.addFiles(urls)
            }
        } catch {
            coreStatus.transferError = String(localized: "Could not prepare media: \(error.localizedDescription)")
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

private struct PickedMediaFile: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            try stage(received)
        }
        FileRepresentation(importedContentType: .movie) { received in
            try stage(received)
        }
    }

    private static func stage(_ received: ReceivedTransferredFile) throws -> PickedMediaFile {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appending(
            path: "Filz Media",
            directoryHint: .isDirectory
        )
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceName = received.file.lastPathComponent.isEmpty
            ? "Media"
            : received.file.lastPathComponent
        let destination = directory.appending(path: "\(UUID().uuidString)-\(sourceName)")

        if !received.isOriginalFile,
           (try? manager.moveItem(at: received.file, to: destination)) != nil {
            return PickedMediaFile(url: destination)
        }
        try manager.copyItem(at: received.file, to: destination)
        return PickedMediaFile(url: destination)
    }
}

private struct DestinationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CoreStatus.self) private var coreStatus
    @Query private var settings: [SettingsModel]
    let allowsMultipleDestinations: Bool

    var body: some View {
        NavigationStack {
            List {
                let favourites = coreStatus.nearbyDevices.filter { settings.first?.isFavourite($0) == true }
                let otherDevices = coreStatus.nearbyDevices.filter { settings.first?.isFavourite($0) != true }
                if !favourites.isEmpty {
                    Section("Favourites") {
                        ForEach(favourites) { destinationButton($0) }
                    }
                }

                Section("Nearby Devices") {
                    if otherDevices.isEmpty && favourites.isEmpty {
                        ContentUnavailableView("No Nearby Devices", systemImage: "antenna.radiowaves.left.and.right")
                    } else {
                        ForEach(otherDevices) { destinationButton($0) }
                    }
                }

                Section {
                    NavigationLink {
                        AddClientOverIP { device in
                            coreStatus.selectDestination(device, replacingExisting: !allowsMultipleDestinations)
                        }
                    } label: {
                        Label("Add by IP Address", systemImage: "network")
                    }
                }
            }
            .navigationTitle("Destinations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable {
                coreStatus.refreshDiscovery()
                try? await Task.sleep(for: .milliseconds(400))
                coreStatus.refresh()
            }
        }
    }

    @ViewBuilder
    private func destinationButton(_ device: LocalSendDevice) -> some View {
        Button {
            if !allowsMultipleDestinations {
                coreStatus.selectDestination(device, replacingExisting: true)
                dismiss()
            } else if coreStatus.selectedDevices.contains(where: { $0.id == device.id }) {
                coreStatus.removeDestination(device)
            } else {
                coreStatus.selectDestination(device)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: device.systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.alias).foregroundStyle(.primary)
                    Text(device.deviceModel ?? device.endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if settings.first?.isFavourite(device) == true {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
                Image(systemName: coreStatus.selectedDevices.contains(where: { $0.id == device.id }) ? "checkmark.circle.fill" : "circle")
            }
        }
        .buttonStyle(.plain)
    }
}
