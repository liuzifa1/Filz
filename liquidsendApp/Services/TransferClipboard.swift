//
//  TransferClipboard.swift
//  liquidsend
//
//  Shared copy-to-pasteboard logic for transfers and history. Text copies as a
//  string; files copy as item providers so images paste as images and
//  documents paste as files.
//

import Foundation
import SwiftUI
import UIKit

enum TransferClipboard {
    /// Paths that still exist and are readable from our sandbox. Received files
    /// live in our own container and always pass; a sent file that was picked
    /// from another app or has since been deleted falls away here, so we never
    /// offer a Copy that would silently do nothing.
    static func readableURLs(_ paths: [String]) -> [URL] {
        paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.isReadableFile(atPath: $0.path) }
    }

    static func canCopy(text: String?, paths: [String]) -> Bool {
        if let text, !text.isEmpty { return true }
        return !readableURLs(paths).isEmpty
    }

    @discardableResult
    static func copy(text: String?, paths: [String]) -> Bool {
        if let text, !text.isEmpty {
            UIPasteboard.general.string = text
            return true
        }
        let urls = readableURLs(paths)
        guard !urls.isEmpty else { return false }
        UIPasteboard.general.itemProviders = urls.compactMap { NSItemProvider(contentsOf: $0) }
        return true
    }
}

/// The swipe action for a transfer's content: Copy for text, Jump to (in the
/// Files app) for received files we can reveal, and Copy for any other readable
/// files. Returns nothing when there is no reachable content.
@ViewBuilder
func transferContentButton(text: String?, paths: [String]) -> some View {
    if let text, !text.isEmpty {
        Button("Copy", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = text
        }
        .tint(.blue)
    } else if let revealPath = FilesLocationOpener.revealablePath(in: paths) {
        Button("Jump to", systemImage: "escape") {
            FilesLocationOpener.reveal(path: revealPath)
        }
        .tint(.blue)
    } else if !TransferClipboard.readableURLs(paths).isEmpty {
        Button("Copy", systemImage: "doc.on.doc") {
            TransferClipboard.copy(text: nil, paths: paths)
        }
        .tint(.blue)
    }
}

func hasTransferContentAction(text: String?, paths: [String]) -> Bool {
    TransferClipboard.canCopy(text: text, paths: paths)
}
