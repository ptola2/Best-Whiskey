// Optional cloud backup. This file only compiles once the Firebase packages
// (FirebaseAuth, FirebaseFirestore) are added to the target. Without them the app
// runs fully offline. See README.md, "Turn on cloud backup".
//
// How sync stays safe:
// - The cloud document carries a server revision number. A write only lands if the server is still at
//   the revision this iPhone last saw (a Firestore transaction), so device clocks never decide who wins.
// - When both sides changed, the copies are merged (SyncMerge) instead of one overwriting the other.
// - Only server-confirmed snapshots are acted on; cached snapshots are ignored.
// - A copy this version cannot read pauses sync instead of being overwritten.
// - "Delete all my data" writes a new generation, which replaces older copies on every device.
// - Local data remembers which account it belongs to and is never pushed into a different account.
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import Foundation
import Observation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

/// Sync bookkeeping kept on this device only.
private struct SyncState: Codable {
    /// The account the local data is linked to. Nil until the first successful sync.
    var ownerUID: String?
    /// Server revision the local data was last in step with.
    var baseRevision = 0
    /// Local changes not yet confirmed by the server.
    var dirty = false
}

private struct RemoteCopy: Sendable {
    let exists: Bool
    let json: String?
    let revision: Int
    let schema: Int
}

@Observable
@MainActor
final class CloudSync {
    static let shared = CloudSync()
    static let schemaVersion = 1

    private(set) var isAvailable = false
    private(set) var uid: String?
    private(set) var email: String?
    private(set) var message: String?
    private(set) var isBusy = false
    /// True while the account deletion step is waiting for the person to confirm with Apple.
    var confirmingDeletion = false

