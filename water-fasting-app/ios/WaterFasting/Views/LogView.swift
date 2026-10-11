import SwiftUI
import UIKit

struct LogView: View {
    var body: some View {
        let store = FastStore.shared
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        Color.clear.frame(height: 0).id("top")
                        if let fast = store.data.active {
                            ResultBanner(checkIns: fast.checkIns)
                            CheckInForm(isFast: true, start: fast.startedAt) {
                                withAnimation { proxy.scrollTo("top", anchor: .top) }
                            }
                            CheckInList(title: "Check-ins this fast", checkIns: fast.checkIns, start: fast.startedAt)
                            WeightCard(fast: fast)
                        } else if let refeed = store.data.refeed {
                            ResultBanner(checkIns: refeed.checkIns)
                            CheckInForm(isFast: false, start: refeed.startedAt) {
                                withAnimation { proxy.scrollTo("top", anchor: .top) }
                            }
                            CheckInList(title: "Refeeding check-ins", checkIns: refeed.checkIns, start: refeed.startedAt)
                        } else {
                            Card {
                                CardTitle(text: "No fast in progress")
                                Para(text: "Check-ins open once you start a fast. Each one records weight, blood pressure lying and standing, ketones and symptoms, then flags anything that needs attention.",
                                     color: Theme.ink2)
                                Button("Plan a fast") { store.tab = .today }
                                    .buttonStyle(WLButtonStyle(kind: .primary))
                            }
                        }
                        if !store.data.history.isEmpty {
                            HistoryCard(history: store.data.history)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .screenBackground()
            .navigationTitle("Log")
            .keyboardDoneButton()
        }
    }
}

/// Shows the grading of the check-in just saved.
struct ResultBanner: View {
    let checkIns: [CheckIn]

    var body: some View {
        let id = FastStore.shared.lastResultID
        if let id, let checkIn = checkIns.first(where: { $0.id == id }) {
            Notice(tone: tone(checkIn.level)) {
                StatusPill(level: checkIn.level)
                NoteList(notes: checkIn.notes)
            }
        }
    }

    private func tone(_ level: Level) -> NoticeTone {
        switch level {
        case .ok: return .ok
        case .caution: return .caution
        case .stop: return .stop
        }
    }
}

struct CheckInForm: View {
    let isFast: Bool
    let start: Date
    var onSaved: () -> Void

    @State private var weight: Double?
    @State private var ketones: Double?
    @State private var lyingSys: Double?
    @State private var lyingDia: Double?
    @State private var lyingPulse: Double?
    @State private var standingSys: Double?
    @State private var standingDia: Double?
    @State private var standingPulse: Double?
    @State private var symptoms: Set<String> = []
    @State private var note = ""
    @State private var error: String?
    @State private var formID = UUID()

