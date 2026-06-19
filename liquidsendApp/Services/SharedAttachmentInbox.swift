import Foundation

struct SharedFavouriteDevice: Codable, Identifiable, Hashable {
    let id: String
    let alias: String
    let endpoint: String
    let systemImage: String
}

struct SharedAttachmentImport {
    let urls: [URL]
    let selectedFavouriteIDs: [String]
    let openDestinationPicker: Bool
}

enum SharedAttachmentInbox {
    static let appGroup = "group.top.kitsune.filz"
    static let urlScheme = "liquidsend"
    private static let favouritesFileName = "Favourite Devices.json"
    private static let selectionFileName = "Share Selection.json"

    static func importPendingFiles() -> [URL] {
        importPendingShare().urls
    }

    static func importPendingShare() -> SharedAttachmentImport {
        let selection = consumeShareSelection()
        return SharedAttachmentImport(
            urls: movePendingFiles(),
            selectedFavouriteIDs: selection.selectedFavouriteIDs,
            openDestinationPicker: selection.openDestinationPicker
        )
    }

    static func exportFavouriteDevices(settings: SettingsModel, devices: [LocalSendDevice]) {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return
        }
        let snapshots = settings.favouriteDeviceTokens.map { token in
            let device = devices.first { $0.id == token || $0.token == token }
            return SharedFavouriteDevice(
                id: token,
                alias: device?.alias ?? "Saved Device",
                endpoint: device?.endpoint ?? token,
                systemImage: device?.systemImage ?? "desktopcomputer"
            )
        }
        let url = group.appending(path: favouritesFileName)
        if let data = try? JSONEncoder().encode(snapshots) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func movePendingFiles() -> [URL] {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return []
        }
        let source = group.appending(path: "Share Inbox", directoryHint: .isDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let destination = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Shared Attachments", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        return entries.compactMap { entry in
            guard (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            let target = uniqueURL(in: destination, named: entry.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: entry, to: target)
                return target
            } catch {
                return nil
            }
        }
    }

    private static func consumeShareSelection() -> (selectedFavouriteIDs: [String], openDestinationPicker: Bool) {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return ([], false)
        }
        let url = group.appending(path: selectionFileName)
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url),
              let selection = try? JSONDecoder().decode(ShareSelection.self, from: data) else {
            return ([], false)
        }
        return (selection.selectedFavouriteIDs, selection.openDestinationPicker)
    }

    private static func uniqueURL(in directory: URL, named name: String) -> URL {
        let initial = directory.appending(path: name)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        let source = URL(fileURLWithPath: name)
        let stem = source.deletingPathExtension().lastPathComponent
        let extensionName = source.pathExtension
        for index in 1...9_999 {
            let candidateName = extensionName.isEmpty ? "\(stem) (\(index))" : "\(stem) (\(index)).\(extensionName)"
            let candidate = directory.appending(path: candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return directory.appending(path: "\(UUID().uuidString)-\(name)")
    }

    private struct ShareSelection: Codable {
        let selectedFavouriteIDs: [String]
        let openDestinationPicker: Bool
    }
}
