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
            .navigationTitle("Refeed")
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
            let intro = "After a fast of \(Int(refeed.fastHours.rounded())) hours, refeed for at least \(Fmt.plural(plan.days, "day")): half the length of the fast."
            VStack(spacing: 14) {
                Card {
                    Eyebrow(text: "Your refeeding plan")
                    CardTitle(text: "Day \(day) of \(plan.days)")
                    Para(text: intro)
                }
                PlanBody(plan: plan, currentDay: day)
                RefeedWarningsCard()
                Card {
                    CardTitle(text: "Finished refeeding?")
                    Para(text: "Move on to a whole-food, low-sodium diet. Without lasting changes, blood pressure, blood sugar and blood fats drift back toward where they started within 3 to 4 months.",
                         font: .subheadline, color: Theme.ink2)
                    Button("Mark refeeding complete") { confirmFinish = true }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                }
            }
        }
        .confirmationDialog("Mark refeeding complete?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Mark complete") { FastStore.shared.finishRefeed() }
            Button("Not yet", role: .cancel) {}
        }
    }
}

struct PlannerSection: View {
    @Binding var days: Double?
    let prefilled: Bool

    var body: some View {
        VStack(spacing: 14) {
            Card {
                Eyebrow(text: "Refeeding planner")
                CardTitle(text: "Breaking a fast safely")
                Para(text: "Coming off a fast is the riskiest part. Eating too much too fast can drive phosphate, potassium and magnesium into cells all at once (refeeding syndrome), and salt can make the body hold fluid. Plan the way back before you start.")
                if prefilled {
                    Para(text: "Prefilled with your current target. When you end the fast, this plan starts automatically.", font: .footnote, color: Theme.muted)
                }
                NumberField(label: "Fast length", unit: "days", value: $days)
                    .frame(maxWidth: 200, alignment: .leading)
            }
            if let d = days, d >= 1, d <= 40 {
                PlanBody(plan: RefeedPlanner.build(fastHours: d * 24, data: FastStore.shared.data, weightKg: nil), currentDay: 0)
            } else {
                Card {
                    Para(text: "Enter a fast length between 1 and 40 days.", color: Theme.muted)
                }
            }
        }
    }
}

struct PlanBody: View {
    let plan: RefeedPlan
    let currentDay: Int

    var body: some View {
        let reasons = plan.reasons.isEmpty ? "" : " For you: \(plan.reasons.joined(separator: ", "))."
        VStack(spacing: 14) {
            Card {
                HStack(alignment: .center) {
                    CardTitle(text: "Refeeding risk", style: .title3)
                    Spacer()
                    StatusPill(level: plan.tier.level, text: plan.tier.label)
                }
                Para(text: plan.tier.criteria + reasons, font: .subheadline)
                if plan.tier == .high {
                    Notice(tone: .stop) {
                        Text("This refeed needs a clinician.").bold()
                        Para(text: "Significant-risk refeeding uses prescribed thiamine and daily blood tests.", font: .subheadline)
                    }
                }
                KeyValueRow(label: "Length") {
                    Para(text: "\(Fmt.plural(plan.days, "day")), at least half the fast", font: .subheadline)
                }
                KeyValueRow(label: "Calories") {
                    Para(text: plan.calorieHeadline, font: .subheadline)
                    if let value = plan.calorieValue {
                        Text(value).font(.subheadline.monospaced().weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    if !plan.calorieBasis.isEmpty {
                        Para(text: plan.calorieBasis, font: .footnote, color: Theme.muted)
                    }
                }
                KeyValueRow(label: "Salt and fluids") {
                    Para(text: plan.tier.fluids, font: .subheadline)
                }
                KeyValueRow(label: "Monitoring") {
                    Para(text: plan.tier.monitoring, font: .subheadline)
                }
                Para(text: "Ranges come from ASPEN and NICE refeeding guidance. Your clinician sets the final numbers.", font: .footnote, color: Theme.muted)
            }
            Card {
                CardTitle(text: "Day by day", style: .title3)
                ForEach(Array(plan.schedule.enumerated()), id: \.offset) { index, stages in
                    DayRow(number: index + 1, stages: stages, currentDay: currentDay)
                }
                Para(text: "Throughout: no added salt or salty seasonings. Insulin makes the kidneys hold sodium and water after a fast, which can cause swelling and strain the heart.", font: .footnote)
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
                Text("Day \(number)").font(.footnote.monospaced())
                if isToday {
                    Text("today").font(.caption.monospaced())
                }
            }
            .foregroundStyle(isToday ? Theme.ink : Theme.muted)
            .frame(width: 58, alignment: .leading)
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
