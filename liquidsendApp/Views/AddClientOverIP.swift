import SwiftUI

struct AddClientOverIP: View {
    @Environment(\.dismiss) private var dismiss

    var showsCancelButton = false
    let completion: (LocalSendDevice) -> Void

    @State private var alias = ""
    @State private var address = ""
    @State private var port = "53317"
    @State private var transferProtocol = "https"
    @State private var pin = ""
    @State private var validationError: String?

    var body: some View {
        Form {
            Section("Destination") {
                TextField("Name (optional)", text: $alias)
                TextField("IP address or hostname", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                Picker("Protocol", selection: $transferProtocol) {
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                .pickerStyle(.segmented)
                TextField("PIN, if required", text: $pin)
                    .textContentType(.oneTimeCode)
            }

            if let validationError {
                Section {
                    Label(validationError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add by IP Address")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { addDestination() }
            }
        }
    }

    private func addDestination() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            validationError = String(localized: "Enter an IP address or hostname.")
            return
        }
        guard let targetPort = UInt16(port), targetPort > 0 else {
            validationError = String(localized: "Enter a valid port between 1 and 65535.")
            return
        }

        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let device = LocalSendDevice(
            alias: trimmedAlias.isEmpty ? trimmedAddress : trimmedAlias,
            version: "2.1",
            deviceModel: nil,
            deviceType: "desktop",
            token: "manual:\(trimmedAddress):\(targetPort):\(transferProtocol)",
            ip: trimmedAddress,
            port: targetPort,
            protocol: transferProtocol,
            download: false,
            pin: normalizedPIN.isEmpty ? nil : normalizedPIN
        )
        completion(device)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddClientOverIP(showsCancelButton: true) { _ in }
    }
}
