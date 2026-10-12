import SwiftUI

struct TodayView: View {
    var body: some View {
        let store = FastStore.shared
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let fast = store.data.active {
                        ActiveFastSection(fast: fast)
                    } else if let refeed = store.data.refeed {
                        RefeedTodaySection(refeed: refeed)
                    } else {
                        IdleSection()
                    }
                    DisclaimerFooter()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(tr("tab.today"))
            .languageToolbarButton()
            .keyboardDoneButton()
        }
    }
}

struct DisclaimerFooter: View {
    var body: some View {
        Para(text: tr("footer.disclaimer"), font: .caption, color: Theme.muted)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Active fast

struct ActiveFastSection: View {
    let fast: ActiveFast
    @State private var confirmEnd = false

    var body: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LiveFastPanels(fast: fast, now: context.date) { confirmEnd = true }
            }
            // Redrawn every minute so "today" rolls over at midnight.
            TimelineView(.everyMinute) { context in
                WaterCard(fast: fast, now: context.date)
            }
            LatestCheckInCard(fast: fast)
            StopCard()
            Button(role: .destructive) {
                confirmEnd = true
            } label: {
                Text(tr("fast.end")).frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .danger))
            .confirmationDialog(tr("fast.end_confirm.title"), isPresented: $confirmEnd, titleVisibility: .visible) {
                Button(tr("fast.end_confirm.target")) { FastStore.shared.endFast(.target) }
                Button(tr("fast.end_confirm.symptoms")) { FastStore.shared.endFast(.symptoms) }
                Button(tr("fast.end_confirm.other")) { FastStore.shared.endFast(.other) }
                Button(tr("fast.end_confirm.keep"), role: .cancel) {}
            } message: {
                Text(tr("fast.end_confirm.message"))
            }
        }
    }
}

struct LiveFastPanels: View {
    let fast: ActiveFast
    let now: Date
    var onEnd: () -> Void

    var body: some View {
        let elapsed = now.timeIntervalSince(fast.startedAt)
        let hours = elapsed / 3600
        let day = FastMath.dayNumber(hours: hours)
        let risks = Research.risks.filter { day >= $0.fromDay && day <= $0.toDay }
        VStack(spacing: 14) {
            if hours >= Double(fast.targetHours) {
                Notice(tone: .ok) {
                    Text(tr("fast.target_reached.title", Fmt.target(fast.targetHours))).bold()
                    Para(text: tr("fast.target_reached.body"), font: .subheadline)
                }
            }
            if !fast.supervised && hours >= 72 {
                Notice(tone: .stop) {
                    Text(tr("fast.unsupervised.title")).bold()
                    Para(text: tr("fast.unsupervised.body"), font: .subheadline)
                    VStack(alignment: .leading, spacing: 8) {
                        Button(tr("fast.end")) { onEnd() }
                            .buttonStyle(WLButtonStyle(kind: .danger))
                        Button(tr("fast.unsupervised.confirm")) { FastStore.shared.markSupervised() }
                            .buttonStyle(WLButtonStyle(kind: .secondary))
                    }
                }
            }
            TimerHero(fast: fast, elapsed: elapsed)
            Card {
                PhaseTimeline(targetHours: fast.targetHours, hours: hours)
            }
            PhaseCard(hours: hours)
            if !risks.isEmpty {
                WatchCard(day: day, risks: risks)
            }
        }
    }
}

struct TimerHero: View {
    let fast: ActiveFast
    let elapsed: TimeInterval

    var body: some View {
        let hours = elapsed / 3600
        let progress = min(max(hours / Double(fast.targetHours), 0), 1)
        let remaining = Double(fast.targetHours) * 3600 - elapsed
        let day = FastMath.dayNumber(hours: hours)
        let plan = tr("timer.day_of_plan", day, Fmt.target(fast.targetHours))
        let subtitle = fast.supervised ? plan + " \u{00B7} " + tr("timer.supervised") : plan
        let remainingLine = remaining > 0
            ? tr("timer.to_go", Fmt.span(remaining), Fmt.target(fast.targetHours))
            : tr("timer.reached_ago", Fmt.span(-remaining))
        Card {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: tr("timer.since", Fmt.when(fast.startedAt)))
                    Text(Fmt.clock(elapsed))
                        .font(.system(size: 48, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Theme.ink)
                        .environment(\.layoutDirection, .leftToRight)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
                ProgressRing(progress: progress)
                    .frame(width: 104, height: 104)
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            Text(remainingLine)
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surface2, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(Int(progress * 100).formatted(.percent.locale(AppLanguage.shared.locale)))
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(tr("timer.of_target"))
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(5)
    }
}

/// Horizontal timeline shaded by metabolic phase (sequential ramp, deeper over time),
/// with markers for now and for the target. Drawn left to right in every language so the
/// bands, markers and labels stay lined up.
struct PhaseTimeline: View {
    let targetHours: Int
    let hours: Double

