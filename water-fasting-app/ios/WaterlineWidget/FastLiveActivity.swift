import ActivityKit
import SwiftUI
import WidgetKit

/// The running fast on the Lock Screen and in the Dynamic Island. The timer and the progress bar count by themselves;
/// the phase is shown until the next phase begins, then hidden until the app is opened and refreshes it.
struct FastLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastActivityAttributes.self) { context in
            LockScreenView(context: context)
                .environment(\.layoutDirection, context.state.rightToLeft ? .rightToLeft : .leftToRight)
                .activityBackgroundTint(WidgetStyle.surface)
                .activitySystemActionForegroundColor(WidgetStyle.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.fastingLabel).lineLimit(1)
                    } icon: {
                        Image(systemName: "drop.fill").foregroundStyle(WidgetStyle.accent)
                    }
                    .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !context.isStale, !context.state.phaseName.isEmpty {
                            Text(context.state.phaseName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        ProgressBar(attributes: context.attributes)
                        Text(targetLine(context))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .environment(\.layoutDirection, context.state.rightToLeft ? .rightToLeft : .leftToRight)
                }
            } compactLeading: {
                Image(systemName: "drop.fill").foregroundStyle(WidgetStyle.accent)
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "drop.fill").foregroundStyle(WidgetStyle.accent)
            }
            .keylineTint(WidgetStyle.accent)
        }
    }
}

private func targetLine(_ context: ActivityViewContext<FastActivityAttributes>) -> String {
    Date() >= context.attributes.targetAt ? context.state.reachedLabel : context.state.targetLabel
}

private struct ProgressBar: View {
    let attributes: FastActivityAttributes

    var body: some View {
        ProgressView(timerInterval: attributes.startedAt...attributes.targetAt, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(WidgetStyle.accent)
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<FastActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text(context.state.fastingLabel.uppercased())
                    } icon: {
                        Image(systemName: "drop.fill").foregroundStyle(WidgetStyle.accent)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetStyle.muted)
                    if !context.isStale, !context.state.phaseName.isEmpty {
                        Text(context.state.phaseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WidgetStyle.ink)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 170, alignment: .trailing)
            }
            ProgressBar(attributes: context.attributes)
            HStack {
                Text(targetLine(context))
                Spacer(minLength: 8)
                if !context.isStale, let next = context.state.nextLabel {
                    Text(next).lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(WidgetStyle.muted)
        }
        .padding(16)
    }
}
