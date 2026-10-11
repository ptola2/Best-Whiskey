import SwiftUI

struct ProfileView: View {
    var body: some View {
        let screening = FastStore.shared.screening
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScreeningSummary(result: screening)
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
            .navigationTitle("Profile")
            .keyboardDoneButton()
        }
    }
}

private struct ScreeningSummary: View {
    let result: ScreeningResult

    var body: some View {
        if !result.complete {
            let what = result.profileComplete ? "\(Fmt.plural(result.missing, "question")) left" : "add your details below"
            Notice(tone: .info) {
                Text("Safety check: \(what).").bold()
                Para(text: "Your answers decide which fasts Waterline will help you plan.", font: .subheadline)
            }
        } else if !result.blockers.isEmpty {
            Notice(tone: .stop) {
                StatusPill(level: .stop, text: "Water fasting is not safe for you")
                Para(text: result.blockers.map(\.title).joined(separator: "; ") + ". Talk to your doctor about what is safe.", font: .subheadline)
            }
        } else if !result.cautions.isEmpty {
            Notice(tone: .caution) {
                StatusPill(level: .caution, text: "Doctor review needed")
                Para(text: result.cautions.map(\.question).joined(separator: "; ") + ".", font: .subheadline)
            }
        } else {
            Notice(tone: .ok) {
                StatusPill(level: .ok, text: "No red flags in your answers")
                Para(text: "That does not replace a check-up. Clinics still run blood tests, a urine test and an ECG before a fast.", font: .subheadline)
            }
        }
    }
}

private struct AboutYouCard: View {
    var body: some View {
        let store = FastStore.shared
        let bmi = FastMath.bmi(store.data.profile)
        Card {
            CardTitle(text: "About you", style: .title3)
            HStack(alignment: .top, spacing: 12) {
                NumberField(label: "Height", unit: "cm", value: Binding(
                    get: { store.data.profile.heightCm },
                    set: { value in store.update { d in d.profile.heightCm = value } }))
                NumberField(label: "Weight", unit: "kg", value: Binding(
                    get: { store.data.profile.weightKg },
                    set: { value in store.update { d in d.profile.weightKg = value } }))
            }
            HStack(alignment: .top, spacing: 12) {
                NumberField(label: "Age", unit: "years", value: Binding(
                    get: { store.data.profile.age.map { Double($0) } },
                    set: { value in store.update { d in d.profile.age = value.map { Int($0) } } }), decimals: false)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Sex, for calorie estimates").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
                    Picker("Sex", selection: Binding(
                        get: { store.data.profile.sex },
                        set: { value in store.update { d in d.profile.sex = value } })) {
                        Text("Prefer not to say").tag(Sex.unspecified)
                        Text("Female").tag(Sex.female)
                        Text("Male").tag(Sex.male)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let bmi {
                HStack(spacing: 10) {
                    Eyebrow(text: "BMI")
                    Text(Fmt.one(bmi)).font(.system(size: 26, weight: .medium, design: .monospaced)).foregroundStyle(Theme.ink)
                    if bmi < 16 {
                        StatusPill(level: .stop, text: "Under 16")
                    } else if bmi < 18.5 {
                        StatusPill(level: .stop, text: "Under 18.5")
                    } else {
                        StatusPill(level: .ok, text: "18.5 or above")
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
            CardTitle(text: "Safety check", style: .title3)
            QuestionGroup(title: "Do any of these apply to you?", hint: "Any yes rules out water fasting.", questions: Research.absolute, kind: .absolute)
            QuestionGroup(title: "Medicines and conditions", hint: "A yes means a doctor must be involved first.", questions: Research.relative, kind: .relative)
            QuestionGroup(title: "Refeeding risk", hint: "These raise the risk of problems when you start eating again.", questions: Research.refeedRisk, kind: .refeed)
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
                        Para(text: "\(question.why) \(question.action)", font: .footnote)
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
            CardTitle(text: "Your clinician", style: .title3)
            Para(text: "Shown on the Today screen during a fast, with a call button, so it is close at hand.", font: .footnote, color: Theme.muted)
            LabeledField(label: "Name", text: Binding(
                get: { store.data.clinician.name },
                set: { value in store.update { d in d.clinician.name = String(value.prefix(80)) } }))
                .textContentType(.name)
            LabeledField(label: "Phone", text: Binding(
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
                    Text("Reminders").font(.headline).foregroundStyle(Theme.ink)
                    Para(text: "Check-in prompts at 9:00 and 21:00 during a fast, plus alerts at 12 h, 36 h, 72 h, day 7 and your target.",
                         font: .footnote, color: Theme.muted)
                }
            }
            .tint(Theme.accent)
        }
    }
}

private struct DataCard: View {
    @State private var confirmDelete = false

    var body: some View {
        Card {
            CardTitle(text: "Your data", style: .title3)
            Para(text: "Everything is saved in a protected file on this iPhone. Nothing leaves the device unless you switch on cloud backup.",
                 font: .subheadline, color: Theme.ink2)
            Button("Delete all my data", role: .destructive) { confirmDelete = true }
                .buttonStyle(WLButtonStyle(kind: .danger))
                .confirmationDialog("Delete everything?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete all my data", role: .destructive) { FastStore.shared.deleteAll() }
                } message: {
                    Text("Your profile, answers, current fast and history will be gone for good.")
                }
        }
    }
}
