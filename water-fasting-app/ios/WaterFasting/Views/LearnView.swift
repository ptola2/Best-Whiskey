import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        Eyebrow(text: tr("learn.eyebrow"))
                        CardTitle(text: tr("learn.title"))
                        Para(text: tr("learn.intro"))
                    }
                    LearnSection(title: tr("learn.section.types"), startsOpen: true) { ProtocolsContent() }
                    LearnSection(title: tr("learn.section.hours")) { PhasesContent() }
                    LearnSection(title: tr("learn.section.studies")) { StudiesContent() }
                    LearnSection(title: tr("learn.section.risks")) { RisksContent() }
                    LearnSection(title: tr("learn.section.refeeding")) { RefeedingContent() }
                    LearnSection(title: tr("learn.section.who")) { ContraindicationsContent() }
                    LearnSection(title: tr("learn.section.sources")) { SourcesContent() }
                    DisclaimerFooter()
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle(tr("tab.learn"))
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
                        .frame(width: 84, alignment: .leading)
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
                (tr("learn.label.calories"), item.calories),
                (tr("learn.label.allowed"), item.allowed),
                (tr("learn.label.length"), item.length),
                (tr("learn.label.setting"), item.setting),
            ])
        }
        Para(text: tr("learn.types.durations"), font: .footnote, color: Theme.muted)
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
                    Text(phase.range).font(.caption.weight(.medium).monospacedDigit()).foregroundStyle(Theme.muted)
                    Text(phase.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Para(text: phase.text, font: .footnote, color: Theme.ink2)
                }
            }
        }
        Text(tr("learn.hormones.title")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).padding(.top, 6)
        ForEach(Research.hormones) { row in
            InfoBlock(title: row.marker, lines: [
                (tr("learn.label.change"), row.change),
                (tr("learn.label.why"), row.why),
                (tr("learn.label.effect"), row.effect),
            ])
        }
        Para(text: tr("learn.autophagy"), font: .footnote, color: Theme.ink2)
    }
}

private struct StudiesContent: View {
    var body: some View {
        ForEach(Research.studies) { study in
            VStack(alignment: .leading, spacing: 3) {
                Text(study.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(study.cohort).font(.caption.weight(.medium)).foregroundStyle(Theme.muted)
                Para(text: study.finding, font: .footnote, color: Theme.ink2)
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            StatTile(value: Fmt.one(0.9) + "-" + Fmt.one(1.5), caption: tr("learn.stat.early_loss"))
            StatTile(value: Fmt.two(0.25) + "-" + Fmt.two(0.40), caption: tr("learn.stat.later_loss"))
            StatTile(value: "~2/3", caption: tr("learn.stat.lean_mass"))
        }
        Para(text: tr("learn.bp_why"), font: .footnote, color: Theme.ink2)
        Para(text: tr("learn.benefits_fade"), font: .footnote, color: Theme.ink2)
    }
}

private struct RisksContent: View {
    var body: some View {
        Para(text: tr("learn.risks.intro"), font: .subheadline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            StatTile(value: 90.formatted(.percent.locale(AppLanguage.shared.locale)), caption: tr("learn.stat.any_effect"))
            StatTile(value: "20/28/32", caption: tr("learn.stat.grade3"))
            StatTile(value: "1 / 0", caption: tr("learn.stat.serious"))
        }
        Para(text: tr("learn.risks.common"), font: .footnote, color: Theme.ink2)
        ForEach(Research.complications) { item in
            InfoBlock(title: item.name, lines: [
                (tr("learn.label.onset"), item.onset),
                (tr("learn.label.cause"), item.cause),
                (tr("learn.label.signs"), item.signs),
                (tr("learn.label.clinics"), item.response),
            ])
        }
        Para(text: tr("learn.risks.electrolytes"), font: .footnote, color: Theme.ink2)
    }
}

private struct RefeedingContent: View {
    var body: some View {
        Para(text: tr("learn.refeeding.mechanism"), font: .footnote, color: Theme.ink2)
        Para(text: tr("learn.refeeding.edema"), font: .footnote, color: Theme.ink2)
        InfoBlock(title: tr("learn.refeeding.aspen.title"), lines: [
            (tr("learn.refeeding.aspen.mild"), tr("learn.refeeding.aspen.mild_value")),
            (tr("learn.refeeding.aspen.moderate"), tr("learn.refeeding.aspen.moderate_value")),
            (tr("learn.refeeding.aspen.severe"), tr("learn.refeeding.aspen.severe_value")),
        ])
        Para(text: tr("learn.refeeding.higher_risk"), font: .footnote, color: Theme.ink2)
        Para(text: tr("learn.refeeding.rule"), font: .footnote, color: Theme.ink2)
    }
}

private struct ContraindicationsContent: View {
    var body: some View {
        Text(tr("learn.who.absolute")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
        NoteList(notes: Research.absolute.map { Note(level: .stop, text: tr("common.title_and_reason", $0.question, $0.why)) }
                 + [Note(level: .stop, text: tr("learn.who.bmi"))])
        Text(tr("learn.who.relative")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).padding(.top, 6)
        NoteList(notes: Research.relative.map { Note(level: .caution, text: tr("common.title_and_reason", $0.question, $0.why)) })
    }
}

private struct SourcesContent: View {
    var body: some View {
        Para(text: tr("learn.sources.note"), font: .footnote, color: Theme.muted)
        ForEach(Research.sources) { source in
            if let url = URL(string: source.url) {
                Link(destination: url) {
                    Text(source.title)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}