    var body: some View {
        let day = FastMath.dayNumber(hours: Date().timeIntervalSince(start) / 3600)
        Card {
            Eyebrow(text: "\(isFast ? "Fast" : "Refeeding"), day \(day)")
            CardTitle(text: "Check in")
            Para(text: "Fill in what you have. Every field is optional.", font: .footnote, color: Theme.muted)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    NumberField(label: "Weight", unit: "kg", value: $weight)
                    NumberField(label: "Ketones (BHB)", unit: "mmol/L", value: $ketones)
                }

                Text("Blood pressure and pulse").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Para(text: "Measure lying down after 5 minutes of rest, then after 1 to 3 minutes standing.", font: .footnote, color: Theme.muted)
                VitalsBlock(title: "Lying down", systolic: $lyingSys, diastolic: $lyingDia, pulse: $lyingPulse)
                VitalsBlock(title: "Standing", systolic: $standingSys, diastolic: $standingDia, pulse: $standingPulse)

                Text("How do you feel?").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                SymptomGroupPicker(title: "Common in the first days", group: .common, selected: $symptoms)
                SymptomGroupPicker(title: "Keep an eye on", group: .watch, selected: $symptoms)
                SymptomGroupPicker(title: "Warning signs", group: .stop, selected: $symptoms)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Note").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
                    TextField("Anything else worth recording", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(10)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
            }
            .id(formID)

            if let error {
                Para(text: error, font: .footnote.weight(.semibold), color: Theme.stop)
            }
            Button {
                save()
            } label: {
                Text("Save check-in").frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .primary))
        }
    }

    private func save() {
        var problems: [String] = []
        func check(_ value: Double?, _ low: Double, _ high: Double, _ label: String) {
            guard let value else { return }
            if value < low || value > high {
                let message = "\(label) should be between \(Fmt.trimmed(low)) and \(Fmt.trimmed(high))."
                if !problems.contains(message) { problems.append(message) }
            }
        }
        check(weight, 25, 350, "Weight")
        check(ketones, 0, 15, "Ketones")
        check(lyingSys, 60, 260, "Systolic pressure")
        check(standingSys, 60, 260, "Systolic pressure")
        check(lyingDia, 30, 160, "Diastolic pressure")
        check(standingDia, 30, 160, "Diastolic pressure")
        check(lyingPulse, 30, 220, "Pulse")
        check(standingPulse, 30, 220, "Pulse")

        let toInt: (Double?) -> Int? = { value in value.map { Int($0.rounded()) } }
        let vitals = Vitals(lyingSystolic: toInt(lyingSys), lyingDiastolic: toInt(lyingDia), lyingPulse: toInt(lyingPulse),
                            standingSystolic: toInt(standingSys), standingDiastolic: toInt(standingDia), standingPulse: toInt(standingPulse))
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if weight == nil && ketones == nil && vitals.isEmpty && symptoms.isEmpty && trimmedNote.isEmpty {
            problems.append("Add at least one reading, symptom or note.")
        }
        guard problems.isEmpty else {
            error = problems.joined(separator: " ")
            return
        }

        let ordered = Research.symptoms.map(\.id).filter { symptoms.contains($0) }
        let checkIn = CheckIn(at: Date(), weightKg: weight, ketones: ketones, vitals: vitals,
                              symptoms: ordered, note: String(trimmedNote.prefix(500)))
        FastStore.shared.addCheckIn(checkIn)

        weight = nil
        ketones = nil
        lyingSys = nil
        lyingDia = nil
        lyingPulse = nil
        standingSys = nil
        standingDia = nil
        standingPulse = nil
        symptoms = []
        note = ""
        error = nil
        formID = UUID()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onSaved()
    }
}

private struct VitalsBlock: View {
    let title: String
    @Binding var systolic: Double?
    @Binding var diastolic: Double?
    @Binding var pulse: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
            HStack(alignment: .top, spacing: 10) {
                NumberField(label: "Systolic", value: $systolic, decimals: false)
                NumberField(label: "Diastolic", value: $diastolic, decimals: false)
                NumberField(label: "Pulse", value: $pulse, decimals: false)
            }
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

private struct SymptomGroupPicker: View {
    let title: String
    let group: SymptomGroup
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
            FlowLayout(spacing: 8) {
                ForEach(Research.symptoms.filter { $0.group == group }) { symptom in
                    SymptomChip(label: symptom.label, group: group, isOn: selected.contains(symptom.id)) {
                        if selected.contains(symptom.id) {
                            selected.remove(symptom.id)
                        } else {
                            selected.insert(symptom.id)
                        }
                    }
                }
            }
        }
    }
}

private struct SymptomChip: View {
    let label: String
    let group: SymptomGroup
    let isOn: Bool
    let action: () -> Void

