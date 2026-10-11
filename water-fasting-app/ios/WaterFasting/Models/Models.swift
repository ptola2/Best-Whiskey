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
        case .ok: return "No warning signs"
        case .caution: return "Caution"
        case .stop: return "Stop and get help"
        }
    }

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rank < rhs.rank }
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
        case .target: return "Reached target"
        case .symptoms: return "Ended early: symptoms"
        case .other: return "Ended early"
        }
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
}

enum Sex: String, Codable, CaseIterable {
    case unspecified, female, male
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
    }

    /// True once the person has entered anything worth keeping. Used so an empty install never overwrites a cloud copy.
    var hasContent: Bool {
        active != nil || refeed != nil || !history.isEmpty || profile.weightKg != nil || !screening.isEmpty
    }
}
