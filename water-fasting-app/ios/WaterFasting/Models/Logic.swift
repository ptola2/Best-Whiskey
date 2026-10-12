import Foundation

// MARK: - Formatting

enum Fmt {
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    static func span(_ interval: TimeInterval) -> String {
        let mins = max(0, Int((interval / 60).rounded()))
        if mins >= 2880 { return tr("fmt.days_hours", mins / 1440, (mins % 1440) / 60) }
        let h = mins / 60, m = mins % 60
        return h > 0 ? tr("fmt.hours_minutes", h, m) : tr("fmt.minutes", m)
    }

    static func target(_ hours: Int) -> String {
        (hours <= 72 || hours % 24 != 0) ? tr("fmt.hours", hours) : trCount("count.days", hours / 24)
    }

    /// One decimal place with the person's own decimal separator (82.5 or 82,5).
    static func one(_ value: Double) -> String { String(format: "%.1f", locale: Locale.current, value) }

    static func two(_ value: Double) -> String { String(format: "%.2f", locale: Locale.current, value) }

    /// Whole numbers without a decimal point. Safe for any input: huge or non-finite values never reach Int().
    static func trimmed(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        if value == value.rounded(), let whole = safeInt(value) { return String(whole) }
        return one(value)
    }

    /// Int(x) traps outside Int's range, so every Double-to-Int conversion of user input goes through here.
    static func safeInt(_ value: Double) -> Int? {
        guard value.isFinite, abs(value) < 1e15 else { return nil }
        return Int(value.rounded())
    }

    static func roundTo10(_ value: Double) -> Int { (safeInt(value / 10) ?? 0) * 10 }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }

    static func when(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    static func day(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .omitted) }
}

// MARK: - Fast arithmetic

enum FastMath {
    static func phaseIndex(hours: Double) -> Int {
        Research.phases.lastIndex(where: { hours >= $0.from }) ?? 0
    }

    static func dayNumber(hours: Double) -> Int { Int(floor(max(hours, 0) / 24)) + 1 }

    static func durationClass(hours: Int) -> (name: String, note: String) {
        if hours < 24 { return (tr("duration.short.name"), tr("duration.short.note")) }
        if hours <= 72 { return (tr("duration.shortterm.name"), tr("duration.shortterm.note")) }
        if hours <= 504 { return (tr("duration.prolonged.name"), tr("duration.prolonged.note")) }
        return (tr("duration.extreme.name"), tr("duration.extreme.note"))
    }

    static func bmi(_ p: Profile) -> Double? {
        guard let h = p.heightCm, let w = p.weightKg, h > 0 else { return nil }
        return w / pow(h / 100, 2)
    }

    /// Refeed for at least half as long as the fast.
    static func refeedDays(hours: Double) -> Int { max(1, Int(ceil(hours / 24 / 2 - 1e-9))) }

    static func schedule(days n: Int) -> [[RefeedStage]] {
        if n <= 1 { return [[.juice, .fruitVeg]] }
        if n == 2 { return [[.juice], [.fruitVeg, .starch]] }
        let k1 = max(1, Int((Double(n) * 0.25).rounded()))
        let k2 = max(1, Int((Double(n) * 0.35).rounded()))
        return (0..<n).map { i -> [RefeedStage] in
            if i < k1 { return [.juice] }
            if i < k1 + k2 { return [.fruitVeg] }
            return [.starch]
        }
    }

    /// Resting energy (Mifflin-St Jeor) times 1.2 for a restful day.
    static func maintenance(_ p: Profile, weight: Double?) -> Int? {
        guard let h = p.heightCm, let a = p.age, let w = weight else { return nil }
        let sexTerm: Double
        switch p.sex {
        case .male: sexTerm = 5
        case .female: sexTerm = -161
        case .unspecified: sexTerm = -78
        }
        return Fmt.roundTo10((10 * w + 6.25 * h - 5 * Double(a) + sexTerm) * 1.2)
    }
}

// MARK: - Safety screen

struct Blocker: Identifiable {
    let id: String
    let title: String
    let why: String
}

