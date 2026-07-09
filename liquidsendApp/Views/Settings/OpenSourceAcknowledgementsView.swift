//
//  OpenSourceAcknowledgementsView.swift
//  liquidsend
//
//  Created by Codex on 6/19/26.
//

import Foundation
import SwiftUI

struct OpenSourceAcknowledgementsView: View {
    private let upstreamProjects = OpenSourceAcknowledgement.upstreamProjects
    private let rustCrates = OpenSourceAcknowledgement.rustCrates

    var body: some View {
        List {
            Section {
                Text("Filz! is built with open source software. This page lists the upstream LocalSend project and the resolved Rust crates used by the iOS LocalSend Core build.")
                    .foregroundStyle(.secondary)

                LabeledContent("Rust crates", value: "\(rustCrates.count)")
            }

            Section("Upstream Project") {
                ForEach(upstreamProjects) { acknowledgement in
                    acknowledgementRow(acknowledgement)
                }
            }

            Section("Rust Core Dependencies") {
                ForEach(rustCrates) { acknowledgement in
                    acknowledgementRow(acknowledgement)
                }
            }

            Section {
                Text("Cargo metadata is the source of package names, versions, authors, license expressions, descriptions, and repository links. Complete license terms remain available from each project source. Third-party copyright notices remain the property of their respective owners.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Open Source")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func acknowledgementRow(_ acknowledgement: OpenSourceAcknowledgement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(acknowledgement.displayName)
                .font(.headline)

            Text(acknowledgement.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                if let version = acknowledgement.version {
                    LabeledContent("Version", value: version)
                }
                LabeledContent("Author / maintainer", value: acknowledgement.author)
                LabeledContent("License", value: acknowledgement.license)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Link("Source", destination: acknowledgement.url)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

private struct OpenSourceAcknowledgement: Identifiable {
    var id: String { [name, version].compactMap { $0 }.joined(separator: "@") }
    let name: String
    let version: String?
    let author: String
    let license: String
    let description: String
    let url: URL

    var displayName: String {
        if let version {
            return "\(name) \(version)"
        }
        return name
    }

    static let upstreamProjects: [OpenSourceAcknowledgement] = [
        OpenSourceAcknowledgement(
            name: "LocalSend",
            version: nil,
            author: "Tien Do Nam and contributors",
            license: "Apache-2.0",
            description: "Open source cross-platform file sharing project and protocol ecosystem that Filz! is compatible with.",
            url: URL(string: "https://github.com/localsend/localsend")!
        )
    ]

    static let rustCrates: [OpenSourceAcknowledgement] = [
        OpenSourceAcknowledgement(
            name: "allocator-api2",
            version: "0.2.21",
            author: "Zakarum <zaq.dev@icloud.com>",
            license: "MIT OR Apache-2.0",
            description: "Mirror of Rust's allocator API",
            url: URL(string: "https://github.com/zakarumych/allocator-api2")!
        ),
        OpenSourceAcknowledgement(
            name: "anyhow",
            version: "1.0.100",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Flexible concrete Error type built on std::error::Error",
            url: URL(string: "https://github.com/dtolnay/anyhow")!
        ),
        OpenSourceAcknowledgement(
            name: "asn1-rs",
            version: "0.7.1",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT OR Apache-2.0",
            description: "Parser/encoder for ASN.1 BER/DER data",
            url: URL(string: "https://github.com/rusticata/asn1-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "asn1-rs-derive",
            version: "0.6.0",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT OR Apache-2.0",
            description: "Derive macros for the `asn1-rs` crate",
            url: URL(string: "https://github.com/rusticata/asn1-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "asn1-rs-impl",
            version: "0.2.0",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT/Apache-2.0",
            description: "Implementation details for the `asn1-rs` crate",
            url: URL(string: "https://github.com/rusticata/asn1-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "atomic-waker",
            version: "1.1.2",
            author: "Stjepan Glavina <stjepang@gmail.com>, Contributors to futures-rs",
            license: "Apache-2.0 OR MIT",
            description: "A synchronization primitive for task wakeup",
            url: URL(string: "https://github.com/smol-rs/atomic-waker")!
        ),
        OpenSourceAcknowledgement(
            name: "base64",
            version: "0.22.1",
            author: "Marshall Pierce <marshall@mpierce.org>",
            license: "MIT OR Apache-2.0",
            description: "encodes and decodes base64 as bytes or utf8",
            url: URL(string: "https://github.com/marshallpierce/rust-base64")!
        ),
        OpenSourceAcknowledgement(
            name: "base64ct",
            version: "1.8.0",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Pure Rust implementation of Base64 (RFC 4648) which avoids any usages of data-dependent branches/LUTs and thereby provides portable \"best effort\" constant-time operation and embedded-friendly no_std support ",
            url: URL(string: "https://github.com/RustCrypto/formats")!
        ),
        OpenSourceAcknowledgement(
            name: "bitflags",
            version: "2.9.1",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "A macro to generate structures which behave like bitflags. ",
            url: URL(string: "https://github.com/bitflags/bitflags")!
        ),
        OpenSourceAcknowledgement(
            name: "block-buffer",
            version: "0.10.4",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "Buffer type for block processing of data",
            url: URL(string: "https://github.com/RustCrypto/utils")!
        ),
        OpenSourceAcknowledgement(
            name: "byteorder",
            version: "1.5.0",
            author: "Andrew Gallant <jamslam@gmail.com>",
            license: "Unlicense OR MIT",
            description: "Library for reading/writing numbers in big-endian and little-endian.",
            url: URL(string: "https://github.com/BurntSushi/byteorder")!
        ),
        OpenSourceAcknowledgement(
            name: "bytes",
            version: "1.10.1",
            author: "Carl Lerche <me@carllerche.com>, Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "Types and traits for working with bytes",
            url: URL(string: "https://github.com/tokio-rs/bytes")!
        ),
        OpenSourceAcknowledgement(
            name: "cfg-if",
            version: "1.0.1",
            author: "Alex Crichton <alex@alexcrichton.com>",
            license: "MIT OR Apache-2.0",
            description: "A macro to ergonomically define an item depending on a large number of #[cfg] parameters. Structured like an if-else chain, the first matching branch is the item that gets emitted. ",
            url: URL(string: "https://github.com/rust-lang/cfg-if")!
        ),
        OpenSourceAcknowledgement(
            name: "const-oid",
            version: "0.9.6",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Const-friendly implementation of the ISO/IEC Object Identifier (OID) standard as defined in ITU X.660, with support for BER/DER encoding/decoding as well as heapless no_std (i.e. embedded) support ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/const-oid")!
        ),
        OpenSourceAcknowledgement(
            name: "cpufeatures",
            version: "0.2.17",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "Lightweight runtime CPU feature detection for aarch64, loongarch64, and x86/x86_64 targets,  with no_std support and support for mobile targets including Android and iOS ",
            url: URL(string: "https://github.com/RustCrypto/utils")!
        ),
        OpenSourceAcknowledgement(
            name: "crypto-common",
            version: "0.1.6",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "Common cryptographic traits",
            url: URL(string: "https://github.com/RustCrypto/traits")!
        ),
        OpenSourceAcknowledgement(
            name: "curve25519-dalek",
            version: "4.2.0",
            author: "Isis Lovecruft <isis@patternsinthevoid.net>, Henry de Valence <hdevalence@hdevalence.ca>",
            license: "BSD-3-Clause",
            description: "A pure-Rust implementation of group operations on ristretto255 and Curve25519",
            url: URL(string: "https://github.com/dalek-cryptography/curve25519-dalek/tree/main/curve25519-dalek")!
        ),
        OpenSourceAcknowledgement(
            name: "data-encoding",
            version: "2.9.0",
            author: "Julien Cretin <git@ia0.eu>",
            license: "MIT",
            description: "Efficient and customizable data-encoding functions like base64, base32, and hex",
            url: URL(string: "https://github.com/ia0/data-encoding")!
        ),
        OpenSourceAcknowledgement(
            name: "der",
            version: "0.7.10",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Pure Rust embedded-friendly implementation of the Distinguished Encoding Rules (DER) for Abstract Syntax Notation One (ASN.1) as described in ITU X.690 with full support for heapless no_std targets ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/der")!
        ),
        OpenSourceAcknowledgement(
            name: "der-parser",
            version: "10.0.0",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT OR Apache-2.0",
            description: "Parser/encoder for ASN.1 BER/DER data",
            url: URL(string: "https://github.com/rusticata/der-parser.git")!
        ),
        OpenSourceAcknowledgement(
            name: "deranged",
            version: "0.4.0",
            author: "Jacob Pratt <jacob@jhpratt.dev>",
            license: "MIT OR Apache-2.0",
            description: "Ranged integers",
            url: URL(string: "https://github.com/jhpratt/deranged")!
        ),
        OpenSourceAcknowledgement(
            name: "digest",
            version: "0.10.7",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "Traits for cryptographic hash functions and message authentication codes",
            url: URL(string: "https://github.com/RustCrypto/traits")!
        ),
        OpenSourceAcknowledgement(
            name: "displaydoc",
            version: "0.2.5",
            author: "Jane Lusby <jlusby@yaah.dev>",
            license: "MIT OR Apache-2.0",
            description: "A derive macro for implementing the display Trait via a doc comment and string interpolation ",
            url: URL(string: "https://github.com/yaahc/displaydoc")!
        ),
        OpenSourceAcknowledgement(
            name: "ed25519",
            version: "2.2.3",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Edwards Digital Signature Algorithm (EdDSA) over Curve25519 (as specified in RFC 8032) support library providing signature type definitions and PKCS#8 private key decoding/encoding support ",
            url: URL(string: "https://github.com/RustCrypto/signatures/tree/master/ed25519")!
        ),
        OpenSourceAcknowledgement(
            name: "ed25519-dalek",
            version: "2.2.0",
            author: "isis lovecruft <isis@patternsinthevoid.net>, Tony Arcieri <bascule@gmail.com>, Michael Rosenberg <michael@mrosenberg.pub>",
            license: "BSD-3-Clause",
            description: "Fast and efficient ed25519 EdDSA key generations, signing, and verification in pure Rust.",
            url: URL(string: "https://github.com/dalek-cryptography/curve25519-dalek/tree/main/ed25519-dalek")!
        ),
        OpenSourceAcknowledgement(
            name: "encoding_rs",
            version: "0.8.35",
            author: "Henri Sivonen <hsivonen@hsivonen.fi>",
            license: "(Apache-2.0 OR MIT) AND BSD-3-Clause",
            description: "A Gecko-oriented implementation of the Encoding Standard",
            url: URL(string: "https://github.com/hsivonen/encoding_rs")!
        ),
        OpenSourceAcknowledgement(
            name: "equivalent",
            version: "1.0.2",
            author: "See project metadata",
            license: "Apache-2.0 OR MIT",
            description: "Traits for key comparison in maps.",
            url: URL(string: "https://github.com/indexmap-rs/equivalent")!
        ),
        OpenSourceAcknowledgement(
            name: "fnv",
            version: "1.0.7",
            author: "Alex Crichton <alex@alexcrichton.com>",
            license: "Apache-2.0 / MIT",
            description: "Fowler–Noll–Vo hash function",
            url: URL(string: "https://github.com/servo/rust-fnv")!
        ),
        OpenSourceAcknowledgement(
            name: "foldhash",
            version: "0.1.5",
            author: "Orson Peters <orsonpeters@gmail.com>",
            license: "Zlib",
            description: "A fast, non-cryptographic, minimally DoS-resistant hashing algorithm.",
            url: URL(string: "https://github.com/orlp/foldhash")!
        ),
        OpenSourceAcknowledgement(
            name: "form_urlencoded",
            version: "1.2.1",
            author: "The rust-url developers",
            license: "MIT OR Apache-2.0",
            description: "Parser and serializer for the application/x-www-form-urlencoded syntax, as used by HTML forms.",
            url: URL(string: "https://github.com/servo/rust-url")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-channel",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Channels for asynchronous communication using futures-rs. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-core",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "The core traits and types in for the `futures` library. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-io",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "The `AsyncRead`, `AsyncWrite`, `AsyncSeek`, and `AsyncBufRead` traits for the futures-rs library. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-macro",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "The futures-rs procedural macro implementations. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-sink",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "The asynchronous `Sink` trait for the futures-rs library. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-task",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Tools for working with tasks. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "futures-util",
            version: "0.3.31",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Common utilities and extension traits for the futures-rs library. ",
            url: URL(string: "https://github.com/rust-lang/futures-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "generic-array",
            version: "0.14.7",
            author: "Bartłomiej Kamiński <fizyk20@gmail.com>, Aaron Trent <novacrazy@gmail.com>",
            license: "MIT",
            description: "Generic types implementing functionality of arrays",
            url: URL(string: "https://github.com/fizyk20/generic-array.git")!
        ),
        OpenSourceAcknowledgement(
            name: "getrandom",
            version: "0.2.16",
            author: "The Rand Project Developers",
            license: "MIT OR Apache-2.0",
            description: "A small cross-platform library for retrieving random data from system source",
            url: URL(string: "https://github.com/rust-random/getrandom")!
        ),
        OpenSourceAcknowledgement(
            name: "getrandom",
            version: "0.3.3",
            author: "The Rand Project Developers",
            license: "MIT OR Apache-2.0",
            description: "A small cross-platform library for retrieving random data from system source",
            url: URL(string: "https://github.com/rust-random/getrandom")!
        ),
        OpenSourceAcknowledgement(
            name: "h2",
            version: "0.4.12",
            author: "Carl Lerche <me@carllerche.com>, Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "An HTTP/2 client and server",
            url: URL(string: "https://github.com/hyperium/h2")!
        ),
        OpenSourceAcknowledgement(
            name: "hashbrown",
            version: "0.15.4",
            author: "Amanieu d'Antras <amanieu@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "A Rust port of Google's SwissTable hash map",
            url: URL(string: "https://github.com/rust-lang/hashbrown")!
        ),
        OpenSourceAcknowledgement(
            name: "http",
            version: "1.3.1",
            author: "Alex Crichton <alex@alexcrichton.com>, Carl Lerche <me@carllerche.com>, Sean McArthur <sean@seanmonstar.com>",
            license: "MIT OR Apache-2.0",
            description: "A set of types for representing HTTP requests and responses. ",
            url: URL(string: "https://github.com/hyperium/http")!
        ),
        OpenSourceAcknowledgement(
            name: "http-body",
            version: "1.0.1",
            author: "Carl Lerche <me@carllerche.com>, Lucio Franco <luciofranco14@gmail.com>, Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "Trait representing an asynchronous, streaming, HTTP request or response body. ",
            url: URL(string: "https://github.com/hyperium/http-body")!
        ),
        OpenSourceAcknowledgement(
            name: "http-body-util",
            version: "0.1.3",
            author: "Carl Lerche <me@carllerche.com>, Lucio Franco <luciofranco14@gmail.com>, Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "Combinators and adapters for HTTP request or response bodies. ",
            url: URL(string: "https://github.com/hyperium/http-body")!
        ),
        OpenSourceAcknowledgement(
            name: "httparse",
            version: "1.10.1",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT OR Apache-2.0",
            description: "A tiny, safe, speedy, zero-copy HTTP/1.x parser.",
            url: URL(string: "https://github.com/seanmonstar/httparse")!
        ),
        OpenSourceAcknowledgement(
            name: "httpdate",
            version: "1.0.3",
            author: "Pyfisch <pyfisch@posteo.org>",
            license: "MIT OR Apache-2.0",
            description: "HTTP date parsing and formatting",
            url: URL(string: "https://github.com/pyfisch/httpdate")!
        ),
        OpenSourceAcknowledgement(
            name: "hyper",
            version: "1.7.0",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "A protective and efficient HTTP library for all.",
            url: URL(string: "https://github.com/hyperium/hyper")!
        ),
        OpenSourceAcknowledgement(
            name: "hyper-rustls",
            version: "0.27.7",
            author: "See project metadata",
            license: "Apache-2.0 OR ISC OR MIT",
            description: "Rustls+hyper integration for pure rust HTTPS",
            url: URL(string: "https://github.com/rustls/hyper-rustls")!
        ),
        OpenSourceAcknowledgement(
            name: "hyper-util",
            version: "0.1.17",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "hyper utilities",
            url: URL(string: "https://github.com/hyperium/hyper-util")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_collections",
            version: "2.0.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Collection of API for use in ICU libraries.",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_locale_core",
            version: "2.0.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "API for managing Unicode Language and Locale Identifiers",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_normalizer",
            version: "2.0.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "API for normalizing text into Unicode Normalization Forms",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_normalizer_data",
            version: "2.0.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Data for the icu_normalizer crate",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_properties",
            version: "2.0.1",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Definitions for Unicode properties",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_properties_data",
            version: "2.0.1",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Data for the icu_properties crate",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "icu_provider",
            version: "2.0.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Trait and struct definitions for the ICU data provider",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "idna",
            version: "1.0.3",
            author: "The rust-url developers",
            license: "MIT OR Apache-2.0",
            description: "IDNA (Internationalizing Domain Names in Applications) and Punycode.",
            url: URL(string: "https://github.com/servo/rust-url/")!
        ),
        OpenSourceAcknowledgement(
            name: "idna_adapter",
            version: "1.2.1",
            author: "The rust-url developers",
            license: "Apache-2.0 OR MIT",
            description: "Back end adapter for idna",
            url: URL(string: "https://github.com/hsivonen/idna_adapter")!
        ),
        OpenSourceAcknowledgement(
            name: "indexmap",
            version: "2.11.4",
            author: "See project metadata",
            license: "Apache-2.0 OR MIT",
            description: "A hash table with consistent order and fast iteration.",
            url: URL(string: "https://github.com/indexmap-rs/indexmap")!
        ),
        OpenSourceAcknowledgement(
            name: "ipnet",
            version: "2.11.0",
            author: "Kris Price <kris@krisprice.nz>",
            license: "MIT OR Apache-2.0",
            description: "Provides types and useful methods for working with IPv4 and IPv6 network addresses, commonly called IP prefixes. The new `IpNet`, `Ipv4Net`, and `Ipv6Net` types build on the existing `IpAddr`, `Ipv4Addr`, and `Ipv6Addr` types already provided in Rust's standard library and align to their design to stay consistent. The module also provides useful traits that extend `Ipv4Addr` and `Ipv6Addr` with methods for `Add`, `Sub`, `BitAnd`, and `BitOr` operations. The module only uses stable feature so it is guaranteed to compile using the stable toolchain.",
            url: URL(string: "https://github.com/krisprice/ipnet")!
        ),
        OpenSourceAcknowledgement(
            name: "iri-string",
            version: "0.7.8",
            author: "YOSHIOKA Takuma <nop_thread@nops.red>",
            license: "MIT OR Apache-2.0",
            description: "IRI as string types",
            url: URL(string: "https://github.com/lo48576/iri-string")!
        ),
        OpenSourceAcknowledgement(
            name: "itoa",
            version: "1.0.15",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Fast integer primitive to string conversion",
            url: URL(string: "https://github.com/dtolnay/itoa")!
        ),
        OpenSourceAcknowledgement(
            name: "lazy_static",
            version: "1.5.0",
            author: "Marvin Löbel <loebel.marvin@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "A macro for declaring lazily evaluated statics in Rust.",
            url: URL(string: "https://github.com/rust-lang-nursery/lazy-static.rs")!
        ),
        OpenSourceAcknowledgement(
            name: "libc",
            version: "0.2.174",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Raw FFI bindings to platform libraries like libc.",
            url: URL(string: "https://github.com/rust-lang/libc")!
        ),
        OpenSourceAcknowledgement(
            name: "libm",
            version: "0.2.15",
            author: "Jorge Aparicio <jorge@japaric.io>",
            license: "MIT",
            description: "libm in pure Rust",
            url: URL(string: "https://github.com/rust-lang/compiler-builtins")!
        ),
        OpenSourceAcknowledgement(
            name: "litemap",
            version: "0.8.0",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "A key-value Map implementation based on a flat, sorted Vec.",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "lock_api",
            version: "0.4.13",
            author: "Amanieu d'Antras <amanieu@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Wrappers to create fully-featured Mutex and RwLock types. Compatible with no_std.",
            url: URL(string: "https://github.com/Amanieu/parking_lot")!
        ),
        OpenSourceAcknowledgement(
            name: "log",
            version: "0.4.27",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "A lightweight logging facade for Rust ",
            url: URL(string: "https://github.com/rust-lang/log")!
        ),
        OpenSourceAcknowledgement(
            name: "lru",
            version: "0.16.1",
            author: "Jerome Froelich <jeromefroelic@hotmail.com>",
            license: "MIT",
            description: "A LRU cache implementation",
            url: URL(string: "https://github.com/jeromefroe/lru-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "memchr",
            version: "2.7.5",
            author: "Andrew Gallant <jamslam@gmail.com>, bluss",
            license: "Unlicense OR MIT",
            description: "Provides extremely fast (uses SIMD on x86_64, aarch64 and wasm32) routines for 1, 2 or 3 byte search and single substring search. ",
            url: URL(string: "https://github.com/BurntSushi/memchr")!
        ),
        OpenSourceAcknowledgement(
            name: "mime",
            version: "0.3.17",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT OR Apache-2.0",
            description: "Strongly Typed Mimes",
            url: URL(string: "https://github.com/hyperium/mime")!
        ),
        OpenSourceAcknowledgement(
            name: "minimal-lexical",
            version: "0.2.1",
            author: "Alex Huszagh <ahuszagh@gmail.com>",
            license: "MIT/Apache-2.0",
            description: "Fast float parsing conversion routines.",
            url: URL(string: "https://github.com/Alexhuszagh/minimal-lexical")!
        ),
        OpenSourceAcknowledgement(
            name: "mio",
            version: "1.0.4",
            author: "Carl Lerche <me@carllerche.com>, Thomas de Zeeuw <thomasdezeeuw@gmail.com>, Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Lightweight non-blocking I/O.",
            url: URL(string: "https://github.com/tokio-rs/mio")!
        ),
        OpenSourceAcknowledgement(
            name: "nom",
            version: "7.1.3",
            author: "contact@geoffroycouprie.com",
            license: "MIT",
            description: "A byte-oriented, zero-copy, parser combinators library",
            url: URL(string: "https://github.com/Geal/nom")!
        ),
        OpenSourceAcknowledgement(
            name: "nu-ansi-term",
            version: "0.50.3",
            author: "ogham@bsago.me, Ryan Scheel (Havvy) <ryan.havvy@gmail.com>, Josh Triplett <josh@joshtriplett.org>, The Nushell Project Developers",
            license: "MIT",
            description: "Library for ANSI terminal colors and styles (bold, underline)",
            url: URL(string: "https://github.com/nushell/nu-ansi-term")!
        ),
        OpenSourceAcknowledgement(
            name: "num-bigint",
            version: "0.4.6",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Big integer implementation for Rust",
            url: URL(string: "https://github.com/rust-num/num-bigint")!
        ),
        OpenSourceAcknowledgement(
            name: "num-bigint-dig",
            version: "0.8.4",
            author: "dignifiedquire <dignifiedquire@gmail.com>, The Rust Project Developers",
            license: "MIT/Apache-2.0",
            description: "Big integer implementation for Rust",
            url: URL(string: "https://github.com/dignifiedquire/num-bigint")!
        ),
        OpenSourceAcknowledgement(
            name: "num-conv",
            version: "0.1.0",
            author: "Jacob Pratt <jacob@jhpratt.dev>",
            license: "MIT OR Apache-2.0",
            description: "`num_conv` is a crate to convert between integer types without using `as` casts. This provides better certainty when refactoring, makes the exact behavior of code more explicit, and allows using turbofish syntax. ",
            url: URL(string: "https://github.com/jhpratt/num-conv")!
        ),
        OpenSourceAcknowledgement(
            name: "num-integer",
            version: "0.1.46",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Integer traits and functions",
            url: URL(string: "https://github.com/rust-num/num-integer")!
        ),
        OpenSourceAcknowledgement(
            name: "num-iter",
            version: "0.1.45",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "External iterators for generic mathematics",
            url: URL(string: "https://github.com/rust-num/num-iter")!
        ),
        OpenSourceAcknowledgement(
            name: "num-traits",
            version: "0.2.19",
            author: "The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Numeric traits for generic mathematics",
            url: URL(string: "https://github.com/rust-num/num-traits")!
        ),
        OpenSourceAcknowledgement(
            name: "oid-registry",
            version: "0.8.1",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT OR Apache-2.0",
            description: "Object Identifier (OID) database",
            url: URL(string: "https://github.com/rusticata/oid-registry.git")!
        ),
        OpenSourceAcknowledgement(
            name: "once_cell",
            version: "1.21.3",
            author: "Aleksey Kladov <aleksey.kladov@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Single assignment cells and lazy values.",
            url: URL(string: "https://github.com/matklad/once_cell")!
        ),
        OpenSourceAcknowledgement(
            name: "parking_lot",
            version: "0.12.4",
            author: "Amanieu d'Antras <amanieu@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "More compact and efficient implementations of the standard synchronization primitives.",
            url: URL(string: "https://github.com/Amanieu/parking_lot")!
        ),
        OpenSourceAcknowledgement(
            name: "parking_lot_core",
            version: "0.9.11",
            author: "Amanieu d'Antras <amanieu@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "An advanced API for creating custom synchronization primitives.",
            url: URL(string: "https://github.com/Amanieu/parking_lot")!
        ),
        OpenSourceAcknowledgement(
            name: "pem",
            version: "3.0.6",
            author: "Jonathan Creekmore <jonathan@thecreekmores.org>",
            license: "MIT",
            description: "Parse and encode PEM-encoded data.",
            url: URL(string: "https://github.com/jcreekmore/pem-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "pem-rfc7468",
            version: "0.7.0",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "PEM Encoding (RFC 7468) for PKIX, PKCS, and CMS Structures, implementing a strict subset of the original Privacy-Enhanced Mail encoding intended specifically for use with cryptographic keys, certificates, and other messages. Provides a no_std-friendly, constant-time implementation suitable for use with cryptographic private keys. ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/pem-rfc7468")!
        ),
        OpenSourceAcknowledgement(
            name: "percent-encoding",
            version: "2.3.1",
            author: "The rust-url developers",
            license: "MIT OR Apache-2.0",
            description: "Percent encoding and decoding",
            url: URL(string: "https://github.com/servo/rust-url/")!
        ),
        OpenSourceAcknowledgement(
            name: "pin-project-lite",
            version: "0.2.16",
            author: "See project metadata",
            license: "Apache-2.0 OR MIT",
            description: "A lightweight version of pin-project written with declarative macros. ",
            url: URL(string: "https://github.com/taiki-e/pin-project-lite")!
        ),
        OpenSourceAcknowledgement(
            name: "pin-utils",
            version: "0.1.0",
            author: "Josef Brandl <mail@josefbrandl.de>",
            license: "MIT OR Apache-2.0",
            description: "Utilities for pinning ",
            url: URL(string: "https://github.com/rust-lang-nursery/pin-utils")!
        ),
        OpenSourceAcknowledgement(
            name: "pkcs1",
            version: "0.7.5",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Pure Rust implementation of Public-Key Cryptography Standards (PKCS) #1: RSA Cryptography Specifications Version 2.2 (RFC 8017) ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/pkcs1")!
        ),
        OpenSourceAcknowledgement(
            name: "pkcs8",
            version: "0.10.2",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Pure Rust implementation of Public-Key Cryptography Standards (PKCS) #8: Private-Key Information Syntax Specification (RFC 5208), with additional support for PKCS#8v2 asymmetric key packages (RFC 5958) ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/pkcs8")!
        ),
        OpenSourceAcknowledgement(
            name: "potential_utf",
            version: "0.1.2",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Unvalidated string and character types",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "powerfmt",
            version: "0.2.0",
            author: "Jacob Pratt <jacob@jhpratt.dev>",
            license: "MIT OR Apache-2.0",
            description: "    `powerfmt` is a library that provides utilities for formatting values. This crate makes it     significantly easier to support filling to a minimum width with alignment, avoid heap     allocation, and avoid repetitive calculations. ",
            url: URL(string: "https://github.com/jhpratt/powerfmt")!
        ),
        OpenSourceAcknowledgement(
            name: "ppv-lite86",
            version: "0.2.21",
            author: "The CryptoCorrosion Contributors",
            license: "MIT OR Apache-2.0",
            description: "Cross-platform cryptography-oriented low-level SIMD library.",
            url: URL(string: "https://github.com/cryptocorrosion/cryptocorrosion")!
        ),
        OpenSourceAcknowledgement(
            name: "proc-macro2",
            version: "1.0.95",
            author: "David Tolnay <dtolnay@gmail.com>, Alex Crichton <alex@alexcrichton.com>",
            license: "MIT OR Apache-2.0",
            description: "A substitute implementation of the compiler's `proc_macro` API to decouple token-based libraries from the procedural macro use case.",
            url: URL(string: "https://github.com/dtolnay/proc-macro2")!
        ),
        OpenSourceAcknowledgement(
            name: "quote",
            version: "1.0.40",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Quasi-quoting macro quote!(...)",
            url: URL(string: "https://github.com/dtolnay/quote")!
        ),
        OpenSourceAcknowledgement(
            name: "rand",
            version: "0.8.5",
            author: "The Rand Project Developers, The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Random number generators and other randomness functionality. ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rand",
            version: "0.9.1",
            author: "The Rand Project Developers, The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Random number generators and other randomness functionality. ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rand_chacha",
            version: "0.3.1",
            author: "The Rand Project Developers, The Rust Project Developers, The CryptoCorrosion Contributors",
            license: "MIT OR Apache-2.0",
            description: "ChaCha random number generator ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rand_chacha",
            version: "0.9.0",
            author: "The Rand Project Developers, The Rust Project Developers, The CryptoCorrosion Contributors",
            license: "MIT OR Apache-2.0",
            description: "ChaCha random number generator ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rand_core",
            version: "0.6.4",
            author: "The Rand Project Developers, The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Core random number generator traits and tools for implementation. ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rand_core",
            version: "0.9.3",
            author: "The Rand Project Developers, The Rust Project Developers",
            license: "MIT OR Apache-2.0",
            description: "Core random number generator traits and tools for implementation. ",
            url: URL(string: "https://github.com/rust-random/rand")!
        ),
        OpenSourceAcknowledgement(
            name: "rcgen",
            version: "0.13.2",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Rust X.509 certificate generator",
            url: URL(string: "https://github.com/rustls/rcgen")!
        ),
        OpenSourceAcknowledgement(
            name: "reqwest",
            version: "0.12.23",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT OR Apache-2.0",
            description: "higher level HTTP client library",
            url: URL(string: "https://github.com/seanmonstar/reqwest")!
        ),
        OpenSourceAcknowledgement(
            name: "ring",
            version: "0.17.14",
            author: "See project metadata",
            license: "Apache-2.0 AND ISC",
            description: "An experiment.",
            url: URL(string: "https://github.com/briansmith/ring")!
        ),
        OpenSourceAcknowledgement(
            name: "rsa",
            version: "0.9.8",
            author: "RustCrypto Developers, dignifiedquire <dignifiedquire@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Pure Rust RSA implementation",
            url: URL(string: "https://github.com/RustCrypto/RSA")!
        ),
        OpenSourceAcknowledgement(
            name: "rusticata-macros",
            version: "4.1.0",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT/Apache-2.0",
            description: "Helper macros for Rusticata",
            url: URL(string: "https://github.com/rusticata/rusticata-macros.git")!
        ),
        OpenSourceAcknowledgement(
            name: "rustls",
            version: "0.23.32",
            author: "See project metadata",
            license: "Apache-2.0 OR ISC OR MIT",
            description: "Rustls is a modern TLS library written in Rust.",
            url: URL(string: "https://github.com/rustls/rustls")!
        ),
        OpenSourceAcknowledgement(
            name: "rustls-pki-types",
            version: "1.12.0",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Shared types for the rustls PKI ecosystem",
            url: URL(string: "https://github.com/rustls/pki-types")!
        ),
        OpenSourceAcknowledgement(
            name: "rustls-webpki",
            version: "0.103.7",
            author: "See project metadata",
            license: "ISC",
            description: "Web PKI X.509 Certificate Verification.",
            url: URL(string: "https://github.com/rustls/webpki")!
        ),
        OpenSourceAcknowledgement(
            name: "ryu",
            version: "1.0.20",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "Apache-2.0 OR BSL-1.0",
            description: "Fast floating point to string conversion",
            url: URL(string: "https://github.com/dtolnay/ryu")!
        ),
        OpenSourceAcknowledgement(
            name: "scopeguard",
            version: "1.2.0",
            author: "bluss",
            license: "MIT OR Apache-2.0",
            description: "A RAII scope guard that will run a given closure when it goes out of scope, even if the code between panics (assuming unwinding panic).  Defines the macros `defer!`, `defer_on_unwind!`, `defer_on_success!` as shorthands for guards with one of the implemented strategies. ",
            url: URL(string: "https://github.com/bluss/scopeguard")!
        ),
        OpenSourceAcknowledgement(
            name: "serde",
            version: "1.0.228",
            author: "Erick Tryzelaar <erick.tryzelaar@gmail.com>, David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "A generic serialization/deserialization framework",
            url: URL(string: "https://github.com/serde-rs/serde")!
        ),
        OpenSourceAcknowledgement(
            name: "serde_core",
            version: "1.0.228",
            author: "Erick Tryzelaar <erick.tryzelaar@gmail.com>, David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Serde traits only, with no support for derive -- use the `serde` crate instead",
            url: URL(string: "https://github.com/serde-rs/serde")!
        ),
        OpenSourceAcknowledgement(
            name: "serde_derive",
            version: "1.0.228",
            author: "Erick Tryzelaar <erick.tryzelaar@gmail.com>, David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Macros 1.1 implementation of #[derive(Serialize, Deserialize)]",
            url: URL(string: "https://github.com/serde-rs/serde")!
        ),
        OpenSourceAcknowledgement(
            name: "serde_json",
            version: "1.0.145",
            author: "Erick Tryzelaar <erick.tryzelaar@gmail.com>, David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "A JSON serialization file format",
            url: URL(string: "https://github.com/serde-rs/json")!
        ),
        OpenSourceAcknowledgement(
            name: "serde_urlencoded",
            version: "0.7.1",
            author: "Anthony Ramine <n.oxyde@gmail.com>",
            license: "MIT/Apache-2.0",
            description: "`x-www-form-urlencoded` meets Serde",
            url: URL(string: "https://github.com/nox/serde_urlencoded")!
        ),
        OpenSourceAcknowledgement(
            name: "sha1",
            version: "0.10.6",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "SHA-1 hash function",
            url: URL(string: "https://github.com/RustCrypto/hashes")!
        ),
        OpenSourceAcknowledgement(
            name: "sha2",
            version: "0.10.9",
            author: "RustCrypto Developers",
            license: "MIT OR Apache-2.0",
            description: "Pure Rust implementation of the SHA-2 hash function family including SHA-224, SHA-256, SHA-384, and SHA-512. ",
            url: URL(string: "https://github.com/RustCrypto/hashes")!
        ),
        OpenSourceAcknowledgement(
            name: "sharded-slab",
            version: "0.1.7",
            author: "Eliza Weisman <eliza@buoyant.io>",
            license: "MIT",
            description: "A lock-free concurrent slab. ",
            url: URL(string: "https://github.com/hawkw/sharded-slab")!
        ),
        OpenSourceAcknowledgement(
            name: "signal-hook-registry",
            version: "1.4.5",
            author: "Michal 'vorner' Vaner <vorner@vorner.cz>, Masaki Hara <ackie.h.gmai@gmail.com>",
            license: "Apache-2.0/MIT",
            description: "Backend crate for signal-hook",
            url: URL(string: "https://github.com/vorner/signal-hook")!
        ),
        OpenSourceAcknowledgement(
            name: "signature",
            version: "2.2.0",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "Traits for cryptographic signature algorithms (e.g. ECDSA, Ed25519)",
            url: URL(string: "https://github.com/RustCrypto/traits/tree/master/signature")!
        ),
        OpenSourceAcknowledgement(
            name: "slab",
            version: "0.4.10",
            author: "Carl Lerche <me@carllerche.com>",
            license: "MIT",
            description: "Pre-allocated storage for a uniform data type",
            url: URL(string: "https://github.com/tokio-rs/slab")!
        ),
        OpenSourceAcknowledgement(
            name: "smallvec",
            version: "1.15.1",
            author: "The Servo Project Developers",
            license: "MIT OR Apache-2.0",
            description: "'Small vector' optimization: store up to a small number of items on the stack",
            url: URL(string: "https://github.com/servo/rust-smallvec")!
        ),
        OpenSourceAcknowledgement(
            name: "socket2",
            version: "0.5.10",
            author: "Alex Crichton <alex@alexcrichton.com>, Thomas de Zeeuw <thomasdezeeuw@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Utilities for handling networking sockets with a maximal amount of configuration possible intended. ",
            url: URL(string: "https://github.com/rust-lang/socket2")!
        ),
        OpenSourceAcknowledgement(
            name: "spin",
            version: "0.9.8",
            author: "Mathijs van de Nes <git@mathijs.vd-nes.nl>, John Ericson <git@JohnEricson.me>, Joshua Barretto <joshua.s.barretto@gmail.com>",
            license: "MIT",
            description: "Spin-based synchronization primitives",
            url: URL(string: "https://github.com/mvdnes/spin-rs.git")!
        ),
        OpenSourceAcknowledgement(
            name: "spki",
            version: "0.7.3",
            author: "RustCrypto Developers",
            license: "Apache-2.0 OR MIT",
            description: "X.509 Subject Public Key Info (RFC5280) describing public keys as well as their associated AlgorithmIdentifiers (i.e. OIDs) ",
            url: URL(string: "https://github.com/RustCrypto/formats/tree/master/spki")!
        ),
        OpenSourceAcknowledgement(
            name: "stable_deref_trait",
            version: "1.2.0",
            author: "Robert Grosse <n210241048576@gmail.com>",
            license: "MIT/Apache-2.0",
            description: "An unsafe marker trait for types like Box and Rc that dereference to a stable address even when moved, and hence can be used with libraries such as owning_ref and rental. ",
            url: URL(string: "https://github.com/storyyeller/stable_deref_trait")!
        ),
        OpenSourceAcknowledgement(
            name: "subtle",
            version: "2.6.1",
            author: "Isis Lovecruft <isis@patternsinthevoid.net>, Henry de Valence <hdevalence@hdevalence.ca>",
            license: "BSD-3-Clause",
            description: "Pure-Rust traits and utilities for constant-time cryptographic implementations.",
            url: URL(string: "https://github.com/dalek-cryptography/subtle")!
        ),
        OpenSourceAcknowledgement(
            name: "syn",
            version: "2.0.104",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Parser for Rust source code",
            url: URL(string: "https://github.com/dtolnay/syn")!
        ),
        OpenSourceAcknowledgement(
            name: "sync_wrapper",
            version: "1.0.2",
            author: "Actyx AG <developer@actyx.io>",
            license: "Apache-2.0",
            description: "A tool for enlisting the compiler's help in proving the absence of concurrency",
            url: URL(string: "https://github.com/Actyx/sync_wrapper")!
        ),
        OpenSourceAcknowledgement(
            name: "synstructure",
            version: "0.13.2",
            author: "Nika Layzell <nika@thelayzells.com>",
            license: "MIT",
            description: "Helper methods and macros for custom derives",
            url: URL(string: "https://github.com/mystor/synstructure")!
        ),
        OpenSourceAcknowledgement(
            name: "thiserror",
            version: "2.0.17",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "derive(Error)",
            url: URL(string: "https://github.com/dtolnay/thiserror")!
        ),
        OpenSourceAcknowledgement(
            name: "thiserror-impl",
            version: "2.0.17",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Implementation detail of the `thiserror` crate",
            url: URL(string: "https://github.com/dtolnay/thiserror")!
        ),
        OpenSourceAcknowledgement(
            name: "thread_local",
            version: "1.1.9",
            author: "Amanieu d'Antras <amanieu@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Per-object thread-local storage",
            url: URL(string: "https://github.com/Amanieu/thread_local-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "time",
            version: "0.3.41",
            author: "Jacob Pratt <open-source@jhpratt.dev>, Time contributors",
            license: "MIT OR Apache-2.0",
            description: "Date and time library. Fully interoperable with the standard library. Mostly compatible with #![no_std].",
            url: URL(string: "https://github.com/time-rs/time")!
        ),
        OpenSourceAcknowledgement(
            name: "time-core",
            version: "0.1.4",
            author: "Jacob Pratt <open-source@jhpratt.dev>, Time contributors",
            license: "MIT OR Apache-2.0",
            description: "This crate is an implementation detail and should not be relied upon directly.",
            url: URL(string: "https://github.com/time-rs/time")!
        ),
        OpenSourceAcknowledgement(
            name: "time-macros",
            version: "0.2.22",
            author: "Jacob Pratt <open-source@jhpratt.dev>, Time contributors",
            license: "MIT OR Apache-2.0",
            description: "    Procedural macros for the time crate.     This crate is an implementation detail and should not be relied upon directly. ",
            url: URL(string: "https://github.com/time-rs/time")!
        ),
        OpenSourceAcknowledgement(
            name: "tinystr",
            version: "0.8.1",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "A small ASCII-only bounded length string representation.",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "tokio",
            version: "1.46.1",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "An event-driven, non-blocking I/O platform for writing asynchronous I/O backed applications. ",
            url: URL(string: "https://github.com/tokio-rs/tokio")!
        ),
        OpenSourceAcknowledgement(
            name: "tokio-macros",
            version: "2.5.0",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Tokio's proc macros. ",
            url: URL(string: "https://github.com/tokio-rs/tokio")!
        ),
        OpenSourceAcknowledgement(
            name: "tokio-rustls",
            version: "0.26.4",
            author: "See project metadata",
            license: "MIT OR Apache-2.0",
            description: "Asynchronous TLS/SSL streams for Tokio using Rustls.",
            url: URL(string: "https://github.com/rustls/tokio-rustls")!
        ),
        OpenSourceAcknowledgement(
            name: "tokio-stream",
            version: "0.1.17",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Utilities to work with `Stream` and `tokio`. ",
            url: URL(string: "https://github.com/tokio-rs/tokio")!
        ),
        OpenSourceAcknowledgement(
            name: "tokio-util",
            version: "0.7.15",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Additional utilities for working with Tokio. ",
            url: URL(string: "https://github.com/tokio-rs/tokio")!
        ),
        OpenSourceAcknowledgement(
            name: "tower",
            version: "0.5.2",
            author: "Tower Maintainers <team@tower-rs.com>",
            license: "MIT",
            description: "Tower is a library of modular and reusable components for building robust clients and servers. ",
            url: URL(string: "https://github.com/tower-rs/tower")!
        ),
        OpenSourceAcknowledgement(
            name: "tower-http",
            version: "0.6.6",
            author: "Tower Maintainers <team@tower-rs.com>",
            license: "MIT",
            description: "Tower middleware and utilities for HTTP clients and servers",
            url: URL(string: "https://github.com/tower-rs/tower-http")!
        ),
        OpenSourceAcknowledgement(
            name: "tower-layer",
            version: "0.3.3",
            author: "Tower Maintainers <team@tower-rs.com>",
            license: "MIT",
            description: "Decorates a `Service` to allow easy composition between `Service`s. ",
            url: URL(string: "https://github.com/tower-rs/tower")!
        ),
        OpenSourceAcknowledgement(
            name: "tower-service",
            version: "0.3.3",
            author: "Tower Maintainers <team@tower-rs.com>",
            license: "MIT",
            description: "Trait representing an asynchronous, request / response based, client or server. ",
            url: URL(string: "https://github.com/tower-rs/tower")!
        ),
        OpenSourceAcknowledgement(
            name: "tracing",
            version: "0.1.41",
            author: "Eliza Weisman <eliza@buoyant.io>, Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Application-level tracing for Rust. ",
            url: URL(string: "https://github.com/tokio-rs/tracing")!
        ),
        OpenSourceAcknowledgement(
            name: "tracing-attributes",
            version: "0.1.30",
            author: "Tokio Contributors <team@tokio.rs>, Eliza Weisman <eliza@buoyant.io>, David Barsky <dbarsky@amazon.com>",
            license: "MIT",
            description: "Procedural macro attributes for automatically instrumenting functions. ",
            url: URL(string: "https://github.com/tokio-rs/tracing")!
        ),
        OpenSourceAcknowledgement(
            name: "tracing-core",
            version: "0.1.34",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Core primitives for application-level tracing. ",
            url: URL(string: "https://github.com/tokio-rs/tracing")!
        ),
        OpenSourceAcknowledgement(
            name: "tracing-log",
            version: "0.2.0",
            author: "Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Provides compatibility between `tracing` and the `log` crate. ",
            url: URL(string: "https://github.com/tokio-rs/tracing")!
        ),
        OpenSourceAcknowledgement(
            name: "tracing-subscriber",
            version: "0.3.20",
            author: "Eliza Weisman <eliza@buoyant.io>, David Barsky <me@davidbarsky.com>, Tokio Contributors <team@tokio.rs>",
            license: "MIT",
            description: "Utilities for implementing and composing `tracing` subscribers. ",
            url: URL(string: "https://github.com/tokio-rs/tracing")!
        ),
        OpenSourceAcknowledgement(
            name: "try-lock",
            version: "0.2.5",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "A lightweight atomic lock.",
            url: URL(string: "https://github.com/seanmonstar/try-lock")!
        ),
        OpenSourceAcknowledgement(
            name: "tungstenite",
            version: "0.28.0",
            author: "Alexey Galakhov, Daniel Abramov",
            license: "MIT OR Apache-2.0",
            description: "Lightweight stream-based WebSocket implementation",
            url: URL(string: "https://github.com/snapview/tungstenite-rs")!
        ),
        OpenSourceAcknowledgement(
            name: "typenum",
            version: "1.18.0",
            author: "Paho Lurie-Gregg <paho@paholg.com>, Andre Bogus <bogusandre@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "Typenum is a Rust library for type-level numbers evaluated at     compile time. It currently supports bits, unsigned integers, and signed     integers. It also provides a type-level array of type-level numbers, but its     implementation is incomplete.",
            url: URL(string: "https://github.com/paholg/typenum")!
        ),
        OpenSourceAcknowledgement(
            name: "unicode-ident",
            version: "1.0.18",
            author: "David Tolnay <dtolnay@gmail.com>",
            license: "(MIT OR Apache-2.0) AND Unicode-3.0",
            description: "Determine whether characters have the XID_Start or XID_Continue properties according to Unicode Standard Annex #31",
            url: URL(string: "https://github.com/dtolnay/unicode-ident")!
        ),
        OpenSourceAcknowledgement(
            name: "untrusted",
            version: "0.9.0",
            author: "Brian Smith <brian@briansmith.org>",
            license: "ISC",
            description: "Safe, fast, zero-panic, zero-crashing, zero-allocation parsing of untrusted inputs in Rust.",
            url: URL(string: "https://github.com/briansmith/untrusted")!
        ),
        OpenSourceAcknowledgement(
            name: "url",
            version: "2.5.4",
            author: "The rust-url developers",
            license: "MIT OR Apache-2.0",
            description: "URL library for Rust, based on the WHATWG URL Standard",
            url: URL(string: "https://github.com/servo/rust-url")!
        ),
        OpenSourceAcknowledgement(
            name: "utf-8",
            version: "0.7.6",
            author: "Simon Sapin <simon.sapin@exyr.org>",
            license: "MIT OR Apache-2.0",
            description: "Incremental, zero-copy UTF-8 decoding with error handling",
            url: URL(string: "https://github.com/SimonSapin/rust-utf8")!
        ),
        OpenSourceAcknowledgement(
            name: "utf8_iter",
            version: "1.0.4",
            author: "Henri Sivonen <hsivonen@hsivonen.fi>",
            license: "Apache-2.0 OR MIT",
            description: "Iterator by char over potentially-invalid UTF-8 in &[u8]",
            url: URL(string: "https://github.com/hsivonen/utf8_iter")!
        ),
        OpenSourceAcknowledgement(
            name: "uuid",
            version: "1.18.1",
            author: "Ashley Mannix<ashleymannix@live.com.au>, Dylan DPC<dylan.dpc@gmail.com>, Hunar Roop Kahlon<hunar.roop@gmail.com>",
            license: "Apache-2.0 OR MIT",
            description: "A library to generate and parse UUIDs.",
            url: URL(string: "https://github.com/uuid-rs/uuid")!
        ),
        OpenSourceAcknowledgement(
            name: "want",
            version: "0.3.1",
            author: "Sean McArthur <sean@seanmonstar.com>",
            license: "MIT",
            description: "Detect when another Future wants a result.",
            url: URL(string: "https://github.com/seanmonstar/want")!
        ),
        OpenSourceAcknowledgement(
            name: "webpki-roots",
            version: "1.0.1",
            author: "See project metadata",
            license: "CDLA-Permissive-2.0",
            description: "Mozilla's CA root certificates for use with webpki",
            url: URL(string: "https://github.com/rustls/webpki-roots")!
        ),
        OpenSourceAcknowledgement(
            name: "writeable",
            version: "0.6.1",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "A more efficient alternative to fmt::Display",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "x509-parser",
            version: "0.17.0",
            author: "Pierre Chifflier <chifflier@wzdftpd.net>",
            license: "MIT OR Apache-2.0",
            description: "Parser for the X.509 v3 format (RFC 5280 certificates)",
            url: URL(string: "https://github.com/rusticata/x509-parser.git")!
        ),
        OpenSourceAcknowledgement(
            name: "yasna",
            version: "0.5.2",
            author: "Masaki Hara <ackie.h.gmai@gmail.com>",
            license: "MIT OR Apache-2.0",
            description: "ASN.1 library for Rust",
            url: URL(string: "https://github.com/qnighy/yasna.rs")!
        ),
        OpenSourceAcknowledgement(
            name: "yoke",
            version: "0.8.0",
            author: "Manish Goregaokar <manishsmail@gmail.com>",
            license: "Unicode-3.0",
            description: "Abstraction allowing borrowed data to be carried along with the backing data it borrows from",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "yoke-derive",
            version: "0.8.0",
            author: "Manish Goregaokar <manishsmail@gmail.com>",
            license: "Unicode-3.0",
            description: "Custom derive for the yoke crate",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "zerocopy",
            version: "0.8.26",
            author: "Joshua Liebow-Feeser <joshlf@google.com>, Jack Wrenn <jswrenn@amazon.com>",
            license: "BSD-2-Clause OR Apache-2.0 OR MIT",
            description: "Zerocopy makes zero-cost memory manipulation effortless. We write \"unsafe\" so you don't have to.",
            url: URL(string: "https://github.com/google/zerocopy")!
        ),
        OpenSourceAcknowledgement(
            name: "zerofrom",
            version: "0.1.6",
            author: "Manish Goregaokar <manishsmail@gmail.com>",
            license: "Unicode-3.0",
            description: "ZeroFrom trait for constructing",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "zerofrom-derive",
            version: "0.1.6",
            author: "Manish Goregaokar <manishsmail@gmail.com>",
            license: "Unicode-3.0",
            description: "Custom derive for the zerofrom crate",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "zeroize",
            version: "1.8.1",
            author: "The RustCrypto Project Developers",
            license: "Apache-2.0 OR MIT",
            description: "Securely clear secrets from memory with a simple trait built on stable Rust primitives which guarantee memory is zeroed using an operation will not be 'optimized away' by the compiler. Uses a portable pure Rust implementation that works everywhere, even WASM! ",
            url: URL(string: "https://github.com/RustCrypto/utils/tree/master/zeroize")!
        ),
        OpenSourceAcknowledgement(
            name: "zerotrie",
            version: "0.2.2",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "A data structure that efficiently maps strings to integers",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "zerovec",
            version: "0.11.2",
            author: "The ICU4X Project Developers",
            license: "Unicode-3.0",
            description: "Zero-copy vector backed by a byte array",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        ),
        OpenSourceAcknowledgement(
            name: "zerovec-derive",
            version: "0.11.1",
            author: "Manish Goregaokar <manishsmail@gmail.com>",
            license: "Unicode-3.0",
            description: "Custom derive for the zerovec crate",
            url: URL(string: "https://github.com/unicode-org/icu4x")!
        )
    ]
}

#Preview {
    NavigationStack {
        OpenSourceAcknowledgementsView()
    }
}
