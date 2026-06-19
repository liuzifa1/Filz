import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiquidSendTransferWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiquidSendTransferStatusWidget()
        LiquidSendTransferLiveActivity()
    }
}

private struct TransferStatusEntry: TimelineEntry {
    let date: Date
}

private struct TransferStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TransferStatusEntry {
        TransferStatusEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TransferStatusEntry) -> Void) {
        completion(TransferStatusEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TransferStatusEntry>) -> Void) {
        completion(Timeline(entries: [TransferStatusEntry(date: .now)], policy: .never))
    }
}

private struct LiquidSendTransferStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LiquidSendTransferStatusWidget", provider: TransferStatusProvider()) { _ in
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text("LiquidSend")
                    .font(.headline)
                Text("Transfer status appears in Live Activities.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LiquidSend")
        .description("Shows transfer status while sending or receiving.")
        .supportedFamilies([.systemSmall])
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
                if let actionHint = context.state.actionHint {
                    Text(actionHint)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(deepLink(context))
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
                        if let actionHint = context.state.actionHint {
                            Text(actionHint)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.cyan)
                        }
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
            .widgetURL(deepLink(context))
        }
    }

    private func deepLink(_ context: ActivityViewContext<TransferActivityAttributes>) -> URL? {
        URL(string: context.state.deepLink ?? "liquidsend://transfer")
    }

    private func directionIcon(_ direction: String) -> String {
        direction == "Receiving" ? "arrow.down" : "arrow.up"
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int(fraction * 100))%"
    }
}
