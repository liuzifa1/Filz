# Filz!

Filz! is a swift app for sending files, media, and text to nearby LocalSend-compatible devices over the local network.

The app is built with SwiftUI and uses a Rust-based LocalSend core packaged as an XCFramework. It is designed to keep transfers local: Filz! does not use a Filz! cloud server, analytics SDK, advertising SDK, or third-party tracking.

## Features

- Discover nearby LocalSend-compatible devices on the local network.
- Send files, photos, videos, and text from the app.
- Receive transfers and save supported media to Photos.
- Share files into Filz! from other iOS apps with the share extension.
- Track active transfers with the transfer widget and Live Activity support.
- Configure favourites, receive PINs, transfer history, and advanced networking options.

## Project Structure

```text
Filz!.xcodeproj/                 Xcode project
liquidsendApp/                   Main SwiftUI iOS app
LiquidSendShareExtension/        iOS share extension
LiquidSendTransferWidget/        Transfer widget and Live Activity UI
LocalsendCore/                   Rust LocalSend-compatible core
Frameworks/                      Built XCFramework output used by Xcode
scripts/                         Build helper scripts
docs/                            Static privacy policy and support pages
```

## Building

1. Open `Filz!.xcodeproj` in Xcode.
2. Select the `liquidsend` app target.
3. Build and run on an iPhone, iPad, or iOS simulator.

The repository includes `Frameworks/LocalSendCore.xcframework`. If you change the Rust core, rebuild the framework with:

```sh
./scripts/build-localsendcore-xcframework.sh
```

You will need a working Rust toolchain and the iOS Rust targets required by the build script.

## Privacy And Support Pages

Static pages for App Store and GitHub Pages use are available in `docs/`:

- `docs/privacy-policy.html`
- `docs/support.html`

## Privacy

Filz! stores settings, favourite devices, transfer history, and draft shared files locally on the device. Files and text are transferred directly between devices on the local network and are not routed through a Filz! server.

See the full privacy policy in `docs/privacy-policy.html`.

## Relationship To LocalSend

Filz! is built on top of the LocalSend core. This app would not have been possible without the hard work of the LocalSend team and the many open source maintainers whose projects helped lay its foundation.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
