// Shown in Profile only when the Firebase packages are part of the build.
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import SwiftUI
import AuthenticationServices

struct CloudCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmDelete = false

    var body: some View {
        let cloud = CloudSync.shared
        let who = cloud.email.map { " as \($0)" } ?? ""
        Card {
            CardTitle(text: "Backup and sync", style: .title3)
            if !cloud.isAvailable {
                Para(text: "Add GoogleService-Info.plist to the project to switch on cloud backup.", font: .footnote, color: Theme.muted)
            } else if cloud.uid != nil {
                Para(text: "Signed in\(who). Your data backs up privately and syncs to your other devices.", font: .subheadline)
                HStack(spacing: 10) {
                    Button("Sign out") { cloud.signOut() }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                        .buttonStyle(WLButtonStyle(kind: .danger))
                }
                .confirmationDialog("Delete your Waterline account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete account and cloud copy", role: .destructive) {
                        Task { await cloud.deleteAccount() }
                    }
                } message: {
                    Text("Your cloud copy is deleted. Data on this iPhone stays.")
                }
            } else {
                Para(text: "Optional. Sign in to back up your fasts and keep them if you reinstall the app or change phones.", font: .subheadline, color: Theme.ink2)
                SignInWithAppleButton(.signIn) { request in
                    cloud.prepare(request)
                } onCompletion: { result in
                    Task { await cloud.complete(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
            }
            if let message = cloud.message {
                Para(text: message, font: .footnote, color: Theme.muted)
            }
        }
    }
}
#endif
