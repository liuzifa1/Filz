import Foundation
import UniformTypeIdentifiers

enum FileIcon {
    static func systemImage(forFileName name: String, mimeType: String? = nil) -> String {
        if let mimeType {
            if mimeType.hasPrefix("image/") { return "photo" }
            if mimeType.hasPrefix("video/") { return "film" }
            if mimeType.hasPrefix("audio/") { return "waveform" }
            if mimeType == "application/pdf" { return "doc.richtext" }
            if mimeType.hasPrefix("text/") { return "doc.text" }
        }
        let type = UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension)
        guard let type else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .archive) { return "archivebox" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}
