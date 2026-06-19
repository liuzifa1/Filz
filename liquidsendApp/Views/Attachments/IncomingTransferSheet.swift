import SwiftUI

struct IncomingTransferSheet: View {
    let request: IncomingLocalSendRequest
    let decision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            IncomingReceiveRequestDetailView(request: request, decision: decision)
        }
        .interactiveDismissDisabled()
    }
}
