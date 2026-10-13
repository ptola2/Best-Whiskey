import SwiftUI
import WidgetKit

struct FastEntry: TimelineEntry {
    let date: Date
    let data: FastWidgetData?
}

struct FastProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastEntry {
        FastEntry(date: Date(), data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (FastEntry) -> Void) {
        let saved = FastWidgetData.load()
        // The widget gallery shows a running fast, so people see what they are adding.
        let showSample = context.isPreview && saved?.startedAt == nil
        completion(FastEntry(date: Date(), data: showSample ? .sample : saved))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastEntry>) -> Void) {
        let now = Date()
        guard let data = FastWidgetData.load(), data.startedAt != nil else {
            // The app reloads the widget as soon as a fast starts.
            completion(Timeline(entries: [FastEntry(date: now, data: FastWidgetData.load())], policy: .never))
            return
        }
        // An entry now, at each upcoming phase change and at the target, so the widget moves on by itself.
        var dates: [Date] = [now]
        var cursor = now
        while dates.count < 10, let next = data.nextPhase(after: cursor) {
            dates.append(next.at)
            cursor = next.at
        }
        if let target = data.targetDate, target > now {
            dates.append(target)
        }
        dates = Array(Set(dates)).sorted()
        let entries = dates.map { FastEntry(date: $0, data: data) }
        let refresh = dates.last.map { max($0, now.addingTimeInterval(3600)) } ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct FastTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FastTimer", provider: FastProvider()) { entry in
            FastWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "extension.widget.name"))
        .description(String(localized: "extension.widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct FastWidgetView: View {
    let entry: FastEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, entry.data?.rightToLeft == true ? .rightToLeft : .leftToRight)
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    LinearGradient(colors: [WidgetStyle.surface, WidgetStyle.paper], startPoint: .top, endPoint: .bottom)
                }
            }
    }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    @ViewBuilder
    private var content: some View {
        if let data = entry.data, let start = data.startedAt, let target = data.targetDate {
            let fast = RunningFast(data: data, start: start, target: target, date: entry.date)
            switch family {
            case .accessoryCircular: CircularView(fast: fast)
            case .accessoryRectangular: RectangularView(fast: fast)
            case .accessoryInline: InlineView(fast: fast)
            case .systemMedium: MediumView(fast: fast)
            default: SmallView(fast: fast)
            }
        } else {
            IdleView(data: entry.data, family: family)
        }
    }
}

/// What every layout needs about the running fast at the entry's moment.
private struct RunningFast {
    let data: FastWidgetData
    let start: Date
    let target: Date
    let date: Date

    var phase: String { data.phase(at: date)?.name ?? "" }
    var next: String? { data.nextLabel(after: date) }
    var targetLine: String { date >= target ? data.labels.reached : data.labels.target }
}

/// Counts up from the start by itself, every second.
private struct ElapsedText: View {
    let start: Date

    var body: some View {
        Text(start, style: .timer)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Fills toward the target by itself.
private struct TargetBar: View {
    let fast: RunningFast

    var body: some View {
        ProgressView(timerInterval: fast.start...fast.target, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(WidgetStyle.accent)
    }
}

private struct Eyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill").foregroundStyle(WidgetStyle.accent)
            Text(text.uppercased()).foregroundStyle(WidgetStyle.muted)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
    }
}

private struct SmallView: View {
    let fast: RunningFast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: fast.data.labels.fasting)
            ElapsedText(start: fast.start)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetStyle.ink)
            Text(fast.phase)
                .font(.caption)
                .foregroundStyle(WidgetStyle.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
            TargetBar(fast: fast)
            Text(fast.targetLine)
                .font(.caption2)
                .foregroundStyle(WidgetStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let fast: RunningFast

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: fast.data.labels.fasting)
                ElapsedText(start: fast.start)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetStyle.ink)
                Spacer(minLength: 0)
                TargetBar(fast: fast)
                Text(fast.targetLine)
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(fast.phase)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetStyle.ink)
                    .lineLimit(3)
                if let next = fast.next {
                    Text(next)
                        .font(.caption)
                        .foregroundStyle(WidgetStyle.muted)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CircularView: View {
    let fast: RunningFast

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ProgressView(timerInterval: fast.start...fast.target, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: "drop.fill")
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        }
    }
}

private struct RectangularView: View {
    let fast: RunningFast

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                Text(fast.data.labels.fasting)
            }
            .font(.caption.weight(.semibold))
            .widgetAccentable()
            ElapsedText(start: fast.start)
                .font(.headline)
            Text(fast.phase)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineView: View {
    let fast: RunningFast

    var body: some View {
        Label {
            Text(fast.start, style: .timer)
        } icon: {
            Image(systemName: "drop.fill")
        }
    }
}

private struct IdleView: View {
    let data: FastWidgetData?
    let family: WidgetFamily

    var body: some View {
        let title = data?.labels.idleTitle ?? String(localized: "extension.idle.title")
        let message = data?.labels.idleBody ?? String(localized: "extension.idle.body")
        switch family {
        case .accessoryInline:
            Label(title, systemImage: "drop")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "drop").font(.title3)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: "drop").font(.caption.weight(.semibold))
                Text(message).font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "drop").font(.title2).foregroundStyle(WidgetStyle.accent)
                Spacer(minLength: 0)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(WidgetStyle.ink)
                Text(message).font(.caption).foregroundStyle(WidgetStyle.muted).lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension FastWidgetData {
    /// A fast 30 hours into a 72-hour target, for the widget gallery and placeholders.
    static var sample: FastWidgetData {
        FastWidgetData(
            startedAt: Date().addingTimeInterval(-30 * 3600),
            targetHours: 72,
            phases: [
                Phase(startHours: 0, name: String(localized: "extension.sample.phase")),
            ],
            labels: Labels(
                fasting: String(localized: "extension.sample.fasting"),
                target: String(localized: "extension.sample.target"),
                reached: String(localized: "extension.sample.target"),
                nextFormat: "%@",
                idleTitle: String(localized: "extension.idle.title"),
                idleBody: String(localized: "extension.idle.body")),
            rightToLeft: false,
            localeIdentifier: Locale.current.identifier)
    }
}
