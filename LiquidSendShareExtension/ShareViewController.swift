import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let appGroup = "group.top.kitsune.filz"
    private let favouritesFileName = "Favourite Devices.json"
    private let selectionFileName = "Share Selection.json"

    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sendButton = UIButton(type: .system)
    private let openButton = UIButton(type: .system)
    private var favourites: [SharedFavouriteDevice] = []
    private var selectedFavouriteIDs: Set<String> = []
    private var openDestinationPicker = false
    private var pendingOpenURL: URL?
    private var isOpening = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filz!"
        view.backgroundColor = .systemBackground
        favourites = loadFavourites()
        configureViews()
        updateSendState()
    }

    private func configureViews() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .prominent, target: self, action: #selector(send))

        statusLabel.text = "Choose where to send these items."
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        var sendConfiguration = UIButton.Configuration.filled()
        sendConfiguration.title = "Send"
        sendConfiguration.image = UIImage(systemName: "paperplane.fill")
        sendConfiguration.imagePadding = 8
        sendButton.configuration = sendConfiguration
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        var openConfiguration = UIButton.Configuration.filled()
        openConfiguration.title = "Open Filz!"
        openConfiguration.image = UIImage(systemName: "arrow.up.forward.app")
        openConfiguration.imagePadding = 8
        openButton.configuration = openConfiguration
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(openApp), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [statusLabel, sendButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [topRow, tableView, openButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        favourites.count + 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Destinations"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if indexPath.row < favourites.count {
            let device = favourites[indexPath.row]
            cell.textLabel?.text = device.alias
            cell.detailTextLabel?.text = device.endpoint
            cell.imageView?.image = UIImage(systemName: device.systemImage)
            cell.accessoryType = selectedFavouriteIDs.contains(device.id) ? .checkmark : .none
        } else {
            cell.textLabel?.text = "Others on Local Network"
            cell.detailTextLabel?.text = "Choose nearby devices in Filz!"
            cell.imageView?.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
            cell.accessoryType = openDestinationPicker ? .checkmark : .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < favourites.count {
            openDestinationPicker = false
            let id = favourites[indexPath.row].id
            if selectedFavouriteIDs.contains(id) {
                selectedFavouriteIDs.remove(id)
            } else {
                selectedFavouriteIDs.insert(id)
            }
        } else {
            openDestinationPicker.toggle()
            if openDestinationPicker {
                selectedFavouriteIDs.removeAll()
            }
        }
        tableView.reloadData()
        updateSendState()
    }

    private func updateSendState() {
        let canSend = openDestinationPicker || !selectedFavouriteIDs.isEmpty
        sendButton.isEnabled = canSend
        navigationItem.rightBarButtonItem?.isEnabled = canSend
    }

    @objc private func send() {
        queueAttachments()
    }

    private func queueAttachments() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            finish(message: "Filz! shared storage is unavailable.")
            return
        }
        let inbox = container.appending(path: "Share Inbox", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        } catch {
            finish(message: "Could not create the Filz! inbox.")
            return
        }

        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        guard !providers.isEmpty else {
            finish(message: "No attachments were provided.")
            return
        }

        statusLabel.text = "Preparing items..."
        sendButton.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false

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
                finish(message: "Filz! could not read the shared items.")
                return
            }
            saveSelection(to: container)
            statusLabel.text = savedCount == 1 ? "Opening 1 item in Filz!..." : "Opening \(savedCount) items in Filz!..."
            guard let url = URL(string: "liquidsend://shared-inbox") else {
                showOpenFailure()
                return
            }
            pendingOpenURL = url
            attemptOpen(userInitiated: false)
        }
    }

    @objc private func openApp() {
        attemptOpen(userInitiated: true)
    }

    private func attemptOpen(userInitiated: Bool) {
        guard let url = pendingOpenURL, !isOpening else { return }
        isOpening = true
        openButton.isHidden = true
        statusLabel.text = "Opening Filz!..."

        extensionContext?.open(url) { [weak self] opened in
            DispatchQueue.main.async {
                guard let self else { return }
                if opened {
                    self.completeRequest()
                } else if userInitiated, self.openThroughResponderChain(url) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.completeRequest()
                    }
                } else {
                    self.isOpening = false
                    self.showOpenFailure()
                }
            }
        }
    }

    private func showOpenFailure() {
        statusLabel.text = "Your items are ready. Tap Open Filz! to continue."
        openButton.isHidden = false
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @discardableResult
    private func openThroughResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        return false
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

    private func loadFavourites() -> [SharedFavouriteDevice] {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return []
        }
        let url = container.appending(path: favouritesFileName)
        guard let data = try? Data(contentsOf: url),
              let devices = try? JSONDecoder().decode([SharedFavouriteDevice].self, from: data) else {
            return []
        }
        return devices
    }

    private func saveSelection(to container: URL) {
        let selection = ShareSelection(
            selectedFavouriteIDs: Array(selectedFavouriteIDs),
            openDestinationPicker: openDestinationPicker
        )
        let url = container.appending(path: selectionFileName)
        if let data = try? JSONEncoder().encode(selection) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func finish(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.extensionContext?.cancelRequest(withError: NSError(
                    domain: "FilzShareExtension",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
        }
    }
}

private struct SharedFavouriteDevice: Codable {
    let id: String
    let alias: String
    let endpoint: String
    let systemImage: String
}

private struct ShareSelection: Codable {
    let selectedFavouriteIDs: [String]
    let openDestinationPicker: Bool
}
