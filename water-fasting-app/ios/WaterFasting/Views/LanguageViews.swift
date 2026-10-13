import SwiftUI

extension View {
    /// Applies the language chosen in Waterline: text direction (Arabic reads right to left) and the locale that
    /// date pickers and other system controls use.
    func appLanguageEnvironment() -> some View {
        modifier(AppLanguageEnvironment())
    }
}

private struct AppLanguageEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        let language = AppLanguage.shared
        content
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

/// First launch: pick a language before anything else. It starts on the suggested language, and every tap
/// switches the screen at once, so people can see the app in a language before they commit to it.
struct LanguageWelcomeView: View {
    var body: some View {
        let language = AppLanguage.shared
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    BrandMark()
                        .frame(width: 44, height: 44)
                    Text(verbatim: "Waterline")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("language.choose"))
                        .font(Theme.display(.largeTitle))
                        .foregroundStyle(Theme.ink)
                    Para(text: tr("language.subtitle"), font: .subheadline, color: Theme.muted)
                }
                LanguageList(includeSystem: false)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                language.confirm()
            } label: {
                HStack(spacing: 8) {
                    Text(AppLanguage.flag(for: language.current))
                    Text(tr("common.continue"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WLButtonStyle(kind: .primary))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .screenBackground()
        .onAppear { language.applySuggestion() }
    }
}

/// The languages with flags. Tapping a row switches the app straight away.
struct LanguageList: View {
    /// Profile and the welcome screen offer "Same as iPhone". The first-launch screen preselects a language instead.
    var includeSystem = true

    var body: some View {
        let language = AppLanguage.shared
        let suggested = AppLanguage.suggestions
        let others = AppLanguage.options.filter { !suggested.contains($0.code) }
        VStack(alignment: .leading, spacing: 20) {
            if includeSystem {
                LanguageGroup {
                    LanguageRow(title: tr("language.system"),
                                subtitle: AppLanguage.option(AppLanguage.systemCode).nativeName,
                                selected: language.choice == nil) {
                        choose(nil)
                    } icon: {
                        Image(systemName: "iphone")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: tr("language.suggested"))
                LanguageGroup {
                    rows(suggested.map(AppLanguage.option))
                }
                Para(text: tr("language.basis"), font: .footnote, color: Theme.muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: tr("language.all"))
                LanguageGroup {
                    rows(others)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: language.code)
    }

    @ViewBuilder
    private func rows(_ items: [LanguageOption]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, option in
            if index > 0 {
                Divider().padding(.leading, 70)
            }
            optionRow(option)
        }
    }

    private func optionRow(_ option: LanguageOption) -> some View {
        let language = AppLanguage.shared
        // With a "Same as iPhone" row, only an explicit choice is ticked. Without one, the language on screen is.
        let selected = includeSystem ? language.choice == option.code : language.code == option.code
        let localized = language.localizedName(of: option.code)
        let subtitle = localized.isEmpty || localized.localizedCaseInsensitiveCompare(option.nativeName) == .orderedSame
            ? nil : localized
        return LanguageRow(title: option.nativeName, subtitle: subtitle, selected: selected) {
            if includeSystem {
                choose(option.code)
            } else {
                // First launch: picking the iPhone's own language stores no override.
                choose(option.code == AppLanguage.systemCode ? nil : option.code)
            }
        } icon: {
            Text(AppLanguage.flag(for: option))
                .font(.system(size: 26))
        }
    }

    private func choose(_ code: String?) {
        AppLanguage.shared.select(code)
        // Scheduled reminders, the widget and the Live Activity hold their text, so they are rewritten in the new language.
        FastStore.shared.refreshReminders()
        WidgetBridge.refresh()
    }
}

private struct LanguageGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

private struct LanguageRow<Icon: View>: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon
                    .frame(width: 42, height: 42)
                    .background(Theme.surface2, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.line)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accentSoft : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    /// Adds a flag to the navigation bar that opens the language list, so the language is always one tap away.
    func languageToolbarButton() -> some View {
        modifier(LanguageToolbarButton())
    }
}

private struct LanguageToolbarButton: ViewModifier {
    @State private var showPicker = false

    func body(content: Content) -> some View {
        let language = AppLanguage.shared
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Text(AppLanguage.flag(for: language.current))
                            .font(.title3)
                    }
                    .accessibilityLabel(tr("language.title"))
                    .accessibilityValue(language.current.nativeName)
                }
            }
            .sheet(isPresented: $showPicker) { LanguageSheet() }
    }
}

/// The full list in a sheet, used from Profile, Today and the welcome screen.
struct LanguageSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LanguageList(includeSystem: true)
                    .padding(16)
            }
            .screenBackground()
            .navigationTitle(tr("language.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("common.done")) { dismiss() }
                }
            }
        }
        .appLanguageEnvironment()
        .presentationDragIndicator(.visible)
    }
}

/// A small flag button that opens the language list. Sits at the top of the welcome screen.
struct LanguageChip: View {
    @State private var showPicker = false

    var body: some View {
        let language = AppLanguage.shared
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(AppLanguage.flag(for: language.current))
                Text(language.current.nativeName)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("language.title"))
        .accessibilityValue(language.current.nativeName)
        .sheet(isPresented: $showPicker) { LanguageSheet() }
    }
}

/// The Language card in Profile.
struct LanguageCard: View {
    @State private var showPicker = false

    var body: some View {
        let language = AppLanguage.shared
        Card {
            CardTitle(text: tr("language.title"), style: .title3)
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 12) {
                    Text(AppLanguage.flag(for: language.current))
                        .font(.system(size: 24))
                        .frame(width: 40, height: 40)
                        .background(Theme.surface2, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.current.nativeName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if language.choice == nil {
                            Text(tr("language.system"))
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("language.title"))
            .accessibilityValue(language.current.nativeName)
        }
        .sheet(isPresented: $showPicker) { LanguageSheet() }
    }
}
