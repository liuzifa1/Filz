import Foundation

enum SharedAttachmentInbox {
    static let appGroup = "group.top.kitsune.filz"
    static let urlScheme = "liquidsend"

    static func importPendingFiles() -> [URL] {
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
}
