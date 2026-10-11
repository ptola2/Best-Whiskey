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
            .navigationTitle("Today")
            .keyboardDoneButton()
        }
    }
}

struct DisclaimerFooter: View {
    var body: some View {
        Para(text: "Waterline is an educational tool built from published research on water-only fasting. It is not medical advice. In an emergency, call your local emergency number.",
             font: .caption, color: Theme.muted)
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
                Text("End fast").frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .danger))
            .confirmationDialog("End this fast?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("I reached my target") { FastStore.shared.endFast(.target) }
                Button("Stopping early: symptoms") { FastStore.shared.endFast(.symptoms) }
                Button("Stopping early: another reason") { FastStore.shared.endFast(.other) }
                Button("Keep fasting", role: .cancel) {}
            } message: {
                Text("Waterline will build your refeeding plan from how long you fasted.")
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
        let reachedLine = "You reached your \(Fmt.target(fast.targetHours)) target."
        VStack(spacing: 14) {
            if hours >= Double(fast.targetHours) {
                Notice(tone: .ok) {
                    Text(reachedLine).bold()
                    Para(text: "Supervised clinics end a fast once its goal is met. End the fast below to get your refeeding plan.", font: .subheadline)
                }
            }
            if !fast.supervised && hours >= 72 {
                Notice(tone: .stop) {
                    Text("This fast has passed 72 hours without supervision.").bold()
                    Para(text: "The research restricts fasts beyond 72 hours to medically supervised settings. End the fast now, or confirm that a clinician is supervising it.", font: .subheadline)
                    VStack(alignment: .leading, spacing: 8) {
                        Button("End fast") { onEnd() }
                            .buttonStyle(WLButtonStyle(kind: .danger))
                        Button("A clinician is supervising") { FastStore.shared.markSupervised() }
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
        let subtitle = "Day \(day) of a \(Fmt.target(fast.targetHours)) plan" + (fast.supervised ? " \u{00B7} supervised" : "")
        let remainingLine = remaining > 0
            ? "\(Fmt.span(remaining)) to go until your \(Fmt.target(fast.targetHours)) target."
            : "Target reached \(Fmt.span(-remaining)) ago."
        Card {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Fasting since \(Fmt.when(fast.startedAt))")
                    Text(Fmt.clock(elapsed))
                        .font(.system(size: 48, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Theme.ink)
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
                Text(verbatim: "\(Int(progress * 100))%")
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text("of target")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(5)
    }
}

/// Horizontal timeline shaded by metabolic phase (sequential ramp, deeper over time),
/// with markers for now and for the target.
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

    private var ticks: [Tick] {
        var out = [Tick(id: -1, x: 0, text: "0", align: .lead)]
        var last = 0.0
        for phase in Research.phases where phase.from > 0 && phase.from < end {
            let position = phase.from / end
            if position - last >= 0.10 && position <= 0.88 {
                let text = phase.from <= 72 ? "\(Int(phase.from)) h" : "\(Int(phase.from / 24)) d"
                out.append(Tick(id: phase.id, x: position, text: text, align: .mid))
                last = position
            }
        }
        let endText = end <= 72 ? "\(Int(end)) h" : "\(Fmt.trimmed(end / 24)) d"
        out.append(Tick(id: 99, x: 1, text: endText, align: .trail))
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where you are in the fast")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Shaded by metabolic phase, deeper over time")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            track
                .frame(height: 18)
                .padding(.top, 10)
            labels
                .frame(height: 14)
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.ink).frame(width: 9, height: 9)
                    Text("Now")
                }
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.ink2).frame(width: 2, height: 12)
                    Text("Your target")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timeline: \(Int(hours)) hours elapsed of a \(targetHours) hour target")
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
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.muted)
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
        let nextLine = next.map { "Next: \($0.name) in \(Fmt.span(($0.from - hours) * 3600))." } ?? ""
        Card {
            Eyebrow(text: "Now \u{00B7} \(phase.range)")
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
            CardTitle(text: "Watch for, on day \(day)")
            Para(text: "The windows when these problems usually start, from supervised fasting data.", font: .footnote, color: Theme.muted)
            ForEach(risks) { risk in
                let window: String = risk.toDay > 100 ? "Days \(risk.fromDay)+" : "Days \(risk.fromDay) to \(risk.toDay)"
                VStack(alignment: .leading, spacing: 3) {
                    Text(window)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                    Text(risk.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: "\(risk.signs) \(risk.action)", font: .footnote, color: Theme.ink2)
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
            if ml == 0 { return "Nothing logged yet today." }
            if ml < Research.waterMin { return "Below the 1.2 L daily minimum so far." }
            if ml <= Research.waterMax { return "Inside the 1.2 to 2.5 L range." }
            return "Above the usual range. More plain water is not better: it can dilute blood sodium."
        }()
        Card {
            Text("Water today").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", Double(ml) / 1000))
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text("L").font(.subheadline).foregroundStyle(Theme.muted)
            }
            WaterMeter(ml: ml)
            Para(text: "\(message) Plain distilled or low-mineral water.", font: .footnote, color: Theme.muted)
            HStack(spacing: 8) {
                Button("\u{2212} 250 mL") { FastStore.shared.addWater(-250) }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
                    .accessibilityLabel("Remove 250 millilitres")
                Button("+ 250 mL") { FastStore.shared.addWater(250) }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
                Button("+ 500 mL") { FastStore.shared.addWater(500) }
                    .buttonStyle(WLButtonStyle(kind: .primary))
            }
            .font(.subheadline)
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
                    Text("0").frame(width: 40, alignment: .leading)
                    Text("1.2").frame(width: 40, alignment: .center).offset(x: width * bandStart - 20)
                    Text("2.5").frame(width: 40, alignment: .center).offset(x: width * (bandStart + bandWidth) - 20)
                    Text("3 L").frame(width: 40, alignment: .trailing).offset(x: width - 40)
                }
                .font(.caption2.monospaced())
                .foregroundStyle(Theme.muted)
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water today: \(ml) millilitres. Target 1,200 to 2,500.")
    }
}

