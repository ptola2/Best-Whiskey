// Optional cloud backup. This file only compiles once the Firebase packages
// (FirebaseAuth, FirebaseFirestore) are added to the target. Without them the app
// runs fully offline. See README.md, "Turn on cloud backup".
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import Foundation
import Observation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@Observable
@MainActor
final class CloudSync {
    static let shared = CloudSync()

    private(set) var isAvailable = false
    private(set) var uid: String?
    private(set) var email: String?
    private(set) var message: String?

    @ObservationIgnored private var started = false
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var currentNonce: String?

    private init() {}

    /// Call once at launch, after FirebaseApp.configure().
    func start() {
        guard !started else { return }
        started = true
        isAvailable = FirebaseApp.app() != nil
        guard isAvailable else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let id = user?.uid
            let mail = user?.email
            Task { @MainActor in self?.authChanged(uid: id, email: mail) }
        }
    }

    // MARK: Sync

    private func document(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid).collection("waterline").document("state")
    }

    private func authChanged(uid newUID: String?, email newEmail: String?) {
        listener?.remove()
        listener = nil
        uid = newUID
        email = newEmail
        guard let newUID else { return }
        listener = document(newUID).addSnapshotListener { [weak self] snapshot, error in
            let failure = error?.localizedDescription
            let exists = snapshot?.exists ?? false
            let pending = snapshot?.metadata.hasPendingWrites ?? false
            let json = snapshot?.data()?["json"] as? String
            Task { @MainActor in
                self?.received(exists: exists, pending: pending, json: json, failure: failure)
            }
        }
    }

    private func received(exists: Bool, pending: Bool, json: String?, failure: String?) {
        if let failure {
            message = "Sync paused: \(failure)"
            return
        }
        if pending { return }
        let store = FastStore.shared
        guard exists, let json, let bytes = json.data(using: .utf8),
              let remote = try? JSONDecoder().decode(AppData.self, from: bytes) else {
            // Nothing in the cloud yet: upload what this iPhone has.
            if store.data.hasContent { push(store.data) }
            return
        }
        message = nil
        if !store.data.hasContent || remote.updatedAt > store.data.updatedAt.addingTimeInterval(0.5) {
            store.replaceAll(with: remote)
        } else if store.data.updatedAt > remote.updatedAt.addingTimeInterval(0.5) {
            push(store.data)
        }
    }

    /// Debounced upload so typing in a field does not write on every keystroke.
    func schedulePush(_ data: AppData) {
        guard uid != nil else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.push(data)
        }
    }

    func cancelPendingPush() {
        pushTask?.cancel()
        pushTask = nil
    }

    private func push(_ data: AppData) {
        guard let uid, let bytes = try? JSONEncoder().encode(data), let json = String(data: bytes, encoding: .utf8) else { return }
        let payload: [String: Any] = [
            "json": json,
            "updatedAt": data.updatedAt.timeIntervalSince1970,
            "version": data.version,
        ]
        document(uid).setData(payload) { [weak self] error in
            guard let error else { return }
            let text = error.localizedDescription
            Task { @MainActor in self?.message = "Could not back up: \(text)" }
        }
    }

    func deleteRemoteState() async {
        guard let uid else { return }
        try? await document(uid).delete()
    }

    // MARK: Sign in with Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                message = error.localizedDescription
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                message = "Sign in with Apple did not return a token. Try again."
                return
            }
            let firebaseCredential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: credential.fullName)
            do {
                _ = try await Auth.auth().signIn(with: firebaseCredential)
                message = nil
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func signOut() {
        cancelPendingPush()
        do {
            try Auth.auth().signOut()
        } catch {
            message = error.localizedDescription
        }
    }

    /// Deletes the cloud copy and the account. Data on this iPhone stays.
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        cancelPendingPush()
        do {
            try await document(user.uid).delete()
            try await user.delete()
            message = "Account deleted. Your data on this iPhone stays."
        } catch {
            message = "Could not delete the account: \(error.localizedDescription) Sign out, sign in again, then retry."
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int(generator.next() % UInt64(charset.count))] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
