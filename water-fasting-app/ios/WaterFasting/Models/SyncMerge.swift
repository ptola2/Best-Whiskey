import Foundation

/// Combines two copies of the app data that both changed since they last matched (two devices editing
/// between syncs). Nothing is dropped silently: check-ins and past fasts are united by id, removals and
/// completed refeeds are respected, and this device's settings win where only one value can stay.
/// Copies from different generations are never merged; the higher generation replaces the other.
enum SyncMerge {
    static func merge(local: AppData, remote: AppData) -> AppData {
        var out = remote
        out.onboarded = local.onboarded || remote.onboarded
        out.profile = Profile(
            heightCm: local.profile.heightCm ?? remote.profile.heightCm,
            weightKg: local.profile.weightKg ?? remote.profile.weightKg,
            age: local.profile.age ?? remote.profile.age,
            sex: local.profile.sex != .unspecified ? local.profile.sex : remote.profile.sex
        )
        out.screening = remote.screening.merging(local.screening) { _, mine in mine }
        out.clinician = Clinician(
            name: local.clinician.name.isEmpty ? remote.clinician.name : local.clinician.name,
            phone: local.clinician.phone.isEmpty ? remote.clinician.phone : local.clinician.phone
        )
        out.remindersOn = local.remindersOn

        var removedList = remote.removedCheckIns
        for id in local.removedCheckIns where !removedList.contains(id) { removedList.append(id) }
        out.removedCheckIns = Array(removedList.suffix(500))
        let removed = Set(removedList)

        var pastByID: [UUID: PastFast] = [:]
        for fast in remote.history + local.history {
            if var existing = pastByID[fast.id] {
                if fast.refeedCompleted == true { existing.refeedCompleted = true }
                pastByID[fast.id] = existing
            } else {
                pastByID[fast.id] = fast
            }
        }
        out.history = Array(pastByID.values.sorted { $0.endedAt > $1.endedAt }.prefix(60))

        let endedFasts = Set(out.history.map(\.id))
        let finishedRefeeds = Set(out.history.filter { $0.refeedCompleted == true }.map(\.id))

        out.active = mergeActive([local.active, remote.active].compactMap { $0 }.filter { !endedFasts.contains($0.id) }, removed: removed)
        out.refeed = mergeRefeed([local.refeed, remote.refeed].compactMap { $0 }.filter { !finishedRefeeds.contains($0.fastId) }, removed: removed)
        if let active = out.active, let refeed = out.refeed, refeed.startedAt < active.startedAt {
            out.refeed = nil
        }
        out.generation = max(local.generation, remote.generation)
        out.updatedAt = Date()
        return out
    }

    static func mergeCheckIns(_ first: [CheckIn], _ second: [CheckIn], removed: Set<UUID>) -> [CheckIn] {
        var seen = Set<UUID>()
        var out: [CheckIn] = []
        for checkIn in first + second where !removed.contains(checkIn.id) && !seen.contains(checkIn.id) {
            seen.insert(checkIn.id)
            out.append(checkIn)
        }
        return out.sorted { $0.at < $1.at }
    }

    /// `fasts` lists this device's copy first.
    private static func mergeActive(_ fasts: [ActiveFast], removed: Set<UUID>) -> ActiveFast? {
        guard var mine = fasts.first else { return nil }
        if fasts.count > 1 {
            let theirs = fasts[1]
            if mine.id == theirs.id {
                mine.checkIns = mergeCheckIns(mine.checkIns, theirs.checkIns, removed: removed)
                mine.waterByDay = mine.waterByDay.merging(theirs.waterByDay) { max($0, $1) }
                mine.startWeightKg = mine.startWeightKg ?? theirs.startWeightKg
                mine.supervised = mine.supervised || theirs.supervised
                return mine
            }
            if theirs.startedAt > mine.startedAt { mine = theirs }
        }
        mine.checkIns = mine.checkIns.filter { !removed.contains($0.id) }
        return mine
    }

    /// `refeeds` lists this device's copy first.
    private static func mergeRefeed(_ refeeds: [RefeedState], removed: Set<UUID>) -> RefeedState? {
        guard var mine = refeeds.first else { return nil }
        if refeeds.count > 1 {
            let theirs = refeeds[1]
            if mine.fastId == theirs.fastId {
                mine.checkIns = mergeCheckIns(mine.checkIns, theirs.checkIns, removed: removed)
                return mine
            }
            if theirs.startedAt > mine.startedAt { mine = theirs }
        }
        mine.checkIns = mine.checkIns.filter { !removed.contains($0.id) }
        return mine
    }
}