struct LatestCheckInCard: View {
    let fast: ActiveFast

    var body: some View {
        let last = fast.checkIns.last
        Card {
            Text("Latest check-in").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            if let last {
                let day = FastMath.dayNumber(hours: last.at.timeIntervalSince(fast.startedAt) / 3600)
                StatusPill(level: last.level)
                Text("Day \(day), \(Fmt.when(last.at))").font(.footnote).foregroundStyle(Theme.muted)
                if let top = last.notes.first {
                    Para(text: top.text, font: .subheadline)
                }
                Button("Check in again") { FastStore.shared.tab = .log }
                    .buttonStyle(WLButtonStyle(kind: .secondary))
            } else {
                Para(text: "No check-ins yet. Clinics record lying and standing blood pressure, pulse and symptoms twice a day.", font: .subheadline, color: Theme.ink2)
                Button("Check in now") { FastStore.shared.tab = .log }
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
            CardTitle(text: "End the fast and get help if you")
            Bullets(items: [
                "faint or nearly faint",
                "have chest pain, or a racing or irregular heartbeat",
                "become confused",
                "vomit and cannot keep water down",
                "start fast, deep breathing",
                "get a hot, swollen, painful joint",
            ])
            Para(text: "Supervised clinics also end a fast when its goal is reached or when vital signs become unstable.", font: .footnote, color: Theme.muted)
            if !clinician.name.isEmpty || !digits.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "stethoscope").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clinician.name.isEmpty ? "Your clinician" : clinician.name).font(.subheadline.weight(.semibold))
                        if !clinician.phone.isEmpty {
                            Text(clinician.phone).font(.footnote.monospaced()).foregroundStyle(Theme.ink2)
                        }
                    }
                    Spacer()
                    if let url = URL(string: "tel:\(digits)"), !digits.isEmpty {
                        Link(destination: url) {
                            Label("Call", systemImage: "phone.fill")
                        }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                    }
                }
            } else {
                Para(text: "Add your clinician's contact details in Profile so they show here.", font: .footnote, color: Theme.muted)
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
                    Eyebrow(text: "Refeeding \u{00B7} day \(day) of \(plan.days)")
                    CardTitle(text: stages.map(\.title).joined(separator: ", then "))
                    ForEach(stages, id: \.self) { stage in
                        Para(text: stage.text)
                    }
                    StatusPill(level: plan.tier.level, text: plan.tier.label)
                    HStack(spacing: 10) {
                        Button("See the full plan") { FastStore.shared.tab = .refeed }
                            .buttonStyle(WLButtonStyle(kind: .primary))
                        Button("Check in") { FastStore.shared.tab = .log }
                            .buttonStyle(WLButtonStyle(kind: .secondary))
                    }
                }
                Notice(tone: .caution) {
                    Text("No added salt yet.").bold()
                    Para(text: "After a fast, insulin makes the kidneys hold on to sodium and water. Salt now can cause swelling and strain the heart.", font: .subheadline)
                }
                RefeedWarningsCard()
            }
        }
    }
}

