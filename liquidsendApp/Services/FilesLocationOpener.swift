import Foundation
import UIKit

enum FilesLocationOpener {
    static var receivedFilesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "Received Files", directoryHint: .isDirectory)
    }

    static func openReceivedFiles() {
        try? FileManager.default.createDirectory(at: receivedFilesDirectory, withIntermediateDirectories: true)
        let candidates = [
            URL(string: "shareddocuments://"),
            URL(string: "com.apple.DocumentsApp://")
        ].compactMap { $0 }

        guard let first = candidates.first else { return }
        UIApplication.shared.open(first)
    }
}
