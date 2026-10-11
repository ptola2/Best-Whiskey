// Shown in Profile only when the Firebase packages are part of the build.
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import SwiftUI
import AuthenticationServices

struct CloudCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        let cloud = CloudSync.shared
        let who = cloud.email.map { " as \($0)" } ?? ""
        Card {
            CardTitle(text: "Backup and sync", style: .title3)
            if !cloud.isAvailable {
                Para(text: "Add GoogleService-Info.plist to the project to switch on cloud backup.", font: .footnote, color: Theme.muted)
            } else if cloud.uid != nil && cloud.confirmingDeletion {
                Para(text: "To delete your account, confirm with Apple. This removes your cloud copy, revokes Waterline's access to your Apple ID and deletes the account. Data on this iPhone stays.",
                     font: .subheadline)
                SignInWithAppleButton(.continue) { request in
                    cloud.prepare(request)
                } onCompletion: { result in
                    Task { await cloud.completeAccountDeletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .disabled(cloud.isBusy)
                Button("Cancel") { cloud.confirmingDeletion = false }
                    .buttonStyle(WLButtonStyle(kind: .quiet))
            } else if cloud.uid != nil {
                Para(text: "Signed in\(who). Your data backs up privately and syncs to your other devices.", font: .subheadline)
                HStack(spacing: 10) {
                    Button("Sign out") { confirmSignOut = true }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                        .buttonStyle(WLButtonStyle(kind: .danger))
                }
                .disabled(cloud.isBusy)
                .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                    Button("Sign out") { Task { await cloud.signOut() } }
                } message: {
                    Text("Your data stays in your account and is removed from this iPhone. Sign in again to get it back.")
                }
                .confirmationDialog("Delete your Waterline account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Continue", role: .destructive) { cloud.confirmingDeletion = true }
                } message: {
                    Text("You will confirm with Apple next. Your cloud copy is deleted. Data on this iPhone stays.")
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
            if cloud.isBusy {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            }
            if let message = cloud.message {
                Para(text: message, font: .footnote, color: Theme.muted)
            }
        }
    }
}
#endif
