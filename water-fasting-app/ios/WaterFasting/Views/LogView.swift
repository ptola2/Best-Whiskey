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
                            CheckInList(title: tr("log.list.fast"), checkIns: fast.checkIns, start: fast.startedAt)
                            WeightCard(fast: fast)
                        } else if let refeed = store.data.refeed {
                            ResultBanner(checkIns: refeed.checkIns)
                            CheckInForm(isFast: false, start: refeed.startedAt) {
                                withAnimation { proxy.scrollTo("top", anchor: .top) }
                            }
                            CheckInList(title: tr("log.list.refeed"), checkIns: refeed.checkIns, start: refeed.startedAt)
                        } else {
                            Card {
                                CardTitle(text: tr("log.empty.title"))
                                Para(text: tr("log.empty.body"), color: Theme.ink2)
                                Button(tr("log.empty.plan")) { store.tab = .today }
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
            .navigationTitle(tr("tab.log"))
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
                NoteList(notes: FastStore.shared.notes(for: checkIn))
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
    /// Values taken from Apple Health, which are not saved back to it.
    @State private var imports = HealthImports()

    var body: some View {
        let day = FastMath.dayNumber(hours: Date().timeIntervalSince(start) / 3600)
        Card {
            Eyebrow(text: isFast ? tr("checkin.eyebrow.fast", day) : tr("checkin.eyebrow.refeed", day))
            CardTitle(text: tr("checkin.title"))
            Para(text: tr("checkin.optional"), font: .footnote, color: Theme.muted)

            VStack(alignment: .leading, spacing: 14) {
                HealthReadingsPanel { kg in
                    weight = kg
                    imports.weightKg = kg
                } onPressure: { reading, lying in
                    let taken = HealthImports.Reading(systolic: reading.systolic, diastolic: reading.diastolic)
                    if lying {
                        lyingSys = Double(reading.systolic)
                        lyingDia = Double(reading.diastolic)
                        if let pulse = reading.pulse { lyingPulse = Double(pulse) }
                        imports.lying = taken
                    } else {
                        standingSys = Double(reading.systolic)
                        standingDia = Double(reading.diastolic)
                        if let pulse = reading.pulse { standingPulse = Double(pulse) }
                        imports.standing = taken
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    NumberField(label: tr("checkin.weight"), unit: tr("unit.kg"), value: $weight)
                    NumberField(label: tr("checkin.ketones"), unit: tr("unit.mmol_l"), value: $ketones)
                }

                Text(tr("checkin.bp.title")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Para(text: tr("checkin.bp.how"), font: .footnote, color: Theme.muted)
                VitalsBlock(title: tr("checkin.bp.lying"), systolic: $lyingSys, diastolic: $lyingDia, pulse: $lyingPulse)
                VitalsBlock(title: tr("checkin.bp.standing"), systolic: $standingSys, diastolic: $standingDia, pulse: $standingPulse)

                Text(tr("checkin.feel")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                SymptomGroupPicker(title: tr("checkin.group.common"), group: .common, selected: $symptoms)
                SymptomGroupPicker(title: tr("checkin.group.watch"), group: .watch, selected: $symptoms)
                SymptomGroupPicker(title: tr("checkin.group.stop"), group: .stop, selected: $symptoms)

                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("checkin.note")).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
                    TextField(tr("checkin.note.placeholder"), text: $note, axis: .vertical)
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
                Text(tr("checkin.save")).frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .primary))
        }
    }

    private func save() {
        var problems: [String] = []
        func check(_ value: Double?, _ low: Int, _ high: Int, _ labelKey: String) {
            guard let value else { return }
            if value < Double(low) || value > Double(high) {
                let message = tr("checkin.error.range", tr(labelKey), low, high)
                if !problems.contains(message) { problems.append(message) }
            }
        }
        check(weight, 25, 350, "checkin.weight")
        check(ketones, 0, 15, "checkin.ketones")
        check(lyingSys, 60, 260, "checkin.systolic")
        check(standingSys, 60, 260, "checkin.systolic")
        check(lyingDia, 30, 160, "checkin.diastolic")
        check(standingDia, 30, 160, "checkin.diastolic")
        check(lyingPulse, 30, 220, "checkin.pulse")
        check(standingPulse, 30, 220, "checkin.pulse")

        let vitalInputs = [lyingSys, lyingDia, lyingPulse, standingSys, standingDia, standingPulse]
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if weight == nil && ketones == nil && vitalInputs.allSatisfy({ $0 == nil }) && symptoms.isEmpty && trimmedNote.isEmpty {
            problems.append(tr("checkin.error.empty"))
        }
        guard problems.isEmpty else {
            error = problems.joined(separator: " ")
            return
        }

        // Converted only after the range checks, and through safeInt, so oversized input can never trap.
        let toInt: (Double?) -> Int? = { value in value.flatMap { Fmt.safeInt($0) } }
        let vitals = Vitals(lyingSystolic: toInt(lyingSys), lyingDiastolic: toInt(lyingDia), lyingPulse: toInt(lyingPulse),
                            standingSystolic: toInt(standingSys), standingDiastolic: toInt(standingDia), standingPulse: toInt(standingPulse))

        let ordered = Research.symptoms.map(\.id).filter { symptoms.contains($0) }
        let checkIn = CheckIn(at: Date(), weightKg: weight, ketones: ketones, vitals: vitals,
                              symptoms: ordered, note: String(trimmedNote.prefix(500)))
        let saved = FastStore.shared.addCheckIn(checkIn)
        let taken = imports
        Task { await HealthService.shared.save(saved, imports: taken) }

        imports = HealthImports()
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

/// Recent weight and blood pressure from Apple Health (a smart scale or cuff), each one tap away from the form.
private struct HealthReadingsPanel: View {
    var onWeight: (Double) -> Void
    var onPressure: (HealthService.Pressure, _ lying: Bool) -> Void

    @State private var weight: HealthService.Weight?
    @State private var pressures: [HealthService.Pressure] = []
    @State private var loaded = false

    var body: some View {
        let health = HealthService.shared
        if health.isOn {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(.pink)
                    Text(tr("health.import.title")).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                if loaded && weight == nil && pressures.isEmpty {
                    Para(text: tr("health.import.none"), font: .footnote, color: Theme.muted)
                }
                if let weight {
                    // One decimal, as the form shows it, so the value is recognised as unchanged when saved.
                    let kg = (weight.kg * 10).rounded() / 10
                    HStack(spacing: 8) {
                        Para(text: tr("health.import.weight", Fmt.one(kg), Fmt.when(weight.date)), font: .footnote, color: Theme.ink2)
                        Spacer(minLength: 8)
                        Button(tr("health.use")) { onWeight(kg) }
                            .accessibilityLabel(tr("health.use_for", tr("checkin.weight")))
                    }
                }
                ForEach(pressures) { reading in
                    VStack(alignment: .leading, spacing: 6) {
                        Para(text: describe(reading), font: .footnote, color: Theme.ink2)
                        HStack(spacing: 8) {
                            Button(tr("checkin.bp.lying")) { onPressure(reading, true) }
                                .accessibilityLabel(tr("health.use_for", tr("checkin.bp.lying")))
                            Button(tr("checkin.bp.standing")) { onPressure(reading, false) }
                                .accessibilityLabel(tr("health.use_for", tr("checkin.bp.standing")))
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Theme.accent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .task {
                weight = await health.latestWeight(withinHours: 24)
                pressures = await health.recentPressures(withinHours: 24, limit: 3)
                loaded = true
            }
        }
    }

    private func describe(_ reading: HealthService.Pressure) -> String {
        let when = Fmt.when(reading.date)
        if let pulse = reading.pulse {
            return tr("health.import.bp_pulse", reading.systolic, reading.diastolic, pulse, when)
        }
        return tr("health.import.bp", reading.systolic, reading.diastolic, when)
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
                NumberField(label: tr("checkin.systolic"), value: $systolic, decimals: false)
                NumberField(label: tr("checkin.diastolic"), value: $diastolic, decimals: false)
                NumberField(label: tr("checkin.pulse"), value: $pulse, decimals: false)
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
                Para(text: tr("log.list.none"), color: Theme.muted)
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

    private func pressure(_ systolic: Int?, _ diastolic: Int?, _ pulse: Int?) -> String {
        let reading = tr("checkin.row.pressure", systolic.map(String.init) ?? "?", diastolic.map(String.init) ?? "?")
        guard let pulse else { return reading }
        return reading + ", " + tr("unit.bpm", pulse)
    }

    private var metrics: [String] {
        var out: [String] = []
        let v = checkIn.vitals
        if let w = checkIn.weightKg { out.append(Fmt.one(w) + " " + tr("unit.kg")) }
        if let k = checkIn.ketones { out.append(tr("checkin.row.bhb", Fmt.trimmed(k))) }
        if v.lyingSystolic != nil || v.lyingDiastolic != nil || v.lyingPulse != nil {
            out.append(tr("checkin.row.lying", pressure(v.lyingSystolic, v.lyingDiastolic, v.lyingPulse)))
        }
        if v.standingSystolic != nil || v.standingDiastolic != nil || v.standingPulse != nil {
            out.append(tr("checkin.row.standing", pressure(v.standingSystolic, v.standingDiastolic, v.standingPulse)))
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
                    Text(tr("checkin.row.day", day)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(Fmt.when(checkIn.at)).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusPill(level: checkIn.level)
            }
            if !metrics.isEmpty {
                Para(text: metrics.joined(separator: "   "), font: .footnote.monospacedDigit(), color: Theme.ink2)
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
            NoteList(notes: FastStore.shared.notes(for: checkIn))
            Button(tr("checkin.row.remove")) { confirmRemove = true }
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .confirmationDialog(tr("checkin.row.remove_confirm"), isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button(tr("checkin.row.remove_action"), role: .destructive) { FastStore.shared.removeCheckIn(checkIn.id) }
                    Button(tr("common.cancel"), role: .cancel) {}
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
            let changeText = (change >= 0 ? "\u{2212}" : "+") + Fmt.one(abs(change))
            let detail = tr("weight.change_detail", Fmt.one(abs(change) / startWeight * 100), Fmt.one(abs(change) / days))
            Card {
                CardTitle(text: tr("weight.title"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    StatTile(value: Fmt.one(startWeight), caption: tr("weight.start"))
                    StatTile(value: Fmt.one(latest), caption: tr("weight.latest"))
                    StatTile(value: changeText, caption: detail)
                }
                Para(text: tr("weight.expected"), font: .footnote, color: Theme.muted)
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
            CardTitle(text: tr("history.title"))
            ForEach(history) { fast in
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("unit.hours_short", Int(fast.hours.rounded()))).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                            Text(Fmt.day(fast.startedAt)).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        StatusPill(level: fast.worst, text: worstText(fast.worst))
                    }
                    Para(text: summary(fast), font: .footnote.monospacedDigit(), color: Theme.ink2)
                }
            }
        }
    }

    private func worstText(_ level: Level) -> String {
        switch level {
        case .ok: return tr("history.worst.ok")
        case .caution: return tr("history.worst.caution")
        case .stop: return tr("history.worst.stop")
        }
    }

    private func summary(_ fast: PastFast) -> String {
        var parts = [tr("history.target", Fmt.target(fast.targetHours)), fast.reason.label]
        if let start = fast.startWeightKg, let end = fast.endWeightKg {
            parts.append(tr("history.weight", Fmt.one(start), Fmt.one(end)))
        }
        parts.append(trCount("count.checkins", fast.checkInCount))
        return parts.joined(separator: "   ")
    }
}
