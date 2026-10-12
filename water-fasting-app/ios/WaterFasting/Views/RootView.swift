import SwiftUI

enum AppScreen {
    case language, welcome, main
}

enum AppTab: Hashable {
    case today, log, refeed, learn, profile
}

/// Top-level flow: language on first launch, then welcome until onboarded, then the tab bar.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let store = FastStore.shared
        let screen: AppScreen = store.data.onboarded ? .main : (AppLanguage.shared.confirmed ? .welcome : .language)
        ZStack {
            switch screen {
            case .language:
                LanguageWelcomeView()
                    .transition(.opacity)
            case .welcome:
                WelcomeView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .appLanguageEnvironment()
        .onChange(of: scenePhase) { _, phase in
            // Renews the rolling window of check-in reminders while a fast runs.
            if phase == .active { FastStore.shared.refreshReminders() }
        }
        .task {
            #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
            CloudSync.shared.start()
            #endif
        }
    }
}

struct MainTabView: View {
    var body: some View {
        let store = FastStore.shared
        TabView(selection: Binding(get: { store.tab }, set: { store.tab = $0 })) {
            TodayView()
                .tabItem { Label(tr("tab.today"), systemImage: "drop") }
                .tag(AppTab.today)
            LogView()
                .tabItem { Label(tr("tab.log"), systemImage: "list.clipboard") }
                .tag(AppTab.log)
            RefeedView()
                .tabItem { Label(tr("tab.refeed"), systemImage: "fork.knife") }
                .tag(AppTab.refeed)
            LearnView()
                .tabItem { Label(tr("tab.learn"), systemImage: "book") }
                .tag(AppTab.learn)
            ProfileView()
                .tabItem { Label(tr("tab.profile"), systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    BrandMark()
                        .frame(width: 64, height: 64)
                    Spacer(minLength: 12)
                    LanguageChip()
                }
                .padding(.top, 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Waterline")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text(tr("welcome.tagline"))
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 16) {
                    WelcomeRow(symbol: "timer", title: tr("welcome.timer.title"), text: tr("welcome.timer.body"))
                    WelcomeRow(symbol: "heart.text.square", title: tr("welcome.warnings.title"), text: tr("welcome.warnings.body"))
                    WelcomeRow(symbol: "fork.knife", title: tr("welcome.refeed.title"), text: tr("welcome.refeed.body"))
                }
                Notice(tone: .caution) {
                    Text(tr("welcome.disclaimer.title")).bold()
                    Para(text: tr("welcome.disclaimer.body"), font: .subheadline)
                }
                Button {
                    FastStore.shared.completeOnboarding()
                } label: {
                    Text(tr("welcome.start")).frame(maxWidth: .infinity)
                }
                .buttonStyle(WLButtonStyle(kind: .primary))
                Link(destination: AppLinks.privacyPolicy) {
                    Label(tr("common.privacy_policy"), systemImage: "hand.raised")
                        .font(.footnote.weight(.semibold))
                }
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .screenBackground()
    }
}

private struct WelcomeRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Para(text: text, font: .subheadline, color: Theme.ink2)
            }
        }
    }
}
