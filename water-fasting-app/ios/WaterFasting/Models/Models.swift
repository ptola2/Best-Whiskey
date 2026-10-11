import Foundation

/// How serious a check-in or finding is. Ordered so `max()` gives the worst.
enum Level: String, Codable, CaseIterable, Comparable {
    case ok, caution, stop

    var rank: Int {
        switch self {
        case .ok: return 0
        case .caution: return 1
        case .stop: return 2
        }
    }

    var label: String {
        switch self {
        case .ok: return tr("level.ok")
        case .caution: return tr("level.caution")
        case .stop: return tr("level.stop")
        }
    }

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rank < rhs.rank }

    /// Unknown values (written by a newer app version) read as caution rather than failing the whole decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Level(rawValue: raw) ?? .caution
    }
}

struct Note: Codable, Hashable {
    var level: Level
    var text: String
}

struct Vitals: Codable, Hashable {
    var lyingSystolic: Int?
    var lyingDiastolic: Int?
    var lyingPulse: Int?
    var standingSystolic: Int?
    var standingDiastolic: Int?
    var standingPulse: Int?

    var isEmpty: Bool {
        [lyingSystolic, lyingDiastolic, lyingPulse, standingSystolic, standingDiastolic, standingPulse].allSatisfy { $0 == nil }
    }
}

struct CheckIn: Codable, Hashable, Identifiable {
    var id = UUID()
    var at: Date
    var weightKg: Double?
    var ketones: Double?
    var vitals = Vitals()
    var symptoms: [String] = []
    var note = ""
    var level: Level = .ok
    var notes: [Note] = []
}

struct ActiveFast: Codable, Hashable {
    var id: UUID
    var startedAt: Date
    var targetHours: Int
    var supervised: Bool
    var startWeightKg: Double?
    /// Millilitres of water per local calendar day, keyed "yyyy-MM-dd".
    var waterByDay: [String: Int]
    var checkIns: [CheckIn]
}

struct RefeedState: Codable, Hashable {
    var fastId: UUID
    var fastHours: Double
    var startedAt: Date
    var days: Int
    var endWeightKg: Double?
    var checkIns: [CheckIn]
}

enum EndReason: String, Codable, CaseIterable {
    case target, symptoms, other

    var label: String {
        switch self {
        case .target: return tr("end_reason.target")
        case .symptoms: return tr("end_reason.symptoms")
        case .other: return tr("end_reason.other")
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = EndReason(rawValue: raw) ?? .other
    }
}

struct PastFast: Codable, Hashable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var hours: Double
    var targetHours: Int
    var startWeightKg: Double?
    var endWeightKg: Double?
    var checkInCount: Int
    var worst: Level
    var reason: EndReason
    /// Set when the refeed that followed this fast was marked complete.
    var refeedCompleted: Bool?
}

enum Sex: String, Codable, CaseIterable {
    case unspecified, female, male

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Sex(rawValue: raw) ?? .unspecified
    }
}

struct Profile: Codable, Hashable {
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var sex: Sex = .unspecified
}

struct Clinician: Codable, Hashable {
    var name = ""
    var phone = ""
}

/// Everything the app stores. Saved as one JSON document on the device and, when signed in, in Firestore.
struct AppData: Codable, Hashable {
    var version = 1
    var onboarded = false
    var profile = Profile()
    /// Safety question id -> answer. A missing key means unanswered.
    var screening: [String: Bool] = [:]
    var clinician = Clinician()
    var remindersOn = true
    var active: ActiveFast?
    var refeed: RefeedState?
    var history: [PastFast] = []
    var updatedAt = Date(timeIntervalSince1970: 0)
    /// Raised by "Delete all my data". A copy with a higher generation replaces older copies outright, so a deletion
    /// reaches every device instead of being merged away.
    var generation = 0
    /// Check-ins the person removed, so a sync merge does not bring them back.
    var removedCheckIns: [UUID] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? Profile()
        screening = try c.decodeIfPresent([String: Bool].self, forKey: .screening) ?? [:]
        clinician = try c.decodeIfPresent(Clinician.self, forKey: .clinician) ?? Clinician()
        remindersOn = try c.decodeIfPresent(Bool.self, forKey: .remindersOn) ?? true
        active = try c.decodeIfPresent(ActiveFast.self, forKey: .active)
        refeed = try c.decodeIfPresent(RefeedState.self, forKey: .refeed)
        history = try c.decodeIfPresent([PastFast].self, forKey: .history) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
        generation = try c.decodeIfPresent(Int.self, forKey: .generation) ?? 0
        removedCheckIns = try c.decodeIfPresent([UUID].self, forKey: .removedCheckIns) ?? []
    }

    /// True once the person has entered anything worth keeping. Used so an empty install never overwrites a cloud copy.
    var hasContent: Bool {
        active != nil || refeed != nil || !history.isEmpty || profile.weightKg != nil || !screening.isEmpty
    }
}
