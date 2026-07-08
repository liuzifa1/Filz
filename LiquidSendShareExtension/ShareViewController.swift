import UIKit
import UniformTypeIdentifiers

// Hands shared items to the main app through the app group: files land in
// "Share Inbox", and "Share Manifest.json" is written last as the ready signal
// the app polls for. The app is opened immediately; nothing here blocks on it.
final class ShareViewController: UIViewController {
    private let appGroup = "group.top.kitsune.filz"
    private let selectionFileName = "Share Selection.json"
    private let manifestFileName = "Share Manifest.json"

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var hostInBackground = false
    private var itemsFinished = false
    private var didComplete = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        // The host app leaving the foreground is the reliable signal that the
        // jump to Filz! worked; the open calls give no trustworthy callback.
        NotificationCenter.default.addObserver(
            forName: .NSExtensionHostDidEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hostInBackground = true
                if self.itemsFinished {
                    self.complete()
                }
            }
        }
        Task { await run() }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "Opening Filz!"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true

        statusLabel.text = "Preparing shared items..."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontForContentSizeCategory = true

        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        let stack = UIStackView(arrangedSubviews: [titleLabel, activityIndicator, statusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    // MARK: - Flow

    private func run() async {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            finish(message: "Filz! shared storage is unavailable.")
            return
        }
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        guard !providers.isEmpty else {
            finish(message: "No shared items were provided.")
            return
        }

        statusLabel.text = "Preparing \(providers.count) item\(providers.count == 1 ? "" : "s")..."

        let inbox = container.appending(path: "Share Inbox", directoryHint: .isDirectory)
        let manifestURL = container.appending(path: manifestFileName)
        guard await Self.prepareInbox(inbox, staleManifest: manifestURL) else {
            finish(message: "Could not prepare the Filz! inbox.")
            return
        }

        // Keep this process alive while the main app takes the foreground. On
        // expiry, tear down at once: a lingering extension process blocks the
        // next share-sheet launch.
        let gate = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Finish importing shared items") { [weak self] expired in
            if expired {
                gate.signal()
                DispatchQueue.main.async { self?.complete() }
            } else {
                gate.wait()
            }
        }

        // Jump to the app immediately; the items land while it opens and the
        // app polls for the manifest before importing.
        writeJSON(
            ShareSelection(selectedFavouriteIDs: [], openDestinationPicker: true),
            to: container.appending(path: selectionFileName)
        )
        openMainApp()

        var savedItems: [SharedManifestItem] = []
        var finishedCount = 0
        for provider in providers {
            if let item = await Self.save(provider, to: inbox) {
                savedItems.append(item)
            }
            finishedCount += 1
            if providers.count > 1 {
                statusLabel.text = "Prepared \(finishedCount) of \(providers.count) items..."
            }
        }

        if savedItems.isEmpty {
            statusLabel.text = "Filz! could not read the shared items."
        } else {
            writeJSON(SharedManifest(items: savedItems), to: manifestURL)
            statusLabel.text = "Opening Filz!..."
        }
        gate.signal()
        finish(message: nil)
    }

    // Always tears down shortly: if the jump failed, the app imports the
    // inbox on its next activation anyway, so waiting on confirmation only
    // risks leaving a stale process behind.
    private func finish(message: String?) {
        if let message {
            statusLabel.text = message
            activityIndicator.stopAnimating()
        }
        itemsFinished = true
        if hostInBackground {
            complete()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.complete()
            }
        }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    // MARK: - Opening the main app

    private func openMainApp() {
        guard let url = URL(string: "liquidsend://shared-inbox") else { return }
        extensionContext?.open(url, completionHandler: nil)
        // Some hosts never deliver a useful completion from extensionContext.open.
        // If the host is still foregrounded shortly after, try the responder chain.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, !self.hostInBackground, !self.didComplete else { return }
            _ = self.openThroughResponderChain(url)
        }
    }

    private func openThroughResponderChain(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                return open(url, with: application)
            }
            responder = current.next
        }
        return false
    }

    // UIApplication.open is marked unavailable in extensions, so it has to be
    // reached through the ObjC runtime. The deprecated openURL: selector is a
    // silent no-op from extensions on modern iOS and must not be used.
    private func open(_ url: URL, with application: UIApplication) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard application.responds(to: selector) else { return false }
        typealias OpenFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        let open = unsafeBitCast(application.method(for: selector), to: OpenFunction.self)
        open(application, selector, url as NSURL, [:] as NSDictionary, nil)
        return true
    }

    // MARK: - Item materialization

    nonisolated private static func prepareInbox(_ inbox: URL, staleManifest: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            do {
                // A stale manifest would let the app import a previous share.
                try? FileManager.default.removeItem(at: staleManifest)
                try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
                let entries = try FileManager.default.contentsOfDirectory(
                    at: inbox,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                for entry in entries {
                    try? FileManager.default.removeItem(at: entry)
                }
                return true
            } catch {
                return false
            }
        }.value
    }

    nonisolated private static func save(_ provider: NSItemProvider, to directory: URL) async -> SharedManifestItem? {
        if let text = await inlineText(from: provider) {
            return writeText(text, to: directory)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
           let url = (item as? URL) ?? (item as? NSURL).map({ $0 as URL }) {
            return importFile(at: url, to: directory)
        }

        guard let identifier = bestFileTypeIdentifier(for: provider) else {
            return nil
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<SharedManifestItem?, Never>) in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: identifier) { url, _, _ in
                // The system deletes its temp copy when this handler returns,
                // so the file must be claimed synchronously here.
                continuation.resume(returning: url.flatMap { importFile(at: $0, to: directory) })
            }
        }
    }

    nonisolated private static func inlineText(from provider: NSItemProvider) async -> String? {
        let isFileBacked = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        guard !isFileBacked else { return nil }

        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil)
            let text = (item as? String)
                ?? (item as? NSAttributedString)?.string
                ?? (item as? URL)?.absoluteString
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return text
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil)
            let text = (item as? URL)?.absoluteString ?? (item as? String)
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return text
        }

        return nil
    }

    // Prefer real media/document types so Photos hands over the original file
    // instead of transcoding to whatever representation happens to be listed
    // first. Registered order is kept within each category.
    nonisolated private static func bestFileTypeIdentifier(for provider: NSItemProvider) -> String? {
        let identifiers = provider.registeredTypeIdentifiers
        let preferences: [UTType] = [.movie, .image, .audio, .pdf, .data]
        for preference in preferences {
            if let match = identifiers.first(where: { UTType($0)?.conforms(to: preference) == true }) {
                return match
            }
        }
        return identifiers.first
    }

    nonisolated private static func importFile(at source: URL, to directory: URL) -> SharedManifestItem? {
        let sourceName = source.lastPathComponent.isEmpty ? "Shared Item" : source.lastPathComponent
        let destinationName = "\(UUID().uuidString)-\(sourceName)"
        let destination = directory.appending(path: destinationName)
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let manager = FileManager.default
        // A hardlink is instant and always works for the system's temp copies,
        // which live in this extension's own sandbox. copyItem clones on APFS
        // when it can, so the fallback is usually cheap as well.
        if (try? manager.linkItem(at: source, to: destination)) == nil {
            do {
                try manager.copyItem(at: source, to: destination)
            } catch {
                return nil
            }
        }
        return SharedManifestItem(fileName: destinationName, textPreview: nil, bookmarkData: nil)
    }

    nonisolated private static func writeText(_ text: String, to directory: URL) -> SharedManifestItem? {
        let destinationName = "Shared Text-\(UUID().uuidString).txt"
        let destination = directory.appending(path: destinationName)
        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return SharedManifestItem(fileName: destinationName, textPreview: text, bookmarkData: nil)
        } catch {
            return nil
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// Wire format shared with SharedAttachmentInbox in the main app.
private struct ShareSelection: Codable {
    let selectedFavouriteIDs: [String]
    let openDestinationPicker: Bool
}

private struct SharedManifest: Codable {
    let items: [SharedManifestItem]
}

private struct SharedManifestItem: Codable {
    let fileName: String
    let textPreview: String?
    let bookmarkData: Data?
}