    private enum TickAlign { case lead, mid, trail }

    private struct Tick: Identifiable {
        let id: Int
        let x: Double
        let text: String
        let align: TickAlign
    }

    private var end: Double {
        max(Double(targetHours), 72, ceil((hours + 0.01) / 24) * 24)
    }

    private func tickLabel(_ hours: Double) -> String {
        hours <= 72 ? tr("unit.hours_short", Int(hours)) : tr("unit.days_short", Fmt.trimmed(hours / 24))
    }

    private var ticks: [Tick] {
        var out = [Tick(id: -1, x: 0, text: "0", align: .lead)]
        var last = 0.0
        for phase in Research.phases where phase.from > 0 && phase.from < end {
            let position = phase.from / end
            if position - last >= 0.10 && position <= 0.88 {
                out.append(Tick(id: phase.id, x: position, text: tickLabel(phase.from), align: .mid))
                last = position
            }
        }
        out.append(Tick(id: 99, x: 1, text: tickLabel(end), align: .trail))
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("timeline.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(tr("timeline.subtitle"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Group {
                track
                    .frame(height: 18)
                    .padding(.top, 10)
                labels
                    .frame(height: 14)
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.ink).frame(width: 9, height: 9)
                    Text(tr("timeline.now"))
                }
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.ink2).frame(width: 2, height: 12)
                    Text(tr("timeline.target"))
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("timeline.accessibility", Int(hours), targetHours))
    }

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let targetX = width * min(Double(targetHours) / end, 1)
            let nowX = width * min(hours / end, 1)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Theme.surface2
                    ForEach(Research.phases.filter { $0.from < end }) { phase in
                        let x0 = width * phase.from / end
                        let x1 = width * min(phase.to, end) / end
                        Theme.bands[phase.id]
                            .frame(width: max(x1 - x0 - 2, 0), height: 18)
                            .offset(x: x0)
                    }
                }
                .frame(width: width, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Path { path in
                    path.move(to: CGPoint(x: targetX, y: -5))
                    path.addLine(to: CGPoint(x: targetX, y: 23))
                }
                .stroke(Theme.ink2, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))

                Path { path in
                    path.move(to: CGPoint(x: nowX, y: -7))
                    path.addLine(to: CGPoint(x: nowX, y: 25))
                }
                .stroke(Theme.ink, lineWidth: 2)

                Circle()
                    .fill(Theme.ink)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    .position(x: nowX, y: -7)
            }
        }
    }

    private var labels: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                ForEach(ticks) { tick in
                    Text(tick.text)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 48, alignment: frameAlignment(tick.align))
                        .offset(x: tickOffset(for: tick, width: width))
                }
            }
        }
    }

    private func frameAlignment(_ align: TickAlign) -> Alignment {
        switch align {
        case .lead: return .leading
        case .mid: return .center
        case .trail: return .trailing
        }
    }

    private func tickOffset(for tick: Tick, width: CGFloat) -> CGFloat {
        switch tick.align {
        case .lead: return 0
        case .mid: return width * tick.x - 24
        case .trail: return width - 48
        }
    }
}

struct PhaseCard: View {
    let hours: Double

    var body: some View {
        let phase = Research.phases[FastMath.phaseIndex(hours: hours)]
        let next = Research.phases.first { $0.from > hours }
        let nextLine = next.map { tr("phase_card.next", $0.name, Fmt.span(($0.from - hours) * 3600)) } ?? ""
        Card {
            Eyebrow(text: tr("phase_card.now", phase.range))
            CardTitle(text: phase.name)
            Para(text: phase.text)
            if !nextLine.isEmpty {
                Para(text: nextLine, font: .footnote, color: Theme.muted)
            }
        }
    }
}

struct WatchCard: View {
    let day: Int
    let risks: [RiskWindow]

