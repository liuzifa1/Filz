import SwiftData
import SwiftUI

struct AddClientOverIP: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CoreStatus.self) private var coreStatus
    @Query private var settingsList: [SettingsModel]

    @State private var alias = ""
    @State private var address = ""
    @State private var port = "53317"
    @State private var transferProtocol = "http"
    @State private var validationError: String?

    var body: some View {
        Form {
            Section("Device") {
                TextField("Name (optional)", text: $alias)
                TextField("IP address or hostname", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                Picker("Protocol", selection: $transferProtocol) {
                    Text("HTTP").tag("http")
                    Text("HTTPS").tag("https")
                }
                .pickerStyle(.segmented)
            }

            if let validationError {
                Section {
                    Label(validationError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Send Selected Items", systemImage: "paperplane.fill") {
                    send()
                }
                .disabled(coreStatus.selectedFileURLs.isEmpty || coreStatus.isSending)
            } footer: {
                if coreStatus.selectedFileURLs.isEmpty {
                    Text("Choose files before opening manual sending.")
                }
            }
        }
        .navigationTitle("Manual Sending")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            validationError = "Enter an IP address or hostname."
            return
        }
        guard let targetPort = UInt16(port), targetPort > 0 else {
            validationError = "Enter a valid port between 1 and 65535."
            return
        }
        guard let settings = settingsList.first else {
            validationError = "App settings are unavailable."
            return
        }

        validationError = nil
        let device = LocalSendDevice(
            alias: alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? trimmedAddress
                : alias.trimmingCharacters(in: .whitespacesAndNewlines),
            version: "2.1",
            deviceModel: nil,
            deviceType: "desktop",
            token: "manual:\(trimmedAddress):\(targetPort)",
            ip: trimmedAddress,
            port: targetPort,
            protocol: transferProtocol,
            download: false
        )
        Task {
            await coreStatus.sendSelectedFile(
                to: device,
                alias: settings.userName,
                portText: settings.port,
                deviceModel: settings.deviceModel,
                deviceIcon: settings.selectedDeviceIcon,
                saveToHistory: settings.saveToHistory
            )
            if coreStatus.transferError == nil {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddClientOverIP()
    }
    .modelContainer(for: SettingsModel.self, inMemory: true)
    .environment(CoreStatus())
}