    @ObservationIgnored private var started = false
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var pushing = false
    @ObservationIgnored private var changeCounter = 0
    @ObservationIgnored private var paused = false
    @ObservationIgnored private var currentNonce: String?
    @ObservationIgnored private var sync: SyncState
    private let syncURL: URL

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Waterline", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sync.json")
        syncURL = url
        if let bytes = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(SyncState.self, from: bytes) {
            sync = saved
        } else {
            sync = SyncState()
        }
    }

    private func saveSyncState() {
        if let bytes = try? JSONEncoder().encode(sync) {
            try? bytes.write(to: syncURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

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

    private func document(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid).collection("waterline").document("state")
    }

    private func authChanged(uid newUID: String?, email newEmail: String?) {
        listener?.remove()
        listener = nil
        uid = newUID
        email = newEmail
        paused = false
        guard let newUID else { return }
        listener = document(newUID).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            let failure = error?.localizedDescription
            let fromCache = snapshot?.metadata.isFromCache ?? true
            let pending = snapshot?.metadata.hasPendingWrites ?? false
            let fields = snapshot?.data()
            let remote = RemoteCopy(
                exists: snapshot?.exists ?? false,
                json: fields?["json"] as? String,
                revision: (fields?["revision"] as? NSNumber)?.intValue ?? 0,
                schema: (fields?["schema"] as? NSNumber)?.intValue ?? 1
            )
            Task { @MainActor in
                self?.received(remote, fromCache: fromCache, pending: pending, failure: failure)
            }
        }
    }

    // MARK: Incoming

    private func decode(_ remote: RemoteCopy) -> AppData? {
        guard remote.schema <= Self.schemaVersion, let json = remote.json, let bytes = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: bytes)
    }

    private func received(_ remote: RemoteCopy, fromCache: Bool, pending: Bool, failure: String?) {
        if let failure {
            message = "Sync paused: \(failure)"
            return
        }
        // Cached snapshots can be stale; wait for the server.
        guard !fromCache, !pending, let uid else { return }
        let store = FastStore.shared

        let decoded = remote.exists ? decode(remote) : nil
        if remote.exists && decoded == nil {
            paused = true
            message = "Your cloud copy was saved by a newer version of Waterline. Update the app to keep syncing. Nothing was overwritten."
            return
        }

        // Local data linked to a different account is replaced, never merged or uploaded.
        if let owner = sync.ownerUID, owner != uid {
            var adopted = decoded ?? AppData()
            adopted.onboarded = true
            store.replaceAll(with: adopted)
            sync = SyncState(ownerUID: uid, baseRevision: remote.exists ? remote.revision : 0, dirty: false)
            saveSyncState()
            message = "Data from a different account was removed from this iPhone."
            return
        }

        guard let remoteData = decoded else {
            if sync.ownerUID == uid && sync.baseRevision > 0 {
                // The cloud copy was removed elsewhere (account deleted). Keep local data and stop syncing.
                paused = true
                sync = SyncState()
                saveSyncState()
                message = "Your cloud copy was removed. Data on this iPhone stays. Sign out and back in to start a new backup."
                return
            }
            // First link to an empty account: upload what this iPhone has.
            sync.ownerUID = uid
            sync.baseRevision = 0
            saveSyncState()
            if store.data.hasContent {
                sync.dirty = true
                saveSyncState()
                pushNow()
            }
            return
        }

        paused = false
        message = nil
        let local = store.data

        if sync.ownerUID == nil {
            // First link on this iPhone: anything entered before signing in is merged in, never discarded.
            if local.hasContent {
                store.replaceAll(with: SyncMerge.merge(local: local, remote: remoteData))
                sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: true)
                saveSyncState()
                pushNow()
            } else {
                store.replaceAll(with: remoteData)
                sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: false)
                saveSyncState()
            }
            return
        }
        if remoteData.generation > local.generation {
            // A deletion (or a newer generation) from another device replaces everything here.
            store.replaceAll(with: remoteData)
            sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: false)
            saveSyncState()
            return
        }
        if remoteData.generation < local.generation {
            sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: true)
            saveSyncState()
            pushNow()
            return
        }
        if remote.revision == sync.baseRevision {
            if sync.dirty { pushNow() }
            return
        }
        // The server moved on. Take its copy if nothing changed here; otherwise merge both.
        if !sync.dirty || !local.hasContent {
            store.replaceAll(with: remoteData)
            sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: false)
            saveSyncState()
        } else {
            store.replaceAll(with: SyncMerge.merge(local: local, remote: remoteData))
            sync = SyncState(ownerUID: uid, baseRevision: remote.revision, dirty: true)
            saveSyncState()
            pushNow()
        }
    }

    // MARK: Outgoing

    /// Called by FastStore after every local change.
    func localChanged() {
        changeCounter += 1
        sync.dirty = true
        saveSyncState()
        schedulePush()
    }

    /// Debounced so typing in a field does not write on every keystroke.
    private func schedulePush() {
        guard uid != nil, !paused else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    private func pushNow() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in await self?.push() }
    }

    private func push() async {
        guard let uid, !paused, sync.dirty, !pushing, sync.ownerUID == nil || sync.ownerUID == uid else { return }
        pushing = true
        defer { pushing = false }
        let startedAt = changeCounter
        guard let bytes = try? JSONEncoder().encode(FastStore.shared.data), let json = String(data: bytes, encoding: .utf8) else { return }
        do {
            guard let newRevision = try await write(uid: uid, base: sync.baseRevision, json: json, force: false) else {
                // The server moved on; the snapshot listener delivers the newer copy and merges.
                return
            }
            sync.ownerUID = uid
            sync.baseRevision = newRevision
            if changeCounter == startedAt { sync.dirty = false }
            saveSyncState()
            message = nil
            if sync.dirty { schedulePush() }
        } catch {
            message = "Could not back up: \(error.localizedDescription)"
        }
    }

    /// Writes `json` as the next revision. Without `force`, only succeeds if the server is still at `base`;
    /// returns nil on a conflict. A document that vanished after this iPhone synced counts as a conflict too,
    /// so a deleted account is never re-created.
    private func write(uid: String, base: Int, json: String, force: Bool) async throws -> Int? {
        let ref = document(uid)
        let schema = Self.schemaVersion
        let result = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            let current = (snapshot.data()?["revision"] as? NSNumber)?.intValue ?? 0
            if !force {
                let moved = snapshot.exists ? current != base : base != 0
                if moved { return NSNumber(value: -1) }
            }
            let next = current + 1
            transaction.setData([
                "json": json,
                "revision": next,
                "schema": schema,
                "updatedAt": FieldValue.serverTimestamp(),
            ], forDocument: ref)
            return NSNumber(value: next)
        }
        let value = (result as? NSNumber)?.intValue ?? -1
        return value > 0 ? value : nil
    }

    /// Used by "Delete all my data": writes the wiped copy so every signed-in device clears too.
    /// Returns an error message if the write failed, in which case nothing should be deleted.
    func publishWipe(_ wiped: AppData) async -> String? {
        guard let uid, sync.ownerUID == nil || sync.ownerUID == uid else { return nil }
        guard let bytes = try? JSONEncoder().encode(wiped), let json = String(data: bytes, encoding: .utf8) else {
            return "Could not prepare the deletion. Nothing was deleted."
        }
        pushTask?.cancel()
        isBusy = true
        defer { isBusy = false }
        do {
            let revision = try await write(uid: uid, base: sync.baseRevision, json: json, force: true)
            changeCounter += 1
            sync = SyncState(ownerUID: uid, baseRevision: revision ?? sync.baseRevision, dirty: false)
            saveSyncState()
            return nil
        } catch {
            return "Could not delete your cloud copy (\(error.localizedDescription)). Nothing was deleted. Check your connection and try again."
        }
    }

    // MARK: Sign in with Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    private struct AppleProof {
        let idToken: String
        let nonce: String
        let authorizationCode: String?
        let fullName: PersonNameComponents?
    }

    private func proof(from result: Result<ASAuthorization, Error>) -> AppleProof? {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                message = error.localizedDescription
            }
            return nil
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                message = "Sign in with Apple did not return a token. Try again."
                return nil
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            return AppleProof(idToken: token, nonce: nonce, authorizationCode: code, fullName: credential.fullName)
        }
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        guard let proof = proof(from: result) else { return }
        let credential = OAuthProvider.appleCredential(withIDToken: proof.idToken, rawNonce: proof.nonce, fullName: proof.fullName)
        do {
            _ = try await Auth.auth().signIn(with: credential)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    /// Backs up anything pending, then signs out and clears this account's data from the iPhone so it can
    /// never be uploaded into a different account. The cloud copy stays in the account.
    func signOut() async {
        isBusy = true
        defer { isBusy = false }
        if sync.dirty && FastStore.shared.data.hasContent {
            if paused {
                message = "Some changes are not backed up, so you are still signed in. Update the app, then try again."
                return
            }
            await push()
            if sync.dirty {
                message = "Some changes are not backed up yet, so you are still signed in. Check your connection and try again."
                return
            }
        }
        do {
            try Auth.auth().signOut()
        } catch {
            message = error.localizedDescription
            return
        }
        pushTask?.cancel()
        sync = SyncState()
        saveSyncState()
        FastStore.shared.resetAfterSignOut()
        message = "Signed out. Your data stays in your account."
    }

    /// Account deletion needs a fresh Sign in with Apple confirmation: it re-authenticates, revokes the
    /// Apple token (App Review guideline 5.1.1(v)), deletes the cloud copy, then deletes the account.
    func completeAccountDeletion(_ result: Result<ASAuthorization, Error>) async {
        guard let proof = proof(from: result) else { return }
        guard let user = Auth.auth().currentUser else {
            confirmingDeletion = false
            return
        }
        guard let code = proof.authorizationCode else {
            message = "Apple did not return an authorization code. Try again."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let credential = OAuthProvider.appleCredential(withIDToken: proof.idToken, rawNonce: proof.nonce, fullName: proof.fullName)
            _ = try await user.reauthenticate(with: credential)
            try await Auth.auth().revokeToken(withAuthorizationCode: code)
            pushTask?.cancel()
            listener?.remove()
            listener = nil
            try await document(user.uid).delete()
            try await user.delete()
            sync = SyncState()
            saveSyncState()
            confirmingDeletion = false
            message = "Account deleted. Your data on this iPhone stays."
        } catch {
            message = "Could not delete the account: \(error.localizedDescription)"
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