struct ScreeningResult {
    var missing: Int
    var blockers: [Blocker]
    var cautions: [ScreenQuestion]
    var refeedFlags: [ScreenQuestion]
    var bmi: Double?
    var profileComplete: Bool
    var noLongFasts: Bool

    var complete: Bool { missing == 0 && profileComplete }
    var superviseAlways: Bool { cautions.contains { $0.needsSupervision } }
}

enum Screening {
    static func evaluate(_ d: AppData) -> ScreeningResult {
        let all = Research.absolute + Research.relative + Research.refeedRisk
        let missing = all.filter { d.screening[$0.id] == nil }.count
        let bmi = FastMath.bmi(d.profile)
        var blockers = Research.absolute
            .filter { d.screening[$0.id] == true }
            .map { Blocker(id: $0.id, title: $0.question, why: $0.why) }
        if let bmi, bmi < 18.5 {
            blockers.append(Blocker(id: "bmi", title: tr("blocker.bmi.title", Fmt.one(bmi)), why: tr("blocker.bmi.why")))
        }
        if let age = d.profile.age, age < 18 {
            blockers.append(Blocker(id: "minor", title: tr("blocker.minor.title"), why: tr("blocker.minor.why")))
        }
        let cautions = Research.relative.filter { d.screening[$0.id] == true }
        let flags = Research.refeedRisk.filter { d.screening[$0.id] == true }
        let profileComplete = d.profile.heightCm != nil && d.profile.weightKg != nil && d.profile.age != nil
        return ScreeningResult(missing: missing, blockers: blockers, cautions: cautions, refeedFlags: flags,
                               bmi: bmi, profileComplete: profileComplete, noLongFasts: d.screening["bone"] == true)
    }
}

// MARK: - Check-in grading

struct AssessContext {
    var isRefeed: Bool
    var start: Date?
    var startWeightKg: Double?
    var water: [String: Int]
}

enum Assessor {
    static func assess(_ c: CheckIn, _ ctx: AssessContext) -> (level: Level, notes: [Note]) {
        var notes: [Note] = []
        var level: Level = .ok
        func add(_ l: Level, _ text: String) {
            notes.append(Note(level: l, text: text))
            if l > level { level = l }
        }

        let sym = Set(c.symptoms)
        let stops = Research.symptoms.filter { $0.group == .stop && sym.contains($0.id) }
        if !stops.isEmpty {
            let list = trList(stops.map(\.label))
            let action = ctx.isRefeed ? tr("assess.action.refeed") : tr("assess.action.fast")
            add(.stop, tr("assess.warnings", list, action))
        }
        if sym.contains("joint") {
            add(.stop, tr("assess.joint"))
        }
        if sym.contains("dizzy") {
            add(.caution, tr("assess.dizzy"))
        }
        let lowSodiumCompanions = ["headache", "lethargy", "dizzy"].filter { sym.contains($0) }.count
        if sym.contains("cramps") && lowSodiumCompanions > 0 {
            add(.caution, tr("assess.sodium.likely"))
        } else if sym.contains("cramps") || sym.contains("lethargy") {
            add(.caution, tr("assess.sodium.possible"))
        }

        let v = c.vitals
        if let ls = v.lyingSystolic, let ss = v.standingSystolic {
            let dropSys = ls - ss
            var dropDia = 0
            if let ld = v.lyingDiastolic, let sd = v.standingDiastolic { dropDia = ld - sd }
            if dropSys >= 20 || dropDia >= 10 {
                add(.caution, tr("assess.bp_drop", dropSys, dropDia))
            }
        }
        if let lp = v.lyingPulse, let sp = v.standingPulse, sp - lp >= 30 {
            add(.caution, tr("assess.pulse_rise", sp - lp))
        }
        if let ls = v.lyingSystolic, ls < 90 {
            add(.caution, tr("assess.low_systolic", ls))
        }

        if let k = c.ketones {
            let ks = Fmt.trimmed(k)
            if k > 7 {
                add(.caution, tr("assess.bhb.high", ks))
            } else if k >= 2 {
                notes.append(Note(level: .ok, text: tr("assess.bhb.brain", ks)))
            } else {
                notes.append(Note(level: .ok, text: tr("assess.bhb.low", ks)))
            }
        }

        // Only judge yesterday's water when the fast covered all of yesterday. The day a fast starts is partial,
        // so an evening start with a few hundred mL logged is normal, not a shortfall.
        let calendar = Calendar.current
        if !ctx.isRefeed, let start = ctx.start, let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: c.at),
           start <= calendar.startOfDay(for: yesterdayDate) {
            let yesterday = Fmt.dayKey(yesterdayDate)
            if let ml = ctx.water[yesterday], ml > 0 {
                let litres = Fmt.two(Double(ml) / 1000)
                if ml < Research.waterMin {
                    add(.caution, tr("assess.water.low", litres))
                } else if ml > Research.waterMax {
                    add(.caution, tr("assess.water.high", litres))
                }
            }
        }

