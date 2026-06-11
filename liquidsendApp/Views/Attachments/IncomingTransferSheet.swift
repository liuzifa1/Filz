import SwiftUI

struct IncomingTransferSheet: View {
    let request: IncomingLocalSendRequest
    let decision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("From", value: request.senderAlias)
                    LabeledContent("Items", value: request.files.count.formatted())
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(request.totalBytes), countStyle: .file))
                }
                Section("Files") {
                    ForEach(request.files) { file in
                        HStack {
                            Text(file.fileName).lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Incoming Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Decline", role: .destructive) { decision(false) }.buttonStyle(.bordered)
                    Button("Accept", systemImage: "checkmark") { decision(true) }.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
                .background(.bar)
            }
        }
        .interactiveDismissDisabled()
    }
}
