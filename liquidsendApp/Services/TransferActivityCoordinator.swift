@preconcurrency import ActivityKit
import Foundation

@MainActor
final class TransferActivityCoordinator {
    static let shared = TransferActivityCoordinator()

    private var activity: Activity<TransferActivityAttributes>?
    private var signature: String?

    private init() {}

    func cancelCurrent() {
        signature = nil
        Task {
            let state = TransferActivityAttributes.ContentState(
                status: "canceled",
                fileName: String(localized: "Transfer canceled"),
                transferredBytes: 0,
                totalBytes: 0,
                completedFiles: 0,
                totalFiles: 0,
                actionHint: nil,
                deepLink: nil
            )
            for activity in Activity<TransferActivityAttributes>.activities {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            self.activity = nil
        }
    }

    func update(
        send: LocalSendTransferProgress?,
        receive: LocalSendTransferProgress?,
        pendingReceive: IncomingLocalSendRequest?
    ) {
        let progress: LocalSendTransferProgress?
        let direction: String
        let peerName: String
        let pendingRequestID: String?

        if let pendingReceive {
            progress = LocalSendTransferProgress(
                requestID: pendingReceive.id,
                status: "waiting",
                startedAtMillis: nil,
                targetAlias: nil,
                targetIP: nil,
                targetPort: nil,
                targetProtocol: nil,
                senderAlias: pendingReceive.senderAlias,
                senderIP: pendingReceive.senderIP,
                senderPort: pendingReceive.senderPort,
                senderProtocol: pendingReceive.senderProtocol,
                senderFingerprint: pendingReceive.senderFingerprint,
                currentFile: String(localized: "Approval needed"),
                sentBytes: nil,
                receivedBytes: 0,
                totalBytes: pendingReceive.totalBytes,
                completedFiles: 0,
                totalFiles: pendingReceive.files.count,
                savedPaths: nil,
                textMessage: pendingReceive.textMessage,
                error: nil
            )
            direction = "receiving"
            peerName = pendingReceive.senderAlias
            pendingRequestID = pendingReceive.id
        } else if let receive, ["waiting", "approved", "receiving"].contains(receive.status) {
            progress = receive
            direction = "receiving"
            peerName = receive.senderAlias ?? String(localized: "LocalSend device")
            pendingRequestID = receive.status == "waiting" ? receive.requestID : nil
        } else if let send, ["waiting", "sending"].contains(send.status) {
            progress = send
            direction = "sending"
            peerName = send.targetAlias ?? String(localized: "LocalSend device")
            pendingRequestID = nil
        } else if activity?.attributes.direction == "receiving", let receive {
            progress = receive
            direction = "receiving"
            peerName = receive.senderAlias ?? String(localized: "LocalSend device")
            pendingRequestID = nil
        } else if activity != nil, let send {
            progress = send
            direction = "sending"
            peerName = send.targetAlias ?? String(localized: "LocalSend device")
            pendingRequestID = nil
        } else {
            if activity != nil || !Activity<TransferActivityAttributes>.activities.isEmpty {
                cancelCurrent()
            }
            return
        }

        guard let progress else { return }
        let state = TransferActivityAttributes.ContentState(
            status: progress.status,
            fileName: progress.currentFile ?? (progress.status == "finished"
                ? String(localized: "Transfer complete")
                : String(localized: "Preparing transfer")),
            transferredBytes: progress.transferredBytes,
            totalBytes: progress.totalBytes,
            completedFiles: progress.completedFiles,
            totalFiles: progress.totalFiles,
            actionHint: actionHint(for: progress.status, direction: direction),
            deepLink: pendingRequestID.map { "filz://receive/\($0)" } ?? "filz://transfer"
        )
        let newSignature = "\(direction)|\(peerName)|\(state.status)|\(state.transferredBytes)|\(state.totalBytes)|\(state.fileName)"
        guard newSignature != signature else { return }
        signature = newSignature

        Task {
            if ["waiting", "approved", "sending", "receiving"].contains(state.status) {
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
            dismissalPolicy: state.status == "canceled"
                ? .immediate
                : .after(.now.addingTimeInterval(12))
        )
        self.activity = nil
    }

    private func actionHint(for status: String, direction: String) -> String? {
        if direction == "receiving" && status == "waiting" {
            return String(localized: "Tap to review")
        }
        if direction == "receiving" && status == "approved" {
            return String(localized: "Waiting for upload")
        }
        return nil
    }
}
