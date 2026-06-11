import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiquidSendTransferWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiquidSendTransferLiveActivity()
    }
}

struct LiquidSendTransferLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransferActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(context.attributes.direction, systemImage: directionIcon(context.attributes.direction))
                        .font(.headline)
                    Spacer()
                    Text(percent(context.state.fractionCompleted))
                        .monospacedDigit()
                }
                Text(context.attributes.peerName)
                    .font(.subheadline)
                ProgressView(value: context.state.fractionCompleted)
                    .tint(.cyan)
                Text(context.state.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.direction, systemImage: directionIcon(context.attributes.direction))
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percent(context.state.fractionCompleted))
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.peerName).font(.headline)
                        ProgressView(value: context.state.fractionCompleted).tint(.cyan)
                        Text(context.state.fileName).font(.caption).lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: directionIcon(context.attributes.direction))
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(percent(context.state.fractionCompleted))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                ProgressView(value: context.state.fractionCompleted)
                    .progressViewStyle(.circular)
                    .tint(.cyan)
            }
            .keylineTint(.cyan)
        }
    }

    private func directionIcon(_ direction: String) -> String {
        direction == "Receiving" ? "arrow.down" : "arrow.up"
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int(fraction * 100))%"
    }
}
