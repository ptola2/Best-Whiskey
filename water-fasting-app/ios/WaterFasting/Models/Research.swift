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

    var title: String {
        switch self {
        case .juice: return "Diluted juice"
        case .fruitVeg: return "Whole fruit and steamed vegetables"
        case .starch: return "Add starches and plant fats"
        }
    }

    var text: String {
        switch self {
        case .juice: return "Fresh fruit or vegetable juice diluted with water, 100 to 200 mL every 2 to 3 hours. It gently restarts stomach acid, digestive enzymes and insulin."
        case .fruitVeg: return "Raw whole fruit and steamed non-starchy vegetables, in small meals."
        case .starch: return "Complex carbohydrates such as sweet potato or brown rice, plus modest plant fats like avocado, nuts or seeds. Keep avoiding concentrated animal fats and refined sugar."
        }
    }
}

enum RefeedTier {
    case low, moderate, high

    var label: String {
        switch self {
        case .low: return "Lower risk"
        case .moderate: return "Moderate risk"
        case .high: return "Significant risk"
        }
    }

    var level: Level {
        switch self {
        case .low: return .ok
        case .moderate: return .caution
        case .high: return .stop
        }
    }

    var criteria: String {
        switch self {
        case .low: return "Fast under 5 days, normal electrolytes and a healthy BMI."
        case .moderate: return "Fast of 5 to 7 days, or BMI 16 to 18.5."
        case .high: return "Fast over 7 days, BMI under 16, recent unintended weight loss over 10%, or low electrolytes before refeeding."
        }
    }

    var fluids: String {
        switch self {
        case .low: return "Drink to thirst. Keep added salt out at first, then bring it back slowly."
        case .moderate: return "No added salt. Make sure food supplies potassium and phosphorus."
        case .high: return "Thiamine (vitamin B1), 100 to 300 mg a day as prescribed. No added salt. Electrolytes replaced as needed."
        }
    }

