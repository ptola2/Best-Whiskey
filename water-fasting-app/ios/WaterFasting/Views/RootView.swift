import SwiftUI

enum AppScreen {
    case welcome, main
}

enum AppTab: Hashable {
    case today, log, refeed, learn, profile
}

/// Top-level flow: welcome until onboarded, then the tab bar.
struct RootView: View {
    var body: some View {
        let store = FastStore.shared
        let screen: AppScreen = store.data.onboarded ? .main : .welcome
        ZStack {
            if screen == .welcome {
                WelcomeView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
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
                .tabItem { Label("Today", systemImage: "drop") }
                .tag(AppTab.today)
            LogView()
                .tabItem { Label("Log", systemImage: "list.clipboard") }
                .tag(AppTab.log)
            RefeedView()
                .tabItem { Label("Refeed", systemImage: "fork.knife") }
                .tag(AppTab.refeed)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book") }
                .tag(AppTab.learn)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandMark()
                    .frame(width: 64, height: 64)
                    .padding(.top, 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Waterline")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("Water fasting, by the evidence")
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 16) {
                    WelcomeRow(symbol: "timer", title: "Know where you are",
                               text: "A live timer shows each metabolic phase, from glycogen running out to the 72-hour threshold.")
                    WelcomeRow(symbol: "heart.text.square", title: "Catch warning signs early",
                               text: "Check-ins grade blood pressure, ketones and symptoms against the clinical research.")
                    WelcomeRow(symbol: "fork.knife", title: "Break the fast safely",
                               text: "A refeeding plan sized to your fast, using the ASPEN and NICE risk levels.")
                }
                Notice(tone: .caution) {
                    Text("Not medical advice").bold()
                    Para(text: "Waterline is an educational tool. The research it draws on restricts fasts longer than 72 hours to medically supervised settings.", font: .subheadline)
                }
                Button {
                    FastStore.shared.completeOnboarding()
                } label: {
                    Text("Get started").frame(maxWidth: .infinity)
                }
                .buttonStyle(WLButtonStyle(kind: .primary))
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
