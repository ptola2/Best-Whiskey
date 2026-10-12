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
        let signedIn = cloud.email.map { tr("cloud.signed_in_as", $0) } ?? tr("cloud.signed_in")
        Card {
            CardTitle(text: tr("cloud.title"), style: .title3)
            if !cloud.isAvailable {
                Para(text: tr("cloud.not_configured"), font: .footnote, color: Theme.muted)
            } else if cloud.uid != nil && cloud.confirmingDeletion {
                Para(text: tr("cloud.delete.confirm_with_apple"), font: .subheadline)
                SignInWithAppleButton(.continue) { request in
                    cloud.prepare(request)
                } onCompletion: { result in
                    Task { await cloud.completeAccountDeletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .disabled(cloud.isBusy)
                Button(tr("common.cancel")) { cloud.confirmingDeletion = false }
                    .buttonStyle(WLButtonStyle(kind: .quiet))
            } else if cloud.uid != nil {
                Para(text: signedIn, font: .subheadline)
                HStack(spacing: 10) {
                    Button(tr("cloud.sign_out")) { confirmSignOut = true }
                        .buttonStyle(WLButtonStyle(kind: .secondary))
                    Button(tr("cloud.delete_account"), role: .destructive) { confirmDelete = true }
                        .buttonStyle(WLButtonStyle(kind: .danger))
                }
                .disabled(cloud.isBusy)
                .confirmationDialog(tr("cloud.sign_out.confirm"), isPresented: $confirmSignOut, titleVisibility: .visible) {
                    Button(tr("cloud.sign_out")) { Task { await cloud.signOut() } }
                    Button(tr("common.cancel"), role: .cancel) {}
                } message: {
                    Text(tr("cloud.sign_out.message"))
                }
                .confirmationDialog(tr("cloud.delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(tr("common.continue"), role: .destructive) { cloud.confirmingDeletion = true }
                    Button(tr("common.cancel"), role: .cancel) {}
                } message: {
                    Text(tr("cloud.delete.message"))
                }
            } else {
                Para(text: tr("cloud.intro"), font: .subheadline, color: Theme.ink2)
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
