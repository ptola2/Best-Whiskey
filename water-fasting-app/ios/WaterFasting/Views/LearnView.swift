import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        Eyebrow(text: "The science")
                        CardTitle(text: "What a water-only fast does to the body")
                        Para(text: "Water-only fasting means no food and no caloric drinks, only plain water. With nothing coming in, the body runs on its own reserves, first glycogen and then fat turned into ketones. These changes can lower blood pressure and improve blood sugar markers. They also stress the kidneys, electrolytes and acid balance, which is why the research on fasts beyond a few days comes from medically supervised clinics.")
                    }
                    LearnSection(title: "Types of fasting compared", startsOpen: true) { ProtocolsContent() }
                    LearnSection(title: "Hour by hour") { PhasesContent() }
                    LearnSection(title: "What the studies found") { StudiesContent() }
                    LearnSection(title: "Side effects and risks") { RisksContent() }
                    LearnSection(title: "Refeeding syndrome") { RefeedingContent() }
                    LearnSection(title: "Who should not water fast") { ContraindicationsContent() }
                    LearnSection(title: "Sources") { SourcesContent() }
                    DisclaimerFooter()
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Learn")
        }
    }
}

struct LearnSection<Content: View>: View {
    let title: String
    var startsOpen = false
    @ViewBuilder var content: Content

    @State private var open: Bool? = nil

    var body: some View {
        let isOpen = Binding<Bool>(get: { open ?? startsOpen }, set: { open = $0 })
        Card {
            DisclosureGroup(isExpanded: isOpen) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            } label: {
                Text(title)
                    .font(Theme.display(.title3))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

private struct InfoBlock: View {
    let title: String
    let lines: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            ForEach(lines.indices, id: \.self) { index in
                let line = lines[index]
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 70, alignment: .leading)
                    Para(text: line.1, font: .footnote, color: Theme.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProtocolsContent: View {
    var body: some View {
        ForEach(Research.protocols) { item in
            InfoBlock(title: item.name, lines: [
                ("Calories", item.calories),
                ("Allowed", item.allowed),
                ("Length", item.length),
                ("Setting", item.setting),
            ])
        }
        Para(text: "Durations in studies: short-term 24 to 72 hours, prolonged 4 to 21 days, extreme over 21 days (up to 40 in some residential groups).",
             font: .footnote, color: Theme.muted)
    }
}

private struct PhasesContent: View {
    var body: some View {
        ForEach(Research.phases) { phase in
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.bands[phase.id])
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.range).font(.caption.monospaced()).foregroundStyle(Theme.muted)
                    Text(phase.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: phase.text, font: .footnote, color: Theme.ink2)
                }
            }
        }
        Text("Hormones and signals").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).padding(.top, 6)
        ForEach(Research.hormones) { row in
            InfoBlock(title: row.marker, lines: [
                ("Change", row.change),
                ("Why", row.why),
                ("Effect", row.effect),
            ])
        }
        Para(text: "Autophagy: once mTORC1 switches off, cells start breaking down and recycling damaged proteins and mitochondria. Fasting also raises spermidine, which keeps this recycling going.",
             font: .footnote, color: Theme.ink2)
    }
}

