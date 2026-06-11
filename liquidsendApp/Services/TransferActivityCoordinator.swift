import ActivityKit
import Foundation

@MainActor
final class TransferActivityCoordinator {
    static let shared = TransferActivityCoordinator()

    private var activity: Activity<TransferActivityAttributes>?
    private var signature: String?

    private init() {}

    func update(send: LocalSendTransferProgress?, receive: LocalSendTransferProgress?) {
        let progress: LocalSendTransferProgress?
        let direction: String
        let peerName: String

        if let receive, ["waiting", "receiving"].contains(receive.status) {
            progress = receive
            direction = "Receiving"
            peerName = receive.senderAlias ?? "LocalSend device"
        } else if let send, ["waiting", "sending"].contains(send.status) {
            progress = send
            direction = "Sending"
            peerName = send.targetAlias ?? "LocalSend device"
        } else if activity?.attributes.direction == "Receiving", let receive {
            progress = receive
            direction = "Receiving"
            peerName = receive.senderAlias ?? "LocalSend device"
        } else if activity != nil, let send {
            progress = send
            direction = "Sending"
            peerName = send.targetAlias ?? "LocalSend device"
        } else {
            return
        }

        guard let progress else { return }
        let state = TransferActivityAttributes.ContentState(
            status: progress.status,
            fileName: progress.currentFile ?? (progress.status == "finished" ? "Transfer complete" : "Preparing transfer"),
            transferredBytes: progress.transferredBytes,
            totalBytes: progress.totalBytes,
            completedFiles: progress.completedFiles,
            totalFiles: progress.totalFiles
        )
        let newSignature = "\(direction)|\(peerName)|\(state.status)|\(state.transferredBytes)|\(state.totalBytes)|\(state.fileName)"
        guard newSignature != signature else { return }
        signature = newSignature

        Task {
            if ["waiting", "sending", "receiving"].contains(state.status) {
                await startOrUpdate(peerName: peerName, direction: direction, state: state)
            } else if ["finished", "failed", "declined", "canceled"].contains(state.status) {
                await finish(state: state)
            }
        }
    }

    private func startOrUpdate(
        peerName: String,
        direction: String,
        state: TransferActivityAttributes.ContentState
    ) async {
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            await activity.update(content)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(
                attributes: TransferActivityAttributes(peerName: peerName, direction: direction),
                content: content
            )
        } catch {
            activity = nil
        }
    }

    private func finish(state: TransferActivityAttributes.ContentState) async {
        guard let activity else { return }
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(12))
        )
        self.activity = nil
    }
}
