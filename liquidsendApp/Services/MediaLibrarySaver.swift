import Foundation
import Photos
import UniformTypeIdentifiers

enum MediaLibrarySaver {
    private static let firstRunPromptKey = "FilzDidPromptForPhotoLibraryAddPermission"

    @MainActor
    static var canSaveToPhotoLibrary: Bool {
        isAuthorized(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    @MainActor
    static var isPhotoLibraryPermissionDenied: Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    @MainActor
    static func shouldPromptForPhotoLibraryPermissionOnFirstRun() -> Bool {
        !UserDefaults.standard.bool(forKey: firstRunPromptKey)
            && PHPhotoLibrary.authorizationStatus(for: .addOnly) == .notDetermined
    }

    @MainActor
    static func markFirstRunPhotoLibraryPromptHandled() {
        UserDefaults.standard.set(true, forKey: firstRunPromptKey)
    }

    @MainActor
    static func requestPhotoLibraryAddPermission(markFirstRunPromptHandled: Bool = false) async -> Bool {
        if markFirstRunPromptHandled {
            Self.markFirstRunPhotoLibraryPromptHandled()
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .notDetermined else {
            return isAuthorized(status)
        }

        let requested = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return isAuthorized(requested)
    }

    static func saveMediaFiles(at paths: [String]) {
        let mediaURLs = paths.map(URL.init(fileURLWithPath:)).filter { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return type.conforms(to: .image) || type.conforms(to: .movie)
        }
        guard !mediaURLs.isEmpty else { return }

        Task { @MainActor in
            guard await requestPhotoLibraryAddPermission() else { return }

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

    private static func isAuthorized(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }
}
