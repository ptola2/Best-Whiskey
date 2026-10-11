import Foundation

// Content taken from "Clinical Physiology, Therapeutic Applications, and Safety Profiles of
// Prolonged Water-Only Fasting". Keep wording plain; numbers must match the source.

struct Phase: Identifiable {
    let id: Int
    let from: Double
    let to: Double
    let name: String
    let range: String
    let text: String
}

struct RiskWindow: Identifiable {
    let id: String
    let name: String
    let fromDay: Int
    let toDay: Int
    let signs: String
    let action: String
}

enum SymptomGroup {
    case common, watch, stop
}

struct Symptom: Identifiable {
    let id: String
    let label: String
    let group: SymptomGroup
}

struct ScreenQuestion: Identifiable {
    let id: String
    let question: String
    let why: String
    var action: String = ""
    var needsSupervision: Bool = false
}

enum RefeedStage: String, CaseIterable {
    case juice, fruitVeg, starch

    var title: String { tr("stage.\(rawValue).title") }
    var text: String { tr("stage.\(rawValue).text") }
}

enum RefeedTier: String {
    case low, moderate, high

    var label: String { tr("tier.\(rawValue).label") }
    var criteria: String { tr("tier.\(rawValue).criteria") }
    var fluids: String { tr("tier.\(rawValue).fluids") }
    var monitoring: String { tr("tier.\(rawValue).monitoring") }

    var level: Level {
        switch self {
        case .low: return .ok
        case .moderate: return .caution
        case .high: return .stop
        }
    }
}

struct FastingProtocol: Identifiable {
    var id: String { name }
    let name: String
    let calories: String
    let allowed: String
    let length: String
    let setting: String
}

struct HormoneRow: Identifiable {
    var id: String { marker }
    let marker: String
    let change: String
    let why: String
    let effect: String
}

struct Study: Identifiable {
    var id: String { name }
    let name: String
    let cohort: String
    let finding: String
}

struct Complication: Identifiable {
    var id: String { name }
    let name: String
    let onset: String
    let cause: String
    let signs: String
    let response: String
}

struct Source: Identifiable {
    var id: String { url }
    let title: String
    let url: String
}

/// Every text here is a translation key; the words live in Localizable.xcstrings.
enum Research {
    static let waterMin = 1200
    static let waterMax = 2500
    static let waterScale = 3000
    static let targets = [24, 36, 48, 72, 120, 168, 240, 336, 504]

    private static let phaseHours: [(from: Double, to: Double)] = [
        (0, 12), (12, 36), (36, 72), (72, 96), (96, 168), (168, 240), (240, 504), (504, .infinity),
    ]

    static var phases: [Phase] {
        phaseHours.enumerated().map { index, hours in
            Phase(id: index, from: hours.from, to: hours.to,
                  name: tr("phase.\(index).name"), range: tr("phase.\(index).range"), text: tr("phase.\(index).text"))
        }
    }

    private static let riskDays: [(id: String, from: Int, to: Int)] = [
        ("ortho", 2, 5), ("hypona", 3, 8), ("acid", 3, 10), ("gout", 4, 12), ("bone", 15, 9999),
    ]

    static var risks: [RiskWindow] {
        riskDays.map { r in
            RiskWindow(id: r.id, name: tr("risk.\(r.id).name"), fromDay: r.from, toDay: r.to,
                       signs: tr("risk.\(r.id).signs"), action: tr("risk.\(r.id).action"))
        }
    }

    private static let symptomGroups: [(id: String, group: SymptomGroup)] = [
        ("fatigue", .common), ("headache", .common), ("nausea", .common), ("insomnia", .common),
        ("drymouth", .common), ("dyspepsia", .common), ("backpain", .common),
        ("dizzy", .watch), ("cramps", .watch), ("lethargy", .watch),
        ("faint", .stop), ("chest", .stop), ("confusion", .stop), ("vomit", .stop),
        ("joint", .stop), ("breathing", .stop), ("swelling", .stop), ("breathless", .stop),
    ]

    static var symptoms: [Symptom] {
        symptomGroups.map { Symptom(id: $0.id, label: tr("symptom.\($0.id)"), group: $0.group) }
    }

    static var absolute: [ScreenQuestion] {
        ["t1d", "preg", "ed", "ckd", "liver", "porph", "cachexia"].map { id in
            ScreenQuestion(id: id, question: tr("screen.\(id).question"), why: tr("screen.\(id).why"))
        }
    }