    private var onColor: Color {
        switch group {
        case .common: return Theme.ink
        case .watch: return Theme.warn
        case .stop: return Theme.stop
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .foregroundStyle(isOn ? Theme.surface : Theme.ink)
                .background(isOn ? onColor : Theme.surface2, in: Capsule())
                .overlay(Capsule().stroke(isOn ? onColor : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct CheckInList: View {
    let title: String
    let checkIns: [CheckIn]
    let start: Date

    var body: some View {
        Card {
            CardTitle(text: title)
            if checkIns.isEmpty {
                Para(text: "None yet.", color: Theme.muted)
            } else {
                ForEach(checkIns.reversed()) { checkIn in
                    CheckInRow(checkIn: checkIn, start: start)
                }
            }
        }
    }
}

struct CheckInRow: View {
    let checkIn: CheckIn
    let start: Date
    @State private var confirmRemove = false

    private var metrics: [String] {
        var out: [String] = []
        let v = checkIn.vitals
        if let w = checkIn.weightKg { out.append("\(Fmt.one(w)) kg") }
        if let k = checkIn.ketones { out.append("BHB \(Fmt.trimmed(k))") }
        if v.lyingSystolic != nil || v.lyingDiastolic != nil || v.lyingPulse != nil {
            out.append("Lying \(v.lyingSystolic.map(String.init) ?? "?")/\(v.lyingDiastolic.map(String.init) ?? "?")" + (v.lyingPulse.map { ", \($0) bpm" } ?? ""))
        }
        if v.standingSystolic != nil || v.standingDiastolic != nil || v.standingPulse != nil {
            out.append("Standing \(v.standingSystolic.map(String.init) ?? "?")/\(v.standingDiastolic.map(String.init) ?? "?")" + (v.standingPulse.map { ", \($0) bpm" } ?? ""))
        }
        return out
    }

    var body: some View {
        let day = FastMath.dayNumber(hours: checkIn.at.timeIntervalSince(start) / 3600)
        let labels = checkIn.symptoms.compactMap { id in Research.symptoms.first { $0.id == id } }
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(Fmt.when(checkIn.at)).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusPill(level: checkIn.level)
            }
            if !metrics.isEmpty {
                Para(text: metrics.joined(separator: "   "), font: .footnote.monospaced(), color: Theme.ink2)
            }
            if !labels.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(labels) { symptom in
                        Text(symptom.label)
                            .font(.caption)
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(tagColor(symptom.group), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            if !checkIn.note.isEmpty {
                Para(text: checkIn.note, font: .subheadline)
            }
            NoteList(notes: checkIn.notes)
            Button("Remove") { confirmRemove = true }
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .confirmationDialog("Remove this check-in?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remove check-in", role: .destructive) { FastStore.shared.removeCheckIn(checkIn.id) }
                }
        }
    }

    private func tagColor(_ group: SymptomGroup) -> Color {
        switch group {
        case .common: return Theme.surface2
        case .watch: return Theme.warnSoft
        case .stop: return Theme.stopSoft
        }
    }
}

struct WeightCard: View {
    let fast: ActiveFast

    var body: some View {
        let weighed = fast.checkIns.filter { $0.weightKg != nil }
        if let startWeight = fast.startWeightKg, let last = weighed.last, let latest = last.weightKg {
            let change = startWeight - latest
            let days = max(last.at.timeIntervalSince(fast.startedAt) / 86_400, 0.01)
            let changeText = "\(change >= 0 ? "\u{2212}" : "+")\(Fmt.one(abs(change)))"
            let detail = "kg change (\(Fmt.one(abs(change) / startWeight * 100))%), about \(Fmt.one(abs(change) / days)) kg a day"
            Card {
                CardTitle(text: "Weight")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    StatTile(value: Fmt.one(startWeight), caption: "kg at the start")
                    StatTile(value: Fmt.one(latest), caption: "kg latest")
                    StatTile(value: changeText, caption: detail)
                }
                Para(text: "Expected: 0.9 to 1.5 kg a day over the first 3 days, slowing to 0.25 to 0.40 kg a day by days 7 to 10. Across 5 to 20 day fasts about two-thirds of the loss is lean mass, mostly glycogen and water that return within 3 to 5 days of eating. The fat loss stays.",
                     font: .footnote, color: Theme.muted)
            }
        }
    }
}

struct StatTile: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Para(text: caption, font: .footnote, color: Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HistoryCard: View {
    let history: [PastFast]

    var body: some View {
        Card {
            CardTitle(text: "Past fasts")
            ForEach(history) { fast in
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(fast.hours.rounded())) h").font(.subheadline.monospaced().weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(Fmt.day(fast.startedAt)).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        StatusPill(level: fast.worst, text: worstText(fast.worst))
                    }
                    Para(text: summary(fast), font: .footnote.monospaced(), color: Theme.ink2)
                }
            }
        }
    }

    private func worstText(_ level: Level) -> String {
        switch level {
        case .ok: return "No warning signs"
        case .caution: return "Had cautions"
        case .stop: return "Had warning signs"
        }
    }

    private func summary(_ fast: PastFast) -> String {
        var parts = ["Target \(Fmt.target(fast.targetHours))", fast.reason.label]
        if let start = fast.startWeightKg, let end = fast.endWeightKg {
            parts.append("\(Fmt.one(start)) to \(Fmt.one(end)) kg")
        }
        parts.append(Fmt.plural(fast.checkInCount, "check-in"))
        return parts.joined(separator: "   ")
    }
}
