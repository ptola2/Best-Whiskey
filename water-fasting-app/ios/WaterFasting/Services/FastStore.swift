import Foundation
import Observation

/// Single source of truth for the app. Saves to a protected JSON file on the device
/// (offline cache) and, when cloud backup is switched on, to Firestore through CloudSync.
@Observable
@MainActor
final class FastStore {
    static let shared = FastStore()

    var data: AppData
    var tab: AppTab = .today
    /// The check-in whose result is shown at the top of the Log tab.
    var lastResultID: UUID?

    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Waterline", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("data.json")
        fileURL = url

        if let bytes = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(AppData.self, from: bytes) {
            data = decoded
        } else {
            if fm.fileExists(atPath: url.path) {
                // Keep an unreadable file aside rather than overwrite it.
                let aside = dir.appendingPathComponent("data-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? fm.moveItem(at: url, to: aside)
            }
            data = AppData()
        }
    }

    var screening: ScreeningResult { Screening.evaluate(data) }

    // MARK: Persistence

    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        persist()
    }

    /// Replaces local data with a copy from the cloud without pushing it back, and brings reminders in line
    /// with whatever fast that copy has running.
    func replaceAll(with remote: AppData) {
        let before = data
        data = remote
        persist(touch: false, push: false)
        let a = before.active, b = remote.active
        if a?.id != b?.id || a?.startedAt != b?.startedAt || a?.targetHours != b?.targetHours
            || a?.supervised != b?.supervised || before.remindersOn != remote.remindersOn {
            refreshReminders()
        }
    }

    private func persist(touch: Bool = true, push: Bool = true) {
        if touch { data.updatedAt = Date() }
        if let bytes = try? JSONEncoder().encode(data) {
            try? bytes.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if push { CloudSync.shared.localChanged() }
        #endif
    }

    // MARK: Actions

    func completeOnboarding() {
        update { $0.onboarded = true }
        tab = .today
    }

    func answer(_ questionID: String, yes: Bool) {
        update { $0.screening[questionID] = yes }
    }

    func startFast(targetHours: Int, supervised: Bool, start: Date) {
        let fast = ActiveFast(id: UUID(), startedAt: start, targetHours: targetHours, supervised: supervised,
                              startWeightKg: data.profile.weightKg, waterByDay: [:], checkIns: [])
        update { d in
            d.active = fast
            d.refeed = nil
        }
        lastResultID = nil
        refreshReminders()
    }

    /// Records that a clinician is supervising the running fast (needed once it passes 72 hours).
    func markSupervised() {
        update { $0.active?.supervised = true }
        refreshReminders()
    }

    func waterToday() -> Int {
        data.active?.waterByDay[Fmt.dayKey(Date())] ?? 0
    }

    func addWater(_ ml: Int) {
        guard data.active != nil else { return }
        let key = Fmt.dayKey(Date())
        update { d in
            let current = d.active?.waterByDay[key] ?? 0
            d.active?.waterByDay[key] = min(max(0, current + ml), 8000)
        }
    }

    @discardableResult
    func addCheckIn(_ input: CheckIn) -> CheckIn {
        var c = input
        if let fast = data.active {
            let ctx = AssessContext(isRefeed: false, start: fast.startedAt, startWeightKg: fast.startWeightKg, water: fast.waterByDay)
            let result = Assessor.assess(c, ctx)
            c.level = result.level
            c.notes = result.notes
            let saved = c
            update { d in
                d.active?.checkIns.append(saved)
                if d.active?.startWeightKg == nil, let w = saved.weightKg { d.active?.startWeightKg = w }
            }
        } else if data.refeed != nil {
            let result = Assessor.assess(c, AssessContext(isRefeed: true, start: nil, startWeightKg: nil, water: [:]))
            c.level = result.level
            c.notes = result.notes
            let saved = c
            update { d in d.refeed?.checkIns.append(saved) }
        }
        lastResultID = c.id
        return c
    }

    func removeCheckIn(_ id: UUID) {
        update { d in
            d.active?.checkIns.removeAll { $0.id == id }
            d.refeed?.checkIns.removeAll { $0.id == id }
            d.removedCheckIns.append(id)
            if d.removedCheckIns.count > 500 { d.removedCheckIns.removeFirst(d.removedCheckIns.count - 500) }
        }
        if lastResultID == id { lastResultID = nil }
    }

    func endFast(_ reason: EndReason) {
        guard let a = data.active else { return }
        let end = Date()
        let hours = end.timeIntervalSince(a.startedAt) / 3600
        let endWeight = a.checkIns.last(where: { $0.weightKg != nil })?.weightKg
        let worst = a.checkIns.map(\.level).max() ?? .ok
        let past = PastFast(id: a.id, startedAt: a.startedAt, endedAt: end, hours: hours, targetHours: a.targetHours,
                            startWeightKg: a.startWeightKg, endWeightKg: endWeight, checkInCount: a.checkIns.count,
                            worst: worst, reason: reason)
        let refeed: RefeedState? = hours >= 24
            ? RefeedState(fastId: a.id, fastHours: hours, startedAt: end, days: FastMath.refeedDays(hours: hours),
                          endWeightKg: endWeight, checkIns: [])
            : nil
        update { d in
            d.history.insert(past, at: 0)
            if d.history.count > 60 { d.history = Array(d.history.prefix(60)) }
            d.active = nil
            d.refeed = refeed
        }
        NotificationService.shared.cancelAll()
        lastResultID = nil
        tab = refeed != nil ? .refeed : .today
    }

    func finishRefeed() {
        let fastID = data.refeed?.fastId
        update { d in
            if let fastID, let index = d.history.firstIndex(where: { $0.id == fastID }) {
                d.history[index].refeedCompleted = true
            }
            d.refeed = nil
        }
        lastResultID = nil
        tab = .today
    }

    func setReminders(_ on: Bool) {
        update { $0.remindersOn = on }
        refreshReminders()
    }

    /// Schedules (or clears) reminders for the running fast. Called on changes and whenever the app comes
    /// forward, so the rolling window of check-in prompts keeps going for as long as the fast runs.
    func refreshReminders() {
        if data.remindersOn, let a = data.active {
            Task { await NotificationService.shared.scheduleFast(start: a.startedAt, targetHours: a.targetHours, supervised: a.supervised) }
        } else {
            NotificationService.shared.cancelAll()
        }
    }

    /// Removes everything. When cloud backup is on, the deletion is written to the cloud first, so other
    /// devices clear too; if that write fails nothing is deleted and the error is returned.
    func deleteAll() async -> String? {
        var wiped = AppData()
        wiped.generation = data.generation + 1
        wiped.updatedAt = Date()
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if let failure = await CloudSync.shared.publishWipe(wiped) { return failure }
        #endif
        NotificationService.shared.cancelAll()
        data = wiped
        persist(touch: false, push: false)
        lastResultID = nil
        tab = .today
        return nil
    }

    /// Clears this iPhone after signing out. The account's copy in the cloud is untouched.
    func resetAfterSignOut() {
        NotificationService.shared.cancelAll()
        var fresh = AppData()
        fresh.onboarded = true
        data = fresh
        persist(touch: false, push: false)
        lastResultID = nil
        tab = .today
    }
}