private struct StudiesContent: View {
    var body: some View {
        ForEach(Research.studies) { study in
            VStack(alignment: .leading, spacing: 3) {
                Text(study.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(study.cohort).font(.caption.monospaced()).foregroundStyle(Theme.muted)
                Para(text: study.finding, font: .footnote, color: Theme.ink2)
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            StatTile(value: "0.9-1.5", caption: "kg a day lost over days 1 to 3, mostly water and glycogen")
            StatTile(value: "0.25-0.40", caption: "kg a day by days 7 to 10")
            StatTile(value: "~2/3", caption: "of loss in 5 to 20 day fasts is lean mass, mostly regained within 3 to 5 days")
        }
        Para(text: "Why blood pressure falls: low insulin makes the kidneys shed sodium and water. After 48 to 72 hours the nervous system calms (less sympathetic, more parasympathetic tone). BHB also relaxes artery walls through nitric oxide and potassium channels.",
             font: .footnote, color: Theme.ink2)
        Para(text: "The benefits fade: 3 to 4 months later, blood pressure, glucose and blood fats are usually back near where they started unless eating habits change for good. A fast works as a short reset, not a cure.",
             font: .footnote, color: Theme.ink2)
    }
}

private struct RisksContent: View {
    var body: some View {
        Para(text: "A review of 768 medically supervised water fasts (2 to 41 days, median 7) graded every side effect on the standard CTCAE scale.", font: .subheadline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            StatTile(value: "90%", caption: "had at least one side effect by day 5, mostly mild")
            StatTile(value: "20/28/32%", caption: "had a severe (Grade 3) event by days 5, 10 and 15")
            StatTile(value: "1 / 0", caption: "life-threatening events / deaths, all under daily medical checks")
        }
        Para(text: "Common mild effects: tiredness, nausea, poor sleep, headache, dizziness, fainting, indigestion, dry mouth and lower back pain.",
             font: .footnote, color: Theme.ink2)
        ForEach(Research.complications) { item in
            InfoBlock(title: item.name, lines: [
                ("Onset", item.onset),
                ("Cause", item.cause),
                ("Signs", item.signs),
                ("Clinics", item.response),
            ])
        }
        Para(text: "Electrolytes: the body loses about 300 mEq of potassium over the first 7 days, even while blood levels look normal (3.5 to 4.0 mmol/L). Blood pH settles around 7.32 to 7.36 as bicarbonate is used up.",
             font: .footnote, color: Theme.ink2)
    }
}

private struct RefeedingContent: View {
    var body: some View {
        Para(text: "During a long fast, the phosphate, magnesium and potassium stored inside cells run low, even when blood tests look normal. When carbohydrate returns, insulin drives these minerals into cells all at once. Blood phosphate can crash below 0.30 mmol/L (1.0 mg/dL). Without phosphate, red cells cannot release oxygen properly, which can lead to breathing failure, dangerous heart rhythms and muscle breakdown. Restarting carbohydrate also burns through thiamine (vitamin B1), risking lactic acidosis and Wernicke's encephalopathy.",
             font: .footnote, color: Theme.ink2)
        Para(text: "Refeeding swelling (edema) is a separate problem: insulin makes the kidneys hold sodium and water. Salt eaten too early can cause swollen legs, fluid on the lungs and heart strain.",
             font: .footnote, color: Theme.ink2)
        InfoBlock(title: "ASPEN severity (drop in phosphorus, potassium or magnesium within 5 days of eating)", lines: [
            ("Mild", "10 to 20%"),
            ("Moderate", "20 to 30%"),
            ("Severe", "Over 30%, or organ problems, or thiamine deficiency"),
        ])
        Para(text: "Higher risk: little or no food for more than 7 to 10 days, BMI under 16, unintended loss of 10 to 15% of body weight in 3 to 6 months, or low phosphate or potassium before eating again.",
             font: .footnote, color: Theme.ink2)
        Para(text: "The rule of thumb: refeed for at least half as long as the fast, starting with diluted juice, then fruit and steamed vegetables, then starches and plant fats, with no added salt. The Refeed tab builds this plan for you.",
             font: .footnote, color: Theme.ink2)
    }
}

private struct ContraindicationsContent: View {
    var body: some View {
        Text("Ruled out completely").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
        NoteList(notes: Research.absolute.map { Note(level: .stop, text: "\($0.question). \($0.why)") }
                 + [Note(level: .stop, text: "BMI under 18.5. Too few reserves to withstand starvation.")])
        Text("Needs a doctor and often inpatient care").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).padding(.top, 6)
        NoteList(notes: Research.relative.map { Note(level: .caution, text: "\($0.question). \($0.why)") })
    }
}

private struct SourcesContent: View {
    var body: some View {
        ForEach(Research.sources) { source in
            if let url = URL(string: source.url) {
                Link(destination: url) {
                    Text(source.title)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