        if let w = c.weightKg, let sw = ctx.startWeightKg, sw - w > 0 {
            let d = sw - w
            notes.append(Note(level: .ok, text: tr("assess.weight_down", Fmt.one(d), Fmt.one(d / sw * 100))))
        }

        let hasCommon = Research.symptoms.contains { $0.group == .common && sym.contains($0.id) }
        if hasCommon && level == .ok {
            notes.append(Note(level: .ok, text: tr("assess.common")))
        }
        if notes.isEmpty {
            notes.append(Note(level: .ok, text: tr("assess.none")))
        }
        notes.sort { $0.level > $1.level }
        return (level, notes)
    }
}

// MARK: - Refeeding plan

struct RefeedPlan {
    let fastHours: Double
    let days: Int
    let tier: RefeedTier
    let reasons: [String]
    let calorieHeadline: String
    let calorieValue: String?
    let calorieBasis: String
    let schedule: [[RefeedStage]]
}

enum RefeedPlanner {
    static func build(fastHours: Double, data: AppData, weightKg: Double?) -> RefeedPlan {
        let days = FastMath.refeedDays(hours: fastHours)
        let fastDays = fastHours / 24
        let screening = Screening.evaluate(data)

        var high: [String] = []
        var mid: [String] = []
        if fastDays > 7 { high.append(tr("refeed.reason.long_fast")) }
        if let b = screening.bmi, b < 16 { high.append(tr("refeed.reason.bmi_under_16")) }
        for flag in screening.refeedFlags {
            high.append(flag.id == "wtloss" ? tr("refeed.reason.weight_loss") : tr("refeed.reason.electrolytes"))
        }
        if fastDays >= 5 && fastDays <= 7 { mid.append(tr("refeed.reason.fast_5_7")) }
        if let b = screening.bmi, b >= 16, b < 18.5 { mid.append(tr("refeed.reason.bmi_16_18")) }

        let tier: RefeedTier = !high.isEmpty ? .high : (!mid.isEmpty ? .moderate : .low)
        let reasons = !high.isEmpty ? high : mid
        let weight = weightKg ?? data.profile.weightKg

        var headline = ""
        var value: String?
        var basis = ""
        switch tier {
        case .low:
            headline = tr("kcal.low.headline")
            if let m = FastMath.maintenance(data.profile, weight: weight) {
                value = tr("kcal.range", Fmt.roundTo10(Double(m) * 0.5), Fmt.roundTo10(Double(m) * 0.7))
                basis = tr("kcal.low.basis", m)
            } else {
                basis = tr("kcal.low.missing")
            }
        case .moderate:
            headline = tr("kcal.moderate.headline")
            if let w = weight {
                value = tr("kcal.range", Fmt.roundTo10(w * 10), Fmt.roundTo10(w * 20))
                basis = tr("kcal.based_on_weight", Fmt.one(w))
            }
        case .high:
            headline = tr("kcal.high.headline")
            if let w = weight {
                value = tr("kcal.range", Fmt.roundTo10(w * 5), Fmt.roundTo10(w * 10))
                basis = tr("kcal.based_on_weight", Fmt.one(w))
            }
        }

        return RefeedPlan(fastHours: fastHours, days: days, tier: tier, reasons: reasons,
                          calorieHeadline: headline, calorieValue: value, calorieBasis: basis,
                          schedule: FastMath.schedule(days: days))
    }
}