    var body: some View {
        Card {
            CardTitle(text: tr("watch.title", day))
            Para(text: tr("watch.subtitle"), font: .footnote, color: Theme.muted)
            ForEach(risks) { risk in
                let window = risk.toDay > 100 ? tr("watch.days_from", risk.fromDay) : tr("watch.days_range", risk.fromDay, risk.toDay)
                VStack(alignment: .leading, spacing: 3) {
                    Text(window)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                    Text(risk.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: risk.signs + " " + risk.action, font: .footnote, color: Theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

struct WaterCard: View {
    let fast: ActiveFast
    var now = Date()

    var body: some View {
        let ml = fast.waterByDay[Fmt.dayKey(now)] ?? 0
        let message: String = {
            if ml == 0 { return tr("water.status.none") }
            if ml < Research.waterMin { return tr("water.status.below") }
            if ml <= Research.waterMax { return tr("water.status.inside") }
            return tr("water.status.above")
        }()
        Card {
            Text(tr("water.title")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.two(Double(ml) / 1000))
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text(tr("unit.litres")).font(.subheadline).foregroundStyle(Theme.muted)
            }
            WaterMeter(ml: ml)
            Para(text: message + " " + tr("water.kind"), font: .footnote, color: Theme.muted)
            HStack(spacing: 8) {
                Button(tr("water.remove", 250)) { FastStore.shared.addWater(-250) }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
                    .accessibilityLabel(tr("water.remove.accessibility", 250))
                Button(tr("water.add", 250)) { FastStore.shared.addWater(250) }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
                Button(tr("water.add", 500)) { FastStore.shared.addWater(500) }
                    .buttonStyle(WLButtonStyle(kind: .primary))
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .sensoryFeedback(.increase, trigger: ml)
        }
    }
}

struct WaterMeter: View {
    let ml: Int

    var body: some View {
        let scale = Double(Research.waterScale)
        let bandStart = Double(Research.waterMin) / scale
        let bandWidth = Double(Research.waterMax - Research.waterMin) / scale
        let fill = min(Double(ml) / scale, 1)
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Theme.surface2
                    Theme.accentSoft
                        .frame(width: width * bandWidth)
                        .offset(x: width * bandStart)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: width * fill, height: 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .frame(height: 14)
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    Text("0").frame(width: 48, alignment: .leading)
                    Text(Fmt.one(1.2)).frame(width: 48, alignment: .center).offset(x: width * bandStart - 24)
                    Text(Fmt.one(2.5)).frame(width: 48, alignment: .center).offset(x: width * (bandStart + bandWidth) - 24)
                    Text("3 " + tr("unit.litres")).frame(width: 48, alignment: .trailing).offset(x: width - 48)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.muted)
            }
            .frame(height: 14)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("water.meter.accessibility", ml))
    }
}

struct LatestCheckInCard: View {
    let fast: ActiveFast

    var body: some View {
        let last = fast.checkIns.last
        Card {
            Text(tr("latest.title")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            if let last {
                let day = FastMath.dayNumber(hours: last.at.timeIntervalSince(fast.startedAt) / 3600)
                StatusPill(level: last.level)
                Text(tr("latest.when", day, Fmt.when(last.at))).font(.footnote).foregroundStyle(Theme.muted)
                if let top = FastStore.shared.notes(for: last).first {
                    Para(text: top.text, font: .subheadline)
                }
                Button(tr("latest.again")) { FastStore.shared.tab = .log }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
            } else {
                Para(text: tr("latest.none"), font: .subheadline, color: Theme.ink2)
                Button(tr("latest.now")) { FastStore.shared.tab = .log }
                    .buttonStyle(WLButtonStyle(kind: .primary))
            }
        }
    }
}

struct StopCard: View {
    var body: some View {
        let clinician = FastStore.shared.data.clinician
        let digits = clinician.phone.filter { "0123456789+".contains($0) }
        Card {
            CardTitle(text: tr("stop.title"))
            Bullets(items: [
                tr("stop.faint"),
                tr("stop.chest"),
                tr("stop.confused"),
                tr("stop.vomit"),
                tr("stop.breathing"),
                tr("stop.joint"),
            ])
            Para(text: tr("stop.clinics"), font: .footnote, color: Theme.muted)
            if !clinician.name.isEmpty || !digits.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "stethoscope").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clinician.name.isEmpty ? tr("stop.your_clinician") : clinician.name).font(.subheadline.weight(.semibold))
                        if !clinician.phone.isEmpty {
                            Text(clinician.phone)
                                .font(.footnote.monospaced())
                                .foregroundStyle(Theme.ink2)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    Spacer()
                    if let url = URL(string: "tel:\(digits)"), !digits.isEmpty {
                        Link(destination: url) {
                            Label(tr("stop.call"), systemImage: "phone.fill")
                        }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                    }
                }
            } else {
                Para(text: tr("stop.add_clinician"), font: .footnote, color: Theme.muted)
            }
        }
    }
}

// MARK: - Refeeding summary

struct RefeedTodaySection: View {
    let refeed: RefeedState

