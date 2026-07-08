//
//  OpenSourceAcknowledgementsView.swift
//  liquidsend
//
//  Created by Codex on 6/19/26.
//

import Foundation
import SwiftUI

struct OpenSourceAcknowledgementsView: View {
    private let acknowledgements = OpenSourceAcknowledgement.all

    var body: some View {
        List {
            Section {
                Text("Filz! is built with open source software. Thanks to the maintainers and contributors whose work makes local, device-to-device transfer possible.")
                    .foregroundStyle(.secondary)
            }

            Section("Projects") {
                ForEach(acknowledgements) { acknowledgement in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(acknowledgement.name)
                            .font(.headline)
                        Text(acknowledgement.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LabeledContent("License", value: acknowledgement.license)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link("Source", destination: acknowledgement.url)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Text("Complete license terms are available from each project's source repository. Third-party copyright notices remain the property of their respective owners.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Open Source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OpenSourceAcknowledgement: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let license: String
    let url: URL

    static let all: [OpenSourceAcknowledgement] = [
        OpenSourceAcknowledgement(
            name: "LocalSend",
            description: "Protocol and app ecosystem that inspired Filz!'s local network discovery and transfer compatibility.",
            license: "Apache License 2.0",
            url: URL(string: "https://github.com/localsend/localsend")!
        ),
        OpenSourceAcknowledgement(
            name: "Tokio",
            description: "Asynchronous runtime used by the embedded transfer core.",
            license: "MIT",
            url: URL(string: "https://github.com/tokio-rs/tokio")!
        ),
        OpenSourceAcknowledgement(
            name: "Hyper",
            description: "HTTP server library used by the embedded transfer core.",
            license: "MIT",
            url: URL(string: "https://github.com/hyperium/hyper")!
        ),
        OpenSourceAcknowledgement(
            name: "Reqwest",
            description: "HTTP client library used for local device-to-device transfer requests.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/seanmonstar/reqwest")!
        ),
        OpenSourceAcknowledgement(
            name: "Rustls",
            description: "TLS library used by the Rust networking stack.",
            license: "Apache License 2.0 / ISC / MIT",
            url: URL(string: "https://github.com/rustls/rustls")!
        ),
        OpenSourceAcknowledgement(
            name: "Serde",
            description: "Serialization framework used to encode and decode LocalSend protocol messages.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/serde-rs/serde")!
        ),
        OpenSourceAcknowledgement(
            name: "socket2",
            description: "Low-level socket helpers used for local network discovery.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/rust-lang/socket2")!
        ),
        OpenSourceAcknowledgement(
            name: "uuid",
            description: "UUID generation used by transfer sessions and local identifiers.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/uuid-rs/uuid")!
        ),
        OpenSourceAcknowledgement(
            name: "RustCrypto",
            description: "Cryptographic primitives used by the embedded transfer core.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/RustCrypto")!
        ),
        OpenSourceAcknowledgement(
            name: "WebRTC.rs",
            description: "Rust WebRTC components included for peer connection support in the core.",
            license: "MIT / Apache License 2.0",
            url: URL(string: "https://github.com/webrtc-rs/webrtc")!
        )
    ]
}

#Preview {
    NavigationStack {
        OpenSourceAcknowledgementsView()
    }
}