struct RefeedWarningsCard: View {
    var body: some View {
        Card {
            CardTitle(text: "Call your clinician if you notice")
            Bullets(items: [
                "swelling in your ankles, legs or face",
                "shortness of breath",
                "a racing or irregular heartbeat",
                "muscle weakness or new numbness",
                "confusion",
            ])
            Para(text: "These can signal refeeding syndrome (phosphate, potassium and magnesium rushing into cells) or refeeding swelling (edema). Both are most likely in the first 3 to 5 days of eating again.",
                 font: .footnote, color: Theme.muted)
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
            Eyebrow(text: "Get set up")
            CardTitle(text: "Start with the safety check")
            Para(text: "Water fasting is not safe for everyone. Answer a few questions first. They come straight from the contraindications in the clinical research.")
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Add your height, weight and age")
                Text("2. Answer the safety questions")
                Text("3. Plan your fast")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink2)
            Button("Go to the safety check") { FastStore.shared.tab = .profile }
                .buttonStyle(WLButtonStyle(kind: .primary))
            if screening.profileComplete && screening.missing > 0 {
                Text("\(Fmt.plural(screening.missing, "question")) left to answer.")
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
            Text("Water fasting is not safe for you.").bold()
            ForEach(blockers) { blocker in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: Theme.symbol(.stop)).foregroundStyle(Theme.stop)
                    Para(text: "\(blocker.title). \(blocker.why)", font: .subheadline)
                }
            }
            Para(text: "Talk to your doctor about what is safe for you. If an answer was a mistake, change it in Profile.", font: .footnote)
        }
    }
}

struct LastFastCard: View {
    let fast: PastFast

    private var line: String {
        var text = "\(Fmt.trimmed((fast.hours / 24 * 10).rounded() / 10)) days (\(Int(fast.hours.rounded())) h), ended \(Fmt.day(fast.endedAt))."
        if let start = fast.startWeightKg, let end = fast.endWeightKg {
            text += " Weight change \(Fmt.one(end - start)) kg."
        }
        return text
    }

    var body: some View {
        Card {
            Eyebrow(text: "Last fast")
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
            out.append("With osteopenia or osteoporosis, keep fasts to 72 hours or less.")
        }
        if needsSupervision && !supervised {
            out.append(target > 72 ? "Fasts longer than 72 hours need a clinician supervising." : "Your answers mean this fast needs a clinician supervising.")
        }
        if !screening.cautions.isEmpty && !doctorReviewed {
            out.append("Confirm your doctor has reviewed this fast and your medicines.")
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
        let startTitle = "Start \(Fmt.target(target)) fast"
        Card {
            Eyebrow(text: "Plan a fast")
            CardTitle(text: "How long?")
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
            NumberField(label: "Or enter hours", unit: "12 to 960", value: $customHours, decimals: false)
                .onChange(of: customHours) { _, value in
                    if let value, value >= 12, value <= 960 { target = Int(value) }
                }
            Toggle(isOn: $startedEarlier) {
                Text("I started earlier").font(.subheadline)
            }
            .tint(Theme.accent)
            if startedEarlier {
                DatePicker("Started", selection: $startDate,
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
                    Text("Your answers need a doctor's input:").bold()
                    ForEach(screening.cautions) { caution in
                        Para(text: "\(caution.question). \(caution.action)", font: .subheadline)
                    }
                }
                Toggle(isOn: $doctorReviewed) {
                    Text("My doctor has reviewed this fast and my medicines.").font(.subheadline)
                }
                .tint(Theme.accent)
            }
            if needsSupervision {
                Toggle(isOn: $supervised) {
                    Text("A clinician is supervising this fast, with regular checks of my blood pressure, pulse and blood tests.").font(.subheadline)
                }
                .tint(Theme.accent)
            }
            Button {
                start()
            } label: {
                Text(startTitle).frame(maxWidth: .infinity)
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
                error = "The start time is in the future. Turn off \"I started earlier\" to start now."
                return
            }
            if Date().timeIntervalSince(startDate) > 7 * 86_400 {
                error = "The start time is more than 7 days ago. Pick a later time."
                return
            }
            startAt = startDate
        }
        error = nil
        FastStore.shared.startFast(targetHours: target, supervised: supervised, start: startAt)
    }
}

struct BeforeYouStartCard: View {
    private let items: [(String, String)] = [
        ("See a doctor first", "Blood tests (metabolic panel and blood count), a urine test and a resting ECG."),
        ("Ease in for 48 hours", "Eat only raw and steamed fruit and vegetables for two days beforehand."),
        ("Plan to rest", "Quiet walking and lying down only. Rest protects muscle and prevents fainting."),
        ("Drink 1.2 to 2.5 L of water a day", "Plain distilled or low-mineral water."),
        ("Block out time to refeed", "At least half as long as the fast. A 10-day fast needs 5 days of careful refeeding."),
    ]

    var body: some View {
        Card {
            CardTitle(text: "Before you start")
            Para(text: "What supervised clinics ask of people starting a fast.", font: .footnote, color: Theme.muted)
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: item.1, font: .footnote, color: Theme.ink2)
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
            Eyebrow(text: "While you're here")
            CardTitle(text: "What a water fast does, hour by hour")
            Para(text: "From the glycogen switch at 12 to 36 hours to the protein changes that appear around day 3, read what the research found, including the risks.")
            Button("Open Learn") { FastStore.shared.tab = .learn }
                .buttonStyle(WLButtonStyle(kind: .secondary))
        }
    }
}