    var body: some View {
        let plan = RefeedPlanner.build(fastHours: refeed.fastHours, data: FastStore.shared.data, weightKg: refeed.endWeightKg)
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let day = min(Int(floor(context.date.timeIntervalSince(refeed.startedAt) / 86_400)) + 1, plan.days)
            let stages = plan.schedule[max(0, min(day - 1, plan.schedule.count - 1))]
            VStack(spacing: 14) {
                Card {
                    Eyebrow(text: tr("refeed_today.eyebrow", day, plan.days))
                    CardTitle(text: stages.map(\.title).joined(separator: tr("refeed_today.then")))
                    ForEach(stages, id: \.self) { stage in
                        Para(text: stage.text)
                    }
                    StatusPill(level: plan.tier.level, text: plan.tier.label)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { refeedButtons }
                        VStack(alignment: .leading, spacing: 8) { refeedButtons }
                    }
                }
                Notice(tone: .caution) {
                    Text(tr("refeed_today.no_salt.title")).bold()
                    Para(text: tr("refeed_today.no_salt.body"), font: .subheadline)
                }
                RefeedWarningsCard()
            }
        }
    }

    @ViewBuilder private var refeedButtons: some View {
        Button(tr("refeed_today.full_plan")) { FastStore.shared.tab = .refeed }
            .buttonStyle(WLButtonStyle(kind: .primary))
        Button(tr("refeed_today.check_in")) { FastStore.shared.tab = .log }
            .buttonStyle(WLButtonStyle(kind: .secondary))
    }
}

struct RefeedWarningsCard: View {
    var body: some View {
        Card {
            CardTitle(text: tr("refeed_warnings.title"))
            Bullets(items: [
                tr("refeed_warnings.swelling"),
                tr("refeed_warnings.breath"),
                tr("refeed_warnings.heart"),
                tr("refeed_warnings.weakness"),
                tr("refeed_warnings.confusion"),
            ])
            Para(text: tr("refeed_warnings.note"), font: .footnote, color: Theme.muted)
        }
    }
}

// MARK: - Not fasting

struct IdleSection: View {
    var body: some View {
        let store = FastStore.shared
        let screening = store.screening
        VStack(spacing: 14) {
            if !screening.complete {
                SetupCard(screening: screening)
                LearnTeaserCard()
            } else if !screening.blockers.isEmpty {
                BlockedNotice(blockers: screening.blockers)
                LearnTeaserCard()
            } else {
                if let last = store.data.history.first {
                    LastFastCard(fast: last)
                }
                PlanCard(screening: screening)
                BeforeYouStartCard()
            }
        }
    }
}

struct SetupCard: View {
    let screening: ScreeningResult

    var body: some View {
        Card {
            Eyebrow(text: tr("setup.eyebrow"))
            CardTitle(text: tr("setup.title"))
            Para(text: tr("setup.body"))
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("setup.step1"))
                Text(tr("setup.step2"))
                Text(tr("setup.step3"))
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink2)
            Button(tr("setup.go")) { FastStore.shared.tab = .profile }
                .buttonStyle(WLButtonStyle(kind: .primary))
            if screening.profileComplete && screening.missing > 0 {
                Text(trCount("count.questions_left", screening.missing))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct BlockedNotice: View {
    let blockers: [Blocker]

    var body: some View {
        Notice(tone: .stop) {
            Text(tr("blocked.title")).bold()
            ForEach(blockers) { blocker in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: Theme.symbol(.stop)).foregroundStyle(Theme.stop)
                    Para(text: tr("common.title_and_reason", blocker.title, blocker.why), font: .subheadline)
                }
            }
            Para(text: tr("blocked.footer"), font: .footnote)
        }
    }
}

struct LastFastCard: View {
    let fast: PastFast

    private var line: String {
        var text = tr("last_fast.summary", Fmt.trimmed((fast.hours / 24 * 10).rounded() / 10), Int(fast.hours.rounded()), Fmt.day(fast.endedAt))
        if let start = fast.startWeightKg, let end = fast.endWeightKg {
            text += " " + tr("last_fast.weight_change", Fmt.one(end - start))
        }
        return text
    }

    var body: some View {
        Card {
            Eyebrow(text: tr("last_fast.eyebrow"))
            Para(text: line, font: .subheadline)
        }
    }
}

