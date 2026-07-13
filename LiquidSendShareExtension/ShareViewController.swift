import UIKit
import UniformTypeIdentifiers

// Hands shared items to the main app through the app group: files land in
// "Share Inbox" and "Share Manifest.json" is written last as the ready signal
// the app imports on launch. Items are materialized first (fast), then the app
// is launched and this extension tears down immediately.
final class ShareViewController: UIViewController {
    private let appGroup = "group.top.kitsune.filz"
    private let selectionFileName = "Share Selection.json"
    private let manifestFileName = "Share Manifest.json"

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var didComplete = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        Task { await run() }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        titleLabel.text = String(localized: "Opening Filz!")
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true

        statusLabel.text = String(localized: "Preparing shared items...")
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
            fail(String(localized: "Filz! shared storage is unavailable."))
            return
        }
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        guard !providers.isEmpty else {
            fail(String(localized: "No shared items were provided."))
            return
        }

        let inbox = container.appending(path: "Share Inbox", directoryHint: .isDirectory)
        let manifestURL = container.appending(path: manifestFileName)
        guard await Self.prepareInbox(inbox, staleManifest: manifestURL) else {
            fail(String(localized: "Could not prepare the Filz! inbox."))
            return
        }

        writeJSON(
            ShareSelection(selectedFavouriteIDs: [], openDestinationPicker: true),
            to: container.appending(path: selectionFileName)
        )

        // Materialize items before launching so the manifest is on disk the
        // instant the app reads it — no polling wait on the app side.
        var savedItems: [SharedManifestItem] = []
        for (index, provider) in providers.enumerated() {
            if providers.count > 1 {
                statusLabel.text = String(localized: "Preparing \(index + 1) of \(providers.count) items...")
            }
            if let item = await Self.save(provider, to: inbox) {
                savedItems.append(item)
            }
        }
        guard !savedItems.isEmpty else {
            fail(String(localized: "Filz! could not read the shared items."))
            return
        }
        writeJSON(SharedManifest(items: savedItems), to: manifestURL)

        statusLabel.text = String(localized: "Opening Filz!...")
        openMainApp()
    }

    private func openMainApp() {
        guard let url = URL(string: "filz://shared-inbox") else {
            complete()
            return
        }
        // The responder-chain UIApplication.open launches the host app
        // immediately and reliably from an extension. extensionContext.open can
        // stall for many seconds before doing anything, so it is only a
        // fallback when no UIApplication is reachable in the chain.
        if openThroughResponderChain(url) {
            // Give SpringBoard a beat to start the launch before we dismiss.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.complete()
            }
        } else {
            extensionContext?.open(url) { [weak self] _ in
                DispatchQueue.main.async { self?.complete() }
            }
            // If open never calls back (or the app can't launch), tear down
            // anyway — the files are queued and import on the next launch.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.complete()
            }
        }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func fail(_ message: String) {
        statusLabel.text = message
        activityIndicator.stopAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(
                domain: "FilzShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    // MARK: - Opening the main app

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

        if let identifier = bestFileTypeIdentifier(for: provider),
           let item = await loadFileRepresentation(provider, identifier: identifier, to: directory) {
            return item
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
           let url = (item as? URL) ?? (item as? NSURL).map({ $0 as URL }) {
            return importFile(at: url, to: directory, canMove: false)
        }

        return nil
    }

    nonisolated private static func loadFileRepresentation(
        _ provider: NSItemProvider,
        identifier: String,
        to directory: URL
    ) async -> SharedManifestItem? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<SharedManifestItem?, Never>) in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: identifier) { url, isInPlace, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                if isInPlace, let item = bookmarkFile(at: url) {
                    continuation.resume(returning: item)
                } else {
                    // Provider-owned temporary files disappear after this
                    // callback, so claim them before returning.
                    continuation.resume(returning: importFile(at: url, to: directory, canMove: !isInPlace))
                }
            }
        }
    }

    nonisolated private static func inlineText(from provider: NSItemProvider) async -> String? {
        let isFileBacked = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
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
        let identifiers = provider.registeredTypeIdentifiers.filter {
            $0 != UTType.fileURL.identifier && $0 != UTType.url.identifier
        }
        let preferences: [UTType] = [.movie, .image, .audio, .pdf, .data]
        for preference in preferences {
            if let match = identifiers.first(where: { UTType($0)?.conforms(to: preference) == true }) {
                return match
            }
        }
        return identifiers.first
    }

    nonisolated private static func bookmarkFile(at source: URL) -> SharedManifestItem? {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }
        guard let bookmarkData = try? source.bookmarkData() else { return nil }
        let sourceName = source.lastPathComponent.isEmpty
            ? String(localized: "Shared Item")
            : source.lastPathComponent
        return SharedManifestItem(fileName: sourceName, textPreview: nil, bookmarkData: bookmarkData)
    }

    nonisolated private static func importFile(
        at source: URL,
        to directory: URL,
        canMove: Bool
    ) -> SharedManifestItem? {
        let sourceName = source.lastPathComponent.isEmpty
            ? String(localized: "Shared Item")
            : source.lastPathComponent
        let destinationName = "\(UUID().uuidString)-\(sourceName)"
        let destination = directory.appending(path: destinationName)
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let manager = FileManager.default
        if canMove, (try? manager.moveItem(at: source, to: destination)) != nil {
            return SharedManifestItem(fileName: destinationName, textPreview: nil, bookmarkData: nil)
        }
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
        let destinationName = "\(String(localized: "Shared Text"))-\(UUID().uuidString).txt"
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
