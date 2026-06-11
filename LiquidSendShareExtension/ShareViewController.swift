import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let appGroup = "group.top.kitsune.filz"
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.text = "Preparing for LiquidSend..."
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        queueAttachments()
    }

    private func queueAttachments() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            finish(message: "LiquidSend shared storage is unavailable.")
            return
        }
        let inbox = container.appending(path: "Share Inbox", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        } catch {
            finish(message: "Could not create the LiquidSend inbox.")
            return
        }

        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        guard !providers.isEmpty else {
            finish(message: "No attachments were provided.")
            return
        }

        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var savedCount = 0
        for provider in providers {
            dispatchGroup.enter()
            save(provider, to: inbox) { saved in
                if saved {
                    lock.lock()
                    savedCount += 1
                    lock.unlock()
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if savedCount == 0 {
                finish(message: "LiquidSend could not read the shared items.")
                return
            }
            statusLabel.text = savedCount == 1 ? "1 item added to LiquidSend" : "\(savedCount) items added to LiquidSend"
            guard let url = URL(string: "liquidsend://shared-inbox") else {
                extensionContext?.completeRequest(returningItems: nil)
                return
            }
            extensionContext?.open(url) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private func save(_ provider: NSItemProvider, to directory: URL, completion: @escaping (Bool) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] item, _ in
                let url = (item as? URL) ?? (item as? NSURL).map { $0 as URL }
                completion(url.map { self?.copy($0, to: directory) ?? false } ?? false)
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
           !provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] item, _ in
                guard let text = item as? String else {
                    completion(false)
                    return
                }
                completion(self?.write(text, to: directory) ?? false)
            }
            return
        }

        guard let identifier = provider.registeredTypeIdentifiers.first else {
            completion(false)
            return
        }
        provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, _ in
            completion(url.map { self?.copy($0, to: directory) ?? false } ?? false)
        }
    }

    private func copy(_ source: URL, to directory: URL) -> Bool {
        let name = source.lastPathComponent.isEmpty ? "Shared Item" : source.lastPathComponent
        let destination = directory.appending(path: "\(UUID().uuidString)-\(name)")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func write(_ text: String, to directory: URL) -> Bool {
        let destination = directory.appending(path: "Shared Text-\(UUID().uuidString).txt")
        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private func finish(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.extensionContext?.cancelRequest(withError: NSError(
                    domain: "LiquidSendShareExtension",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
        }
    }
}
