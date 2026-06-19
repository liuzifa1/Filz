import Foundation
import Photos
import UniformTypeIdentifiers

enum MediaLibrarySaver {
    static func saveMediaFiles(at paths: [String]) {
        let mediaURLs = paths.map(URL.init(fileURLWithPath:)).filter { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return type.conforms(to: .image) || type.conforms(to: .movie)
        }
        guard !mediaURLs.isEmpty else { return }

        Task { @MainActor in
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            let authorized: Bool
            switch status {
            case .authorized, .limited:
                authorized = true
            case .notDetermined:
                let requested = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                authorized = requested == .authorized || requested == .limited
            default:
                authorized = false
            }
            guard authorized else { return }

            try? await PHPhotoLibrary.shared().performChanges {
                for url in mediaURLs {
                    if let type = UTType(filenameExtension: url.pathExtension),
                       type.conforms(to: .movie) {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    }
                }
            }
        }
    }
}