    static var relative: [ScreenQuestion] {
        let supervised: Set<String> = ["diuretic", "t2d"]
        return ["diuretic", "t2d", "bpmeds", "lithium", "gout", "bone", "heart"].map { id in
            ScreenQuestion(id: id, question: tr("screen.\(id).question"), why: tr("screen.\(id).why"),
                           action: tr("screen.\(id).action"), needsSupervision: supervised.contains(id))
        }
    }

    static var refeedRisk: [ScreenQuestion] {
        ["wtloss", "lytes"].map { ScreenQuestion(id: $0, question: tr("screen.\($0).question"), why: "") }
    }

    static var protocols: [FastingProtocol] {
        ["water", "buchinger", "fmd", "adf", "tre"].map { id in
            FastingProtocol(name: tr("protocol.\(id).name"), calories: tr("protocol.\(id).calories"),
                            allowed: tr("protocol.\(id).allowed"), length: tr("protocol.\(id).length"),
                            setting: tr("protocol.\(id).setting"))
        }
    }

    static var hormones: [HormoneRow] {
        ["insulin", "bhb", "gh", "igf1", "cortisol", "ft3", "mtor", "uric"].map { id in
            HormoneRow(marker: tr("hormone.\(id).marker"), change: tr("hormone.\(id).change"),
                       why: tr("hormone.\(id).why"), effect: tr("hormone.\(id).effect"))
        }
    }

    /// Study names are author citations and stay as published.
    private static let studyNames: [(id: String, name: String)] = [
        ("goldhamer", "Goldhamer et al., 2001"),
        ("dai", "Dai et al., 2022"),
        ("oglodek", "Og\u{142}odek & Pilis, 2021"),
        ("pietzner", "Pietzner et al., 2024"),
        ("scharf", "Scharf et al., 2022"),
    ]

    static var studies: [Study] {
        studyNames.map { Study(name: $0.name, cohort: tr("study.\($0.id).cohort"), finding: tr("study.\($0.id).finding")) }
    }

    static var complications: [Complication] {
        ["sodium", "gout", "ortho", "acid", "bone"].map { id in
            Complication(name: tr("complication.\(id).name"), onset: tr("complication.\(id).onset"),
                         cause: tr("complication.\(id).cause"), signs: tr("complication.\(id).signs"),
                         response: tr("complication.\(id).response"))
        }
    }

    /// Paper titles stay in their published language.
    static let sources: [Source] = [
        Source(title: "Is water-only fasting safe? (PMC8369953)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8369953/"),
        Source(title: "Goldhamer A. Water fasting, clinical effectiveness (PMC4684131)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4684131/"),
        Source(title: "Efficacy and safety of prolonged water fasting: a narrative review (PMC11494232)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11494232/"),
        Source(title: "Is fasting safe? A chart review of adverse events during medically supervised, water-only fasting (PMC5819235)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5819235/"),
        Source(title: "Fasting therapy: an expert panel update of the 2002 consensus (Karger)", url: "https://karger.com/fok/article/20/6/434/356679/Fasting-Therapy-an-Expert-Panel-Update-of-the-2002"),
        Source(title: "Critical assessment of fasting to promote metabolic health (Endocrine Reviews)", url: "https://academic.oup.com/edrv/article/46/6/856/8211151"),
        Source(title: "Effects of 10-day complete fasting on physiological homeostasis (Nutrients)", url: "https://www.mdpi.com/2072-6643/14/18/3860"),
        Source(title: "Metabolic and hormonal effects of an 8 days water only fasting (PMC12219608)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12219608/"),
        Source(title: "Endocrine adaptations to prolonged fasting (Nutrients)", url: "https://www.mdpi.com/2072-6643/17/24/3949"),
        Source(title: "Spermidine is essential for fasting-mediated autophagy and longevity (PMC11392816)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11392816/"),
        Source(title: "A single 36-h water-only fast vastly remodels the plasma lipidome (PMC10513913)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC10513913/"),
        Source(title: "The effects of prolonged water-only fasting and refeeding (PMC8951503)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8951503/"),
        Source(title: "Prolonged water-only fasting followed by a whole-plant-food diet (PMC11597177)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11597177/"),
        Source(title: "Refeeding syndrome, StatPearls (NCBI Bookshelf)", url: "https://www.ncbi.nlm.nih.gov/sites/books/NBK564513/"),
        Source(title: "ASPEN guidelines for refeeding syndrome, a review (PMC9464262)", url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9464262/"),
        Source(title: "Scientists reveal what seven days of fasting does to the human body (ScienceDaily)", url: "https://www.sciencedaily.com/releases/2026/10/261005012444.htm"),
    ]
}