    var monitoring: String {
        switch self {
        case .low: return "Baseline checks only. Get tested if symptoms appear."
        case .moderate: return "Vital signs twice a day and blood electrolytes every 48 hours."
        case .high: return "Daily blood tests (electrolytes, magnesium, phosphorus) for 3 to 5 days."
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

enum Research {
    static let waterMin = 1200
    static let waterMax = 2500
    static let waterScale = 3000
    static let targets = [24, 36, 48, 72, 120, 168, 240, 336, 504]

    static let phases: [Phase] = [
        Phase(id: 0, from: 0, to: 12, name: "Running on your last meal", range: "0 to 12 h",
              text: "Blood sugar comes from your last meal, then from glycogen stored in the liver. Insulin begins to fall."),
        Phase(id: 1, from: 12, to: 36, name: "Glycogen runs down", range: "12 to 36 h",
              text: "Liver glycogen is used up. Falling insulin unlocks fat stores, sending fatty acids and glycerol into the blood. Each gram of glycogen holds 3 to 4 g of water, so early weight loss is mostly water."),
        Phase(id: 2, from: 36, to: 72, name: "The metabolic switch", range: "36 to 72 h",
              text: "The liver turns the flood of fatty acids into ketones (acetoacetate and beta-hydroxybutyrate, or BHB). Low insulin makes the kidneys shed sodium, so blood pressure drops. Typical loss over the first 3 days is 0.9 to 1.5 kg a day, mostly water, glycogen and gut contents."),
        Phase(id: 3, from: 72, to: 96, name: "The 72-hour threshold", range: "Day 4",
              text: "A study that tracked about 3,000 blood proteins daily saw only small changes for 48 hours. From the third day, about 36% of them changed together across every major organ system. 72-hour trials also show more autophagy markers (LC3-II, Beclin-1)."),
        Phase(id: 4, from: 96, to: 168, name: "Keto-adaptation", range: "Days 5 to 7",
              text: "Once BHB passes 2.0 mmol/L, ketones reach the brain and can cover 60 to 70% of its energy. The body needs less glucose made from muscle protein, so protein breakdown drops and steadies around days 4 to 7. The kidneys raise ammonium output to save sodium and potassium."),
        Phase(id: 5, from: 168, to: 240, name: "Deep ketosis", range: "Days 8 to 10",
              text: "BHB usually sits between 3.0 and 7.0 mmol/L by days 5 to 10, up from under 0.1 mmol/L at baseline. IGF-1 falls 40 to 60% by days 5 to 8. Weight loss slows to about 0.25 to 0.40 kg a day as the kidneys switch to saving sodium."),
        Phase(id: 6, from: 240, to: 504, name: "Prolonged fast", range: "Days 11 to 21",
              text: "Free T3 falls and metabolic rate drops to save energy. Under medical supervision, about 28% of fasters had a severe (Grade 3) side effect by day 10 and 32% by day 15."),
        Phase(id: 7, from: 504, to: .infinity, name: "Extreme range", range: "Past day 21",
              text: "Lean tissue loss, low micronutrients and strain on the heart become major concerns. Fasts this long have only been studied in residential medical settings."),
    ]

    static let risks: [RiskWindow] = [
        RiskWindow(id: "ortho", name: "Low blood pressure on standing", fromDay: 2, toDay: 5,
                   signs: "Lightheaded, faint or a racing heart when you stand up.",
                   action: "Sit on the edge of the bed before standing. Keep to rest and quiet walking."),
        RiskWindow(id: "hypona", name: "Low sodium (hyponatremia)", fromDay: 3, toDay: 8,
                   signs: "Muscle cramps, sluggishness, headache, dizziness.",
                   action: "Only a blood test can confirm sodium below 136 mmol/L. Tell your clinician. Stay inside your water target rather than drinking extra."),
        RiskWindow(id: "acid", name: "Ketone acid build-up (metabolic acidosis)", fromDay: 3, toDay: 10,
                   signs: "Fast, deep breathing, nausea, extreme tiredness.",
                   action: "Fast, deep breathing means stop and get medical help."),
        RiskWindow(id: "gout", name: "High uric acid and gout", fromDay: 4, toDay: 12,
                   signs: "Hot, red, painful swelling in a joint, often the big toe.",
                   action: "Keep up your water intake. An acute flare means ending the fast."),
        RiskWindow(id: "bone", name: "Bone mineral loss", fromDay: 15, toDay: 9999,
                   signs: "No symptoms. Shows up as more calcium in urine.",
                   action: "A reason to cap how long a fast runs, especially with low bone density."),
    ]

    static let symptoms: [Symptom] = [
        Symptom(id: "fatigue", label: "Tiredness", group: .common),
        Symptom(id: "headache", label: "Headache", group: .common),
        Symptom(id: "nausea", label: "Nausea", group: .common),
        Symptom(id: "insomnia", label: "Poor sleep", group: .common),
        Symptom(id: "drymouth", label: "Dry mouth", group: .common),
        Symptom(id: "dyspepsia", label: "Indigestion", group: .common),
        Symptom(id: "backpain", label: "Lower back pain", group: .common),
        Symptom(id: "dizzy", label: "Lightheaded when standing", group: .watch),
        Symptom(id: "cramps", label: "Muscle cramps", group: .watch),
        Symptom(id: "lethargy", label: "Heavy, sluggish drowsiness", group: .watch),
        Symptom(id: "faint", label: "Fainted or nearly fainted", group: .stop),
        Symptom(id: "chest", label: "Chest pain or irregular heartbeat", group: .stop),
        Symptom(id: "confusion", label: "Confusion", group: .stop),
        Symptom(id: "vomit", label: "Vomiting, can't keep water down", group: .stop),
        Symptom(id: "joint", label: "Hot, swollen, painful joint", group: .stop),
        Symptom(id: "breathing", label: "Fast, deep breathing", group: .stop),
        Symptom(id: "swelling", label: "Swollen ankles, legs or face", group: .stop),
        Symptom(id: "breathless", label: "Short of breath", group: .stop),
    ]

    static let absolute: [ScreenQuestion] = [
        ScreenQuestion(id: "t1d", question: "Type 1 diabetes",
                       why: "Without your own insulin, a fast leads to diabetic ketoacidosis if insulin is stopped, or dangerously low blood sugar if it is not."),
        ScreenQuestion(id: "preg", question: "Pregnant or breastfeeding",
                       why: "A baby relies on a steady supply of glucose and amino acids, sustained ketones may affect brain development, and milk supply drops."),
        ScreenQuestion(id: "ed", question: "A current or past eating disorder (anorexia, bulimia, ARFID)",
                       why: "Stopping food can set off a serious relapse and carries a high risk of fatal refeeding problems. If eating feels hard right now, an eating disorder support service can help."),
        ScreenQuestion(id: "ckd", question: "Advanced kidney disease (CKD stage 3b to 5, or dialysis)",
                       why: "The kidneys cannot clear the acid load, which risks severe acidosis and high potassium."),
        ScreenQuestion(id: "liver", question: "Cirrhosis of the liver with complications",
                       why: "The liver cannot store glycogen or make glucose well, so blood sugar stays dangerously low."),
        ScreenQuestion(id: "porph", question: "Acute porphyria",
                       why: "Cutting calories switches on the liver enzyme ALAS1, which sets off attacks."),
        ScreenQuestion(id: "cachexia", question: "Severe weight or muscle wasting (cachexia, sarcopenia)",
                       why: "Without fat and protein reserves, fasting can waste heart muscle and cause fatal heart rhythms."),
    ]

    static let relative: [ScreenQuestion] = [
        ScreenQuestion(id: "diuretic", question: "Taking a diuretic (\"water pill\")",
                       why: "Diuretics add to the sodium loss of fasting and can cause fluid collapse, fainting, low potassium and heart rhythm problems.",
                       action: "Your doctor has to stop it before the fast, and the fast needs inpatient monitoring.", needsSupervision: true),
        ScreenQuestion(id: "t2d", question: "Type 2 diabetes treated with tablets or insulin",
                       why: "Sulfonylureas cause severe low blood sugar without food. SGLT2 inhibitors can cause ketoacidosis even with normal glucose.",
                       action: "Medicines must be tapered or stopped by a doctor, SGLT2 inhibitors well before the fast. Fast only under physician oversight.", needsSupervision: true),
        ScreenQuestion(id: "bpmeds", question: "Taking blood pressure medicine (ACE inhibitor, ARB, calcium channel blocker, beta-blocker)",
                       why: "Fasting lowers blood pressure by itself. Full doses on top can cause severe low pressure, fainting and poor blood flow to the kidneys.",
                       action: "Only your doctor should reduce or stop these."),
        ScreenQuestion(id: "lithium", question: "Taking lithium or another psychiatric medicine with a narrow safe range",
                       why: "Dehydration and sodium changes slow lithium clearance and raise the risk of toxicity.",
                       action: "Needs close monitoring by your prescriber."),
        ScreenQuestion(id: "gout", question: "Gout or high uric acid",
                       why: "Ketones compete with uric acid for removal by the kidneys, which can set off a gout flare.",
                       action: "Drink enough water and have uric acid checked during the fast."),
        ScreenQuestion(id: "bone", question: "Osteopenia or osteoporosis",
                       why: "Long fasts draw minerals from bone to buffer ketone acids.",
                       action: "Fasts over 72 hours are off the table. Keep any fast short."),
        ScreenQuestion(id: "heart", question: "Heart disease or a heart rhythm problem",
                       why: "Electrolyte losses can trigger rhythm problems, and refeeding can overload the heart with salt and fluid.",
                       action: "Needs specialist supervision."),
    ]

    static let refeedRisk: [ScreenQuestion] = [
        ScreenQuestion(id: "wtloss", question: "Lost more than 10% of your body weight without trying in the last 3 to 6 months", why: ""),
        ScreenQuestion(id: "lytes", question: "Been told you have low phosphate, potassium or magnesium", why: ""),
    ]

    static let protocols: [FastingProtocol] = [
        FastingProtocol(name: "Water-only", calories: "0 kcal a day", allowed: "Plain distilled or mineral water, 1.2 to 2.5 L a day or more", length: "3 to 21+ days", setting: "Residential, with twice-daily checks and lab tests"),
        FastingProtocol(name: "Buchinger", calories: "200 to 250 kcal a day", allowed: "Vegetable broth, fresh juice, herbal tea with honey", length: "5 to 20 days", setting: "Residential or outpatient, run by certified therapists"),
        FastingProtocol(name: "Fasting-mimicking diet", calories: "Reduced", allowed: "Plant-based soups, energy bars, teas, a glycerol drink", length: "5 days per cycle", setting: "Self-run or supervised"),
        FastingProtocol(name: "Alternate-day fasting", calories: "0 kcal or a small allowance on fast days", allowed: "Water, black coffee, unsweetened tea", length: "Alternating 24 h", setting: "Lifestyle routine"),
        FastingProtocol(name: "Time-restricted eating", calories: "Normal, inside an eating window", allowed: "Water and zero-calorie drinks while fasting", length: "14 to 20 h fasting daily", setting: "Lifestyle routine"),
    ]

    static let hormones: [HormoneRow] = [
        HormoneRow(marker: "Insulin", change: "Down, marked", why: "No carbohydrate or protein coming in", effect: "Unlocks fat stores; kidneys shed sodium"),
        HormoneRow(marker: "BHB (ketone)", change: "Up, marked", why: "Liver burns fatty acids", effect: "Main brain fuel; relaxes blood vessels"),
        HormoneRow(marker: "Growth hormone", change: "Up", why: "Response to falling insulin and glucose", effect: "Spares muscle; more fat breakdown"),
        HormoneRow(marker: "IGF-1", change: "Down 40 to 60%", why: "Liver stops responding to growth hormone", effect: "Halts cell growth signals; more stress resistance"),
        HormoneRow(marker: "Cortisol", change: "Up", why: "Stress axis switched on", effect: "Keeps the liver making glucose"),
        HormoneRow(marker: "Free T3", change: "Down", why: "Less thyroid hormone activated in the liver", effect: "Lower metabolic rate; spares protein"),
        HormoneRow(marker: "mTORC1", change: "Down", why: "Amino acids run low; AMPK switched on", effect: "Triggers autophagy and mitophagy"),
        HormoneRow(marker: "Uric acid", change: "Up", why: "Ketones block its removal in the kidney", effect: "Gout flare risk"),
    ]

    static let studies: [Study] = [
        Study(name: "Goldhamer et al., 2001", cohort: "174 adults with high blood pressure, water fast averaging 10.5 days",
              finding: "89% reached a reading under 140/90 mmHg. People starting above 180/110 dropped 37/13 mmHg on average. Everyone on blood pressure medicine stopped it during the fast with no rebound."),
        Study(name: "Dai et al., 2022", cohort: "Overweight men without diabetes, 10-day water fast",
              finding: "Weight fell 7.28 kg (9.8%). Systolic pressure was down 6.44% by day 7 and 14.68% at its lowest, on the first day of refeeding. Sodium, chloride and IGF-1 fell."),
        Study(name: "Og\u{142}odek and Pilis, 2021", cohort: "Healthy, normal-weight men, 8-day water fast",
              finding: "Lower blood pressure, weight, BMI, fat-free mass and body water. Low sodium (under 136 mmol/L) developed, and uric acid clearance fell."),
        Study(name: "Pietzner et al., 2024", cohort: "Healthy adults, 7-day water fast",
              finding: "Average loss of 5.7 kg, with the lean mass regained after refeeding. A distinct change in blood proteins appeared from day 3, involving about 36% of those measured."),
        Study(name: "Scharf et al., 2022", cohort: "Adults with obesity, no diabetes, 17-day water fast",
              finding: "Body weight fell 10.2%. Blood pressure, fasting glucose, insulin and insulin resistance (HOMA-IR) fell. Triglycerides rose for a while."),
    ]

    static let complications: [Complication] = [
        Complication(name: "Low sodium", onset: "Days 3 to 8", cause: "Sodium loss from low insulin, plus plain water", signs: "Cramps, sluggishness, headache, dizziness on standing", response: "Watch fluid intake; sometimes oral salt"),
        Complication(name: "High uric acid, gout", onset: "Days 4 to 12", cause: "Ketones compete with urate in the kidney", signs: "Red, painful, swollen joint, often the big toe", response: "Keep hydrated; end the fast for an acute flare"),
        Complication(name: "Low blood pressure on standing", onset: "Days 2 to 5", cause: "Lower blood volume and a calmer nervous system", signs: "Near-fainting, lightheadedness, racing pulse on standing", response: "Strict rest; slow position changes; vital signs"),
        Complication(name: "Metabolic acidosis", onset: "Days 3 to 10", cause: "Ketone acids build up", signs: "Fast, deep breathing, nausea, extreme tiredness", response: "Track bicarbonate; start refeeding if blood pH falls"),
        Complication(name: "Bone mineral loss", onset: "Extended fasts", cause: "Bone releases calcium salts to buffer acid", signs: "More calcium in urine", response: "Cap fast length; avoid long fasts with low bone density"),
    ]

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