struct PlanCard: View {
    let screening: ScreeningResult

    @State private var target = 72
    @State private var customHours: Double?
    @State private var startedEarlier = false
    @State private var startDate = Date()
    @State private var supervised = false
    @State private var doctorReviewed = false
    @State private var error: String?

    private var needsSupervision: Bool { target > 72 || screening.superviseAlways }

    private var reasons: [String] {
        var out: [String] = []
        if screening.noLongFasts && target > 72 {
            out.append(tr("plan.reason.bone"))
        }
        if needsSupervision && !supervised {
            out.append(target > 72 ? tr("plan.reason.long_needs_supervision") : tr("plan.reason.answers_need_supervision"))
        }
        if !screening.cautions.isEmpty && !doctorReviewed {
            out.append(tr("plan.reason.doctor"))
        }
        return out
    }

    private var tone: NoticeTone {
        if target > 504 { return .stop }
        if target > 72 { return .caution }
        return .info
    }

    var body: some View {
        let durationClass = FastMath.durationClass(hours: target)
        Card {
            Eyebrow(text: tr("plan.eyebrow"))
            CardTitle(text: tr("plan.title"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(Research.targets, id: \.self) { hours in
                    Chip(title: Fmt.target(hours), selected: hours == target) {
                        target = hours
                        customHours = nil
                        error = nil
                    }
                    .disabled(screening.noLongFasts && hours > 72)
                }
            }
            NumberField(label: tr("plan.custom_hours"), unit: tr("plan.custom_hours.range"), value: $customHours, decimals: false)
                .onChange(of: customHours) { _, value in
                    if let value, value >= 12, value <= 960 { target = Int(value) }
                }
            Toggle(isOn: $startedEarlier) {
                Text(tr("plan.started_earlier")).font(.subheadline)
            }
            .tint(Theme.accent)
            if startedEarlier {
                DatePicker(tr("plan.started"), selection: $startDate,
                           in: Date().addingTimeInterval(-7 * 86_400)...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .font(.subheadline)
            }
            Notice(tone: tone) {
                Text(durationClass.name).bold()
                Para(text: durationClass.note, font: .subheadline)
            }
            if !screening.cautions.isEmpty {
                Notice(tone: .caution) {
                    Text(tr("plan.cautions.title")).bold()
                    ForEach(screening.cautions) { caution in
                        Para(text: tr("common.title_and_reason", caution.question, caution.action), font: .subheadline)
                    }
                }
                Toggle(isOn: $doctorReviewed) {
                    Text(tr("plan.doctor_reviewed")).font(.subheadline)
                }
                .tint(Theme.accent)
            }
            if needsSupervision {
                Toggle(isOn: $supervised) {
                    Text(tr("plan.supervised")).font(.subheadline)
                }
                .tint(Theme.accent)
            }
            Button {
                start()
            } label: {
                Text(tr("plan.start", Fmt.target(target))).frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .primary))
            .disabled(!reasons.isEmpty)
            if !reasons.isEmpty {
                Para(text: reasons.joined(separator: " "), font: .footnote, color: Theme.muted)
            }
            if let error {
                Para(text: error, font: .footnote.weight(.semibold), color: Theme.stop)
            }
        }
    }

    private func start() {
        var startAt = Date()
        if startedEarlier {
            if startDate > Date().addingTimeInterval(60) {
                error = tr("plan.error.future")
                return
            }
            if Date().timeIntervalSince(startDate) > 7 * 86_400 {
                error = tr("plan.error.too_old")
                return
            }
            startAt = startDate
        }
        error = nil
        FastStore.shared.startFast(targetHours: target, supervised: supervised, start: startAt)
    }
}

struct BeforeYouStartCard: View {
    private let items = ["doctor", "ease_in", "rest", "water", "refeed"]

    var body: some View {
        Card {
            CardTitle(text: tr("before.title"))
            Para(text: tr("before.subtitle"), font: .footnote, color: Theme.muted)
            ForEach(items, id: \.self) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("before.\(item).title")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: tr("before.\(item).body"), font: .footnote, color: Theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

struct LearnTeaserCard: View {
    var body: some View {
        Card {
            Eyebrow(text: tr("teaser.eyebrow"))
            CardTitle(text: tr("teaser.title"))
            Para(text: tr("teaser.body"))
            Button(tr("teaser.open")) { FastStore.shared.tab = .learn }
                .buttonStyle(WLButtonStyle(kind: .secondary))
        }
    }
}
