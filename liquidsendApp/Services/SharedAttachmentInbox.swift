import Foundation

struct SharedFavouriteDevice: Codable, Identifiable, Hashable {
    let id: String
    let alias: String
    let endpoint: String
    let systemImage: String
}

struct SharedAttachmentImport {
    let urls: [URL]
    let textPreviews: [URL: String]
    let selectedFavouriteIDs: [String]
    let openDestinationPicker: Bool
}

enum SharedAttachmentInbox {
    static let appGroup = "group.top.kitsune.filz"
    static let urlScheme = "liquidsend"
    private static let favouritesFileName = "Favourite Devices.json"
    private static let selectionFileName = "Share Selection.json"
    private static let manifestFileName = "Share Manifest.json"

    static func importPendingFiles() -> [URL] {
        importPendingShare().urls
    }

    // The share extension writes the manifest last, after every item has been
    // materialized, so its presence means the share is complete and safe to
    // import.
    static var hasPendingShare: Bool {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return false
        }
        return FileManager.default.fileExists(atPath: group.appending(path: manifestFileName).path)
    }

    static func importPendingShare() -> SharedAttachmentImport {
        let selection = consumeShareSelection()
        let manifest = consumeShareManifest()
        let movedItems = movePendingItems(manifest: manifest)
        return SharedAttachmentImport(
            urls: movedItems.map(\.url),
            textPreviews: movedItems.reduce(into: [:]) { result, item in
                if let textPreview = item.textPreview {
                    result[item.url] = textPreview
                }
            },
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
        movePendingItems(manifest: consumeShareManifest()).map(\.url)
    }

    private static func movePendingItems(manifest: ShareManifest) -> [(url: URL, textPreview: String?)] {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return []
        }
        let destination = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Shared Attachments", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        var importedItems = importBookmarkedItems(manifest: manifest, destination: destination)
        importedItems.append(contentsOf: moveInboxItems(manifest: manifest, group: group, destination: destination))
        return importedItems
    }

    private static func importBookmarkedItems(
        manifest: ShareManifest,
        destination: URL
    ) -> [(url: URL, textPreview: String?)] {
        manifest.items.compactMap { item in
            guard let bookmarkData = item.bookmarkData else { return nil }
            var stale = false
            guard let source = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                return nil
            }
            let didAccess = source.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    source.stopAccessingSecurityScopedResource()
                }
            }
            let target = uniqueURL(in: destination, named: item.fileName)
            do {
                try FileManager.default.copyItem(at: source, to: target)
                return (target, item.textPreview)
            } catch {
                return nil
            }
        }
    }

    private static func moveInboxItems(
        manifest: ShareManifest,
        group: URL,
        destination: URL
    ) -> [(url: URL, textPreview: String?)] {
        let source = group.appending(path: "Share Inbox", directoryHint: .isDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let textPreviewsByName = manifest.items.reduce(into: [String: String?]()) { result, item in
            result[item.fileName] = item.textPreview
        }

        return entries.compactMap { entry in
            guard (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            let target = uniqueURL(in: destination, named: entry.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: entry, to: target)
                return (target, textPreviewsByName[entry.lastPathComponent] ?? nil)
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

    private static func consumeShareManifest() -> ShareManifest {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return ShareManifest(items: [])
        }
        let url = group.appending(path: manifestFileName)
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ShareManifest.self, from: data) else {
            return ShareManifest(items: [])
        }
        return manifest
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

    private struct ShareManifest: Codable {
        let items: [ShareManifestItem]
    }

    private struct ShareManifestItem: Codable {
        let fileName: String
        let textPreview: String?
        let bookmarkData: Data?
    }
}
