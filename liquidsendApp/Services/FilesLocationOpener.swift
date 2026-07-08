import Foundation
import UIKit

enum FilesLocationOpener {
    static var receivedFilesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "Received Files", directoryHint: .isDirectory)
    }

    static func openReceivedFiles() {
        try? FileManager.default.createDirectory(at: receivedFilesDirectory, withIntermediateDirectories: true)
        // The Files app expects the folder's real filesystem path with the
        // scheme swapped to shareddocuments; bundle-identifier forms are not
        // understood and land on the browse root instead.
        var components = URLComponents(url: receivedFilesDirectory, resolvingAgainstBaseURL: false)
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
