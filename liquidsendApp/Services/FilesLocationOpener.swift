import Foundation
import UIKit

enum FilesLocationOpener {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var receivedFilesDirectory: URL {
        documentsDirectory.appending(path: "Received Files", directoryHint: .isDirectory)
    }

    static func openReceivedFiles() {
        try? FileManager.default.createDirectory(at: receivedFilesDirectory, withIntermediateDirectories: true)
        openInFiles(receivedFilesDirectory)
    }

    /// The first path that both exists and lives in our Documents container —
    /// the only files the Files app can navigate to via shareddocuments. Sent
    /// originals (temp / other apps' containers) are not revealable.
    static func revealablePath(in paths: [String]) -> String? {
        let documents = documentsDirectory.standardizedFileURL.path
        return paths.first { path in
            guard FileManager.default.fileExists(atPath: path) else { return false }
            return URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(documents)
        }
    }

    /// Opens the Files app at the folder containing the given file.
    static func reveal(path: String) {
        let fileURL = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let folder = isDirectory.boolValue ? fileURL : fileURL.deletingLastPathComponent()
        openInFiles(folder)
    }

    private static func openInFiles(_ folder: URL) {
        // The Files app expects the folder's real filesystem path with the
        // scheme swapped to shareddocuments; bundle-identifier forms are not
        // understood and land on the browse root instead.
        var components = URLComponents(url: folder, resolvingAgainstBaseURL: false)
        components?.scheme = "shareddocuments"
        let candidates = [
            components?.url,
            URL(string: "shareddocuments://")
        ].compactMap { $0 }
        openFirstAvailable(candidates)
    }

    private static func openFirstAvailable(_ urls: [URL]) {
        guard let url = urls.first else { return }
        UIApplication.shared.open(url) { opened in
            if !opened {
                openFirstAvailable(Array(urls.dropFirst()))
            }
        }
    }
}
