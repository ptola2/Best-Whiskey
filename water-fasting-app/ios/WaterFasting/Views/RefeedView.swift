import SwiftUI

struct RefeedView: View {
    @State private var plannerDays: Double?

    var body: some View {
        let store = FastStore.shared
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let refeed = store.data.refeed {
                        ActiveRefeedSection(refeed: refeed)
                    } else {
                        PlannerSection(days: $plannerDays, prefilled: store.data.active != nil)
                    }
                    DisclaimerFooter()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(tr("tab.refeed"))
            .keyboardDoneButton()
            .onAppear {
                if plannerDays == nil {
                    if let fast = store.data.active {
                        plannerDays = Double(fast.targetHours) / 24
                    } else {
                        plannerDays = 5
                    }
                }
            }
        }
    }
}

struct ActiveRefeedSection: View {
    let refeed: RefeedState
    @State private var confirmFinish = false

    var body: some View {
        let plan = RefeedPlanner.build(fastHours: refeed.fastHours, data: FastStore.shared.data, weightKg: refeed.endWeightKg)
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let day = min(Int(floor(context.date.timeIntervalSince(refeed.startedAt) / 86_400)) + 1, plan.days)
            let intro = tr("refeed.active.intro", Int(refeed.fastHours.rounded()), trCount("count.days", plan.days))
            VStack(spacing: 14) {
                Card {
                    Eyebrow(text: tr("refeed.active.eyebrow"))
                    CardTitle(text: tr("refeed.active.day", day, plan.days))
                    Para(text: intro)
                }
                PlanBody(plan: plan, currentDay: day)
                RefeedWarningsCard()
                Card {
                    CardTitle(text: tr("refeed.finish.title"))
                    Para(text: tr("refeed.finish.body"), font: .subheadline, color: Theme.ink2)
                    Button(tr("refeed.finish.button")) { confirmFinish = true }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                }
            }
        }
        .confirmationDialog(tr("refeed.finish.confirm"), isPresented: $confirmFinish, titleVisibility: .visible) {
            Button(tr("refeed.finish.confirm_action")) { FastStore.shared.finishRefeed() }
            Button(tr("refeed.finish.not_yet"), role: .cancel) {}
        }
    }
}

struct PlannerSection: View {
    @Binding var days: Double?
    let prefilled: Bool

    var body: some View {
        VStack(spacing: 14) {
            Card {
                Eyebrow(text: tr("refeed.planner.eyebrow"))
                CardTitle(text: tr("refeed.planner.title"))
                Para(text: tr("refeed.planner.body"))
                if prefilled {
                    Para(text: tr("refeed.planner.prefilled"), font: .footnote, color: Theme.muted)
                }
                NumberField(label: tr("refeed.planner.length"), unit: tr("unit.days"), value: $days)
                    .frame(maxWidth: 220, alignment: .leading)
            }
            if let d = days, d >= 1, d <= 40 {
                PlanBody(plan: RefeedPlanner.build(fastHours: d * 24, data: FastStore.shared.data, weightKg: nil), currentDay: 0)
            } else {
                Card {
                    Para(text: tr("refeed.planner.invalid"), color: Theme.muted)
                }
            }
        }
    }
}

struct PlanBody: View {
    let plan: RefeedPlan
    let currentDay: Int

    var body: some View {
        let reasons = plan.reasons.isEmpty ? "" : " " + tr("refeed.plan.for_you", trList(plan.reasons))
        VStack(spacing: 14) {
            Card {
                HStack(alignment: .center) {
                    CardTitle(text: tr("refeed.plan.risk_title"), style: .title3)
                    Spacer()
                    StatusPill(level: plan.tier.level, text: plan.tier.label)
                }
                Para(text: plan.tier.criteria + reasons, font: .subheadline)
                if plan.tier == .high {
                    Notice(tone: .stop) {
                        Text(tr("refeed.plan.needs_clinician")).bold()
                        Para(text: tr("refeed.plan.needs_clinician.body"), font: .subheadline)
                    }
                }
                KeyValueRow(label: tr("refeed.plan.length")) {
                    Para(text: tr("refeed.plan.length_value", trCount("count.days", plan.days)), font: .subheadline)
                }
                KeyValueRow(label: tr("refeed.plan.calories")) {
                    Para(text: plan.calorieHeadline, font: .subheadline)
                    if let value = plan.calorieValue {
                        Text(value).font(.subheadline.monospaced().weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    if !plan.calorieBasis.isEmpty {
                        Para(text: plan.calorieBasis, font: .footnote, color: Theme.muted)
                    }
                }
                KeyValueRow(label: tr("refeed.plan.fluids")) {
                    Para(text: plan.tier.fluids, font: .subheadline)
                }
                KeyValueRow(label: tr("refeed.plan.monitoring")) {
                    Para(text: plan.tier.monitoring, font: .subheadline)
                }
                Para(text: tr("refeed.plan.source"), font: .footnote, color: Theme.muted)
            }
            Card {
                CardTitle(text: tr("refeed.plan.by_day"), style: .title3)
                ForEach(Array(plan.schedule.enumerated()), id: \.offset) { index, stages in
                    DayRow(number: index + 1, stages: stages, currentDay: currentDay)
                }
                Para(text: tr("refeed.plan.no_salt"), font: .footnote)
            }
        }
    }
}

private struct DayRow: View {
    let number: Int
    let stages: [RefeedStage]
    let currentDay: Int

    var body: some View {
        let isToday = currentDay == number
        let isDone = currentDay > 0 && number < currentDay
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("refeed.plan.day", number)).font(.footnote.monospaced())
                if isToday {
                    Text(tr("refeed.plan.today")).font(.caption.monospaced())
                }
            }
            .foregroundStyle(isToday ? Theme.ink : Theme.muted)
            .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(stages, id: \.self) { stage in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Para(text: stage.text, font: .footnote, color: Theme.ink2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(isToday ? Theme.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isToday ? Theme.accent : Theme.line, lineWidth: 1))
        .opacity(isDone ? 0.6 : 1)
    }
}
