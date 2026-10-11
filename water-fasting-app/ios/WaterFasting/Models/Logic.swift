import Foundation

// MARK: - Formatting

enum Fmt {
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    static func span(_ interval: TimeInterval) -> String {
        let mins = max(0, Int((interval / 60).rounded()))
        if mins >= 2880 { return "\(mins / 1440) d \((mins % 1440) / 60) h" }
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h) h \(m) m" : "\(m) m"
    }

    static func target(_ hours: Int) -> String {
        (hours <= 72 || hours % 24 != 0) ? "\(hours) h" : "\(hours / 24) days"
    }

    static func one(_ value: Double) -> String { String(format: "%.1f", value) }

    /// Whole numbers without a decimal point. Safe for any input: huge or non-finite values never reach Int().
    static func trimmed(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        if value == value.rounded(), let whole = safeInt(value) { return String(whole) }
        return String(format: "%.1f", value)
    }

    /// Int(x) traps outside Int's range, so every Double-to-Int conversion of user input goes through here.
    static func safeInt(_ value: Double) -> Int? {
        guard value.isFinite, abs(value) < 1e15 else { return nil }
        return Int(value.rounded())
    }

    static func roundTo10(_ value: Double) -> Int { (safeInt(value / 10) ?? 0) * 10 }

    static func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

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
        if hours < 24 { return ("Short fast", "Under 24 hours.") }
        if hours <= 72 { return ("Short-term fast", "24 to 72 hours. Glycogen runs out and early ketosis begins.") }
        if hours <= 504 { return ("Prolonged fast", "4 to 21 days of sustained ketosis. Research on fasts this long comes from supervised clinics with twice-daily checks and weekly blood tests.") }
        return ("Extreme fast", "Over 21 days. Lean tissue loss, micronutrient depletion and heart strain become major concerns.")
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
            blockers.append(Blocker(id: "bmi", title: "BMI of \(Fmt.one(bmi)) (under 18.5)",
                                    why: "Without enough fat and protein reserves, fasting can waste heart muscle and cause dangerous heart rhythms."))
        }
        if let age = d.profile.age, age < 18 {
            blockers.append(Blocker(id: "minor", title: "Under 18", why: "The research covers adults only."))
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
            let list = stops.map { $0.label.lowercased() }.joined(separator: "; ")
            let action = ctx.isRefeed
                ? "Contact your clinician now. These can be signs of refeeding syndrome or refeeding swelling."
                : "End the fast and contact your clinician now."
            add(.stop, "Warning sign\(stops.count > 1 ? "s" : ""): \(list). \(action) If it feels severe, call your local emergency number.")
        }
        if sym.contains("joint") {
            add(.stop, "A hot, swollen joint during a fast is often gout: ketones block uric acid clearance. An acute flare is a reason to end the fast.")
        }
        if sym.contains("dizzy") {
            add(.caution, "Lightheadedness on standing is common on days 2 to 5 as blood volume drops. Get up slowly and rest. If you faint or nearly faint, stop the fast.")
        }
        let lowSodiumCompanions = ["headache", "lethargy", "dizzy"].filter { sym.contains($0) }.count
        if sym.contains("cramps") && lowSodiumCompanions > 0 {
            add(.caution, "Cramps with headache, sluggishness or dizziness can point to low sodium (below 136 mmol/L). Only a blood test can tell. Let your clinician know.")
        } else if sym.contains("cramps") || sym.contains("lethargy") {
            add(.caution, "Cramps or heavy drowsiness can be early signs of low sodium. Mention it to your clinician and keep watching.")
        }

        let v = c.vitals
        if let ls = v.lyingSystolic, let ss = v.standingSystolic {
            let dropSys = ls - ss
            var dropDia = 0
            if let ld = v.lyingDiastolic, let sd = v.standingDiastolic { dropDia = ld - sd }
            if dropSys >= 20 || dropDia >= 10 {
                add(.caution, "Blood pressure fell \(dropSys)/\(dropDia) mmHg when you stood up. A drop of 20/10 or more counts as orthostatic hypotension. Share it with your clinician and avoid sudden position changes.")
            }
        }
        if let lp = v.lyingPulse, let sp = v.standingPulse, sp - lp >= 30 {
            add(.caution, "Your pulse rose \(sp - lp) beats a minute on standing, a sign of low blood volume.")
        }
        if let ls = v.lyingSystolic, ls < 90 {
            add(.caution, "A lying systolic pressure of \(ls) mmHg is low. Rest and tell your clinician.")
        }

        if let k = c.ketones {
            let ks = Fmt.trimmed(k)
            if k > 7 {
                add(.caution, "BHB of \(ks) mmol/L is above the 3.0 to 7.0 range usually seen by days 5 to 10. Share the reading with your clinician.")
            } else if k >= 2 {
                notes.append(Note(level: .ok, text: "BHB of \(ks) mmol/L: above 2.0, ketones are reaching the brain and covering much of its fuel."))
            } else {
                notes.append(Note(level: .ok, text: "BHB of \(ks) mmol/L. Ketones start reaching the brain in quantity above 2.0 mmol/L."))
            }
        }

        // Only judge yesterday's water when the fast covered all of yesterday. The day a fast starts is partial,
        // so an evening start with a few hundred mL logged is normal, not a shortfall.
        let calendar = Calendar.current
        if !ctx.isRefeed, let start = ctx.start, let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: c.at),
           start <= calendar.startOfDay(for: yesterdayDate) {
            let yesterday = Fmt.dayKey(yesterdayDate)
            if let ml = ctx.water[yesterday], ml > 0 {
                let litres = String(format: "%.2f", Double(ml) / 1000)
                if ml < Research.waterMin {
                    add(.caution, "Yesterday you logged \(litres) L of water, under the 1.2 L minimum.")
                } else if ml > Research.waterMax {
                    add(.caution, "Yesterday you logged \(litres) L of water, above the usual 1.2 to 2.5 L. Large amounts of plain water can lower blood sodium.")
                }
            }
        }

        if let w = c.weightKg, let sw = ctx.startWeightKg, sw - w > 0 {
            let d = sw - w
            notes.append(Note(level: .ok, text: "Down \(Fmt.one(d)) kg (\(Fmt.one(d / sw * 100))%) since the start. Early loss is mostly water and glycogen, which come back when you eat."))
        }

        let hasCommon = Research.symptoms.contains { $0.group == .common && sym.contains($0.id) }
        if hasCommon && level == .ok {
            notes.append(Note(level: .ok, text: "Common, mostly mild side effects. In 768 supervised fasts, 90% of people had at least one by day 5."))
        }
        if notes.isEmpty {
            notes.append(Note(level: .ok, text: "No warning signs in this check-in."))
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
        if fastDays > 7 { high.append("fast longer than 7 days") }
        if let b = screening.bmi, b < 16 { high.append("BMI under 16") }
        for flag in screening.refeedFlags {
            high.append(flag.id == "wtloss" ? "recent unintended weight loss" : "low electrolytes")
        }
        if fastDays >= 5 && fastDays <= 7 { mid.append("fast of 5 to 7 days") }
        if let b = screening.bmi, b >= 16, b < 18.5 { mid.append("BMI 16 to 18.5") }

        let tier: RefeedTier = !high.isEmpty ? .high : (!mid.isEmpty ? .moderate : .low)
        let reasons = !high.isEmpty ? high : mid
        let weight = weightKg ?? data.profile.weightKg

        var headline = ""
        var value: String?
        var basis = ""
        switch tier {
        case .low:
            headline = "Start at 50 to 70% of your usual needs."
            if let m = FastMath.maintenance(data.profile, weight: weight) {
                value = "About \(Fmt.roundTo10(Double(m) * 0.5)) to \(Fmt.roundTo10(Double(m) * 0.7)) kcal a day"
                basis = "Estimated from about \(m) kcal a day for a restful day (Mifflin-St Jeor x 1.2)."
            } else {
                basis = "Add height, weight and age in Profile for a personal estimate."
            }
        case .moderate:
            headline = "Start low, around 10 to 20 kcal per kg a day (the ASPEN starting range), and build up across 4 to 7 days."
            if let w = weight {
                value = "About \(Fmt.roundTo10(w * 10)) to \(Fmt.roundTo10(w * 20)) kcal a day"
                basis = "Based on \(Fmt.one(w)) kg."
            }
        case .high:
            headline = "Limit to 5 to 10 kcal per kg a day and advance gradually, under medical care."
            if let w = weight {
                value = "About \(Fmt.roundTo10(w * 5)) to \(Fmt.roundTo10(w * 10)) kcal a day"
                basis = "Based on \(Fmt.one(w)) kg."
            }
        }

        return RefeedPlan(fastHours: fastHours, days: days, tier: tier, reasons: reasons,
                          calorieHeadline: headline, calorieValue: value, calorieBasis: basis,
                          schedule: FastMath.schedule(days: days))
    }
}
