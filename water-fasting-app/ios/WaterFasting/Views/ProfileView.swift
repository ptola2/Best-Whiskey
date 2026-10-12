import SwiftUI

struct ProfileView: View {
    var body: some View {
        let screening = FastStore.shared.screening
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScreeningSummary(result: screening)
                    LanguageCard()
                    AboutYouCard()
                    SafetyCheckCard()
                    ClinicianCard()
                    RemindersCard()
                    #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
                    CloudCard()
                    #endif
                    DataCard()
                    DisclaimerFooter()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(tr("tab.profile"))
            .languageToolbarButton()
            .keyboardDoneButton()
        }
    }
}

private struct ScreeningSummary: View {
    let result: ScreeningResult

    var body: some View {
        if !result.complete {
            let what = result.profileComplete ? trCount("count.questions_left", result.missing) : tr("profile.summary.add_details")
            Notice(tone: .info) {
                Text(tr("profile.summary.incomplete", what)).bold()
                Para(text: tr("profile.summary.incomplete.body"), font: .subheadline)
            }
        } else if !result.blockers.isEmpty {
            Notice(tone: .stop) {
                StatusPill(level: .stop, text: tr("blocked.title"))
                Para(text: tr("common.title_and_reason", trList(result.blockers.map(\.title)), tr("profile.summary.blocked.body")), font: .subheadline)
            }
        } else if !result.cautions.isEmpty {
            Notice(tone: .caution) {
                StatusPill(level: .caution, text: tr("profile.summary.doctor"))
                Para(text: trList(result.cautions.map(\.question)), font: .subheadline)
            }
        } else {
            Notice(tone: .ok) {
                StatusPill(level: .ok, text: tr("profile.summary.clear"))
                Para(text: tr("profile.summary.clear.body"), font: .subheadline)
            }
        }
    }
}

private struct AboutYouCard: View {
    /// Converts typed text safely: anything outside 1 to 130 (or too large for Int) is treated as not entered.
    static func age(from value: Double?) -> Int? {
        guard let value, let whole = Fmt.safeInt(value), (1...130).contains(whole) else { return nil }
        return whole
    }

    var body: some View {
        let store = FastStore.shared
        let bmi = FastMath.bmi(store.data.profile)
        Card {
            CardTitle(text: tr("profile.about.title"), style: .title3)
            HStack(alignment: .top, spacing: 12) {
                NumberField(label: tr("profile.height"), unit: tr("unit.cm"), value: Binding(
                    get: { store.data.profile.heightCm },
                    set: { value in store.update { d in d.profile.heightCm = value } }))
                NumberField(label: tr("profile.weight"), unit: tr("unit.kg"), value: Binding(
                    get: { store.data.profile.weightKg },
                    set: { value in store.update { d in d.profile.weightKg = value } }))
            }
            HStack(alignment: .top, spacing: 12) {
                NumberField(label: tr("profile.age"), unit: tr("unit.years"), value: Binding(
                    get: { store.data.profile.age.map { Double($0) } },
                    set: { value in store.update { d in d.profile.age = Self.age(from: value) } }), decimals: false)
                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("profile.sex")).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
                    Picker(tr("profile.sex"), selection: Binding(
                        get: { store.data.profile.sex },
                        set: { value in store.update { d in d.profile.sex = value } })) {
                        Text(tr("profile.sex.unspecified")).tag(Sex.unspecified)
                        Text(tr("profile.sex.female")).tag(Sex.female)
                        Text(tr("profile.sex.male")).tag(Sex.male)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let bmi {
                HStack(spacing: 10) {
                    Eyebrow(text: tr("profile.bmi"))
                    Text(Fmt.one(bmi)).font(.system(size: 26, weight: .medium, design: .monospaced)).foregroundStyle(Theme.ink)
                    if bmi < 16 {
                        StatusPill(level: .stop, text: tr("profile.bmi.under16"))
                    } else if bmi < 18.5 {
                        StatusPill(level: .stop, text: tr("profile.bmi.under18"))
                    } else {
                        StatusPill(level: .ok, text: tr("profile.bmi.ok"))
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct SafetyCheckCard: View {
    var body: some View {
        Card {
            CardTitle(text: tr("profile.safety.title"), style: .title3)
            QuestionGroup(title: tr("profile.safety.absolute"), hint: tr("profile.safety.absolute.hint"), questions: Research.absolute, kind: .absolute)
            QuestionGroup(title: tr("profile.safety.relative"), hint: tr("profile.safety.relative.hint"), questions: Research.relative, kind: .relative)
            QuestionGroup(title: tr("profile.safety.refeed"), hint: tr("profile.safety.refeed.hint"), questions: Research.refeedRisk, kind: .refeed)
        }
    }
}

private enum QuestionKind {
    case absolute, relative, refeed
}

private struct QuestionGroup: View {
    let title: String
    let hint: String
    let questions: [ScreenQuestion]
    let kind: QuestionKind

    var body: some View {
        let answers = FastStore.shared.data.screening
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).padding(.top, 8)
            Para(text: hint, font: .footnote, color: Theme.muted).padding(.bottom, 4)
            ForEach(questions) { question in
                let value = answers[question.id]
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Para(text: question.question, font: .subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        YesNoControl(value: value) { yes in
                            FastStore.shared.answer(question.id, yes: yes)
                        }
                        .accessibilityLabel(question.question)
                    }
                    if value == true && kind == .absolute {
                        Para(text: question.why, font: .footnote)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.stopSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    if value == true && kind == .relative {
                        Para(text: question.why + " " + question.action, font: .footnote)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.warnSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
        }
    }
}

private struct ClinicianCard: View {
    var body: some View {
        let store = FastStore.shared
        Card {
            CardTitle(text: tr("profile.clinician.title"), style: .title3)
            Para(text: tr("profile.clinician.body"), font: .footnote, color: Theme.muted)
            LabeledField(label: tr("profile.clinician.name"), text: Binding(
                get: { store.data.clinician.name },
                set: { value in store.update { d in d.clinician.name = String(value.prefix(80)) } }))
                .textContentType(.name)
            LabeledField(label: tr("profile.clinician.phone"), text: Binding(
                get: { store.data.clinician.phone },
                set: { value in store.update { d in d.clinician.phone = String(value.prefix(40)) } }))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        }
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
            TextField("", text: $text)
                .padding(10)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.line, lineWidth: 1))
                .accessibilityLabel(label)
        }
    }
}

private struct RemindersCard: View {
    var body: some View {
        let store = FastStore.shared
        Card {
            Toggle(isOn: Binding(get: { store.data.remindersOn }, set: { store.setReminders($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("profile.reminders.title")).font(.headline).foregroundStyle(Theme.ink)
                    Para(text: tr("profile.reminders.body"), font: .footnote, color: Theme.muted)
                }
            }
            .tint(Theme.accent)
        }
    }
}

private struct DataCard: View {
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        Card {
            CardTitle(text: tr("profile.data.title"), style: .title3)
            Para(text: tr("profile.data.body"), font: .subheadline, color: Theme.ink2)
            Link(destination: AppLinks.privacyPolicy) {
                Label(tr("common.privacy_policy"), systemImage: "hand.raised")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
            Button(tr("profile.data.delete"), role: .destructive) { confirmDelete = true }
                .buttonStyle(WLButtonStyle(kind: .danger))
                .disabled(deleting)
                .confirmationDialog(tr("profile.data.delete_confirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(tr("profile.data.delete"), role: .destructive) { delete() }
                    Button(tr("common.cancel"), role: .cancel) {}
                } message: {
                    Text(tr("profile.data.delete_message"))
                }
            if deleting {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            }
            if let deleteError {
                Para(text: deleteError, font: .footnote.weight(.semibold), color: Theme.stop)
            }
        }
    }

    private func delete() {
        deleting = true
        deleteError = nil
        Task {
            deleteError = await FastStore.shared.deleteAll()
            deleting = false
        }
    }
}
