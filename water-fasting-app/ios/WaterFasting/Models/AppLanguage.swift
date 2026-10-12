import Foundation
import Observation

/// A language Waterline ships in.
struct LanguageOption: Identifiable, Hashable {
    /// Matches the .lproj folder the String Catalog builds: "fr", "pt-BR", "zh-Hans".
    let code: String
    /// The language's name in itself, so people can find their own language whatever the screen is showing.
    let nativeName: String
    /// Regions (ISO 3166 codes) where this is the main language. The first one gives the default flag.
    let regions: [String]

    var id: String { code }
}

/// The language the app shows. All text goes through tr(), which reads from here, so a change takes effect on
/// every screen at once, with no restart. The choice is a setting on this iPhone (UserDefaults), not part of the
/// fasting data, so it is not synced and survives "Delete all my data".
@Observable
final class AppLanguage {
    static let shared = AppLanguage()

    /// English first, then the others by their English name. The order never changes with the language on
    /// screen, so the list does not jump around while someone is choosing.
    static let options: [LanguageOption] = [
        LanguageOption(code: "en", nativeName: "English",
                       regions: ["GB", "US", "AU", "CA", "IE", "NZ", "ZA", "SG", "PH", "NG", "GH", "JM"]),
        LanguageOption(code: "ar", nativeName: "العربية",
                       regions: ["SA", "AE", "BH", "DZ", "EG", "IQ", "JO", "KW", "LB", "LY", "MA", "MR", "OM", "PS",
                                 "QA", "SD", "SY", "TN", "YE"]),
        LanguageOption(code: "zh-Hans", nativeName: "简体中文", regions: ["CN"]),
        LanguageOption(code: "nl", nativeName: "Nederlands", regions: ["NL", "SR"]),
        LanguageOption(code: "fr", nativeName: "Français",
                       regions: ["FR", "MC", "SN", "CI", "ML", "BF", "NE", "TG", "BJ", "GN", "CD", "CG", "GA", "MG",
                                 "HT", "TD", "CF", "BI"]),
        LanguageOption(code: "de", nativeName: "Deutsch", regions: ["DE", "AT", "CH", "LI"]),
        LanguageOption(code: "hi", nativeName: "हिन्दी", regions: ["IN"]),
        LanguageOption(code: "id", nativeName: "Bahasa Indonesia", regions: ["ID"]),
        LanguageOption(code: "it", nativeName: "Italiano", regions: ["IT", "SM", "VA"]),
        LanguageOption(code: "ja", nativeName: "日本語", regions: ["JP"]),
        LanguageOption(code: "ko", nativeName: "한국어", regions: ["KR"]),
        LanguageOption(code: "ms", nativeName: "Bahasa Melayu", regions: ["MY", "BN"]),
        LanguageOption(code: "pl", nativeName: "Polski", regions: ["PL"]),
        LanguageOption(code: "pt-BR", nativeName: "Português (Brasil)",
                       regions: ["BR", "PT", "AO", "MZ", "CV", "GW", "ST"]),
        LanguageOption(code: "ru", nativeName: "Русский", regions: ["RU", "BY", "KZ", "KG"]),
        LanguageOption(code: "es", nativeName: "Español",
                       regions: ["ES", "MX", "AR", "CO", "CL", "PE", "VE", "EC", "GT", "CU", "BO", "DO", "HN", "PY",
                                 "SV", "NI", "CR", "PA", "UY", "GQ", "PR"]),
        LanguageOption(code: "sw", nativeName: "Kiswahili", regions: ["TZ", "KE"]),
        LanguageOption(code: "sv", nativeName: "Svenska", regions: ["SE"]),
        LanguageOption(code: "th", nativeName: "ไทย", regions: ["TH"]),
        LanguageOption(code: "tr", nativeName: "Türkçe", regions: ["TR"]),
        LanguageOption(code: "vi", nativeName: "Tiếng Việt", regions: ["VN"]),
    ]

    private static let choiceKey = "waterline.language"
    private static let confirmedKey = "waterline.languageConfirmed"

    /// The language picked in Waterline, or nil to follow the iPhone.
    private(set) var choice: String?
    /// True once a language has been confirmed on the first-launch screen.
    private(set) var confirmed: Bool
    /// Where tr() looks up text.
    private(set) var bundle: Bundle = .main
    /// Formats numbers, dates and lists to match the text.
    private(set) var locale: Locale = .autoupdatingCurrent

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.choiceKey)
        choice = Self.options.contains { $0.code == saved } ? saved : nil
        confirmed = UserDefaults.standard.bool(forKey: Self.confirmedKey)
        apply()
    }

    // MARK: What is on screen

    /// The language on screen now.
    var code: String { choice ?? Self.systemCode }

    var current: LanguageOption { Self.option(code) }

    var isRightToLeft: Bool { Locale.Language(identifier: code).characterDirection == .rightToLeft }

    static func option(_ code: String) -> LanguageOption {
        options.first { $0.code == code } ?? options[0]
    }

    // MARK: Suggestions

    /// Waterline's best match for the iPhone's language settings, including the per-app language in Settings.
    /// English when none of the iPhone's languages is available.
    static var systemCode: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return options.contains { $0.code == code } ? code : "en"
    }

    /// The language of the iPhone's Region setting, when Waterline has it ("FR" gives French). Region comes from
    /// Settings, not GPS, so no location permission is needed and nothing leaves the phone.
    static var regionCode: String? {
        guard let region = Locale.current.region?.identifier else { return nil }
        return options.first { $0.regions.contains(region) }?.code
    }

    /// What the first-launch screen starts on. The iPhone's language comes first. When that is English, which is
    /// often the default rather than a choice, the region decides: an English-language iPhone in France starts
    /// in French, and the person can still pick English with one tap.
    static var suggestedCode: String {
        let system = systemCode
        if system == "en", let region = regionCode { return region }
        return system
    }

    /// Shown at the top of the list: the suggestion, then the iPhone's language and the region's language if they
    /// differ from it.
    static var suggestions: [String] {
        var codes = [suggestedCode]
        for code in [systemCode, regionCode].compactMap({ $0 }) where !codes.contains(code) {
            codes.append(code)
        }
        return codes
    }

    /// The person's own country flag when the language is spoken there (Spanish in Mexico shows Mexico's flag),
    /// otherwise the language's usual flag.
    static func flag(for option: LanguageOption) -> String {
        let here = Locale.current.region?.identifier
        let region = here.flatMap { option.regions.contains($0) ? $0 : nil } ?? option.regions.first ?? ""
        var flag = ""
        for letter in region.unicodeScalars where (65...90).contains(letter.value) {
            if let indicator = Unicode.Scalar(0x1F1E6 + letter.value - 65) {
                flag.unicodeScalars.append(indicator)
            }
        }
        return flag
    }

    /// The language's name in the language on screen ("Allemand" while the app shows French).
    func localizedName(of code: String) -> String {
        guard let name = locale.localizedString(forIdentifier: code), let first = name.first else { return "" }
        return String(first).uppercased(with: locale) + name.dropFirst()
    }

    // MARK: Changing it

    /// Shows `code` from now on. nil follows the iPhone.
    func select(_ code: String?) {
        choice = code.flatMap { picked in Self.options.contains { $0.code == picked } ? picked : nil }
        UserDefaults.standard.set(choice, forKey: Self.choiceKey)
        apply()
    }

    /// First launch: starts on the suggested language, so the first screen is readable straight away.
    func applySuggestion() {
        guard !confirmed, choice == nil else { return }
        let suggested = Self.suggestedCode
        if suggested != Self.systemCode { select(suggested) }
    }

    /// Ends the first-launch language step.
    func confirm() {
        // Keeping the iPhone's own language stores no override, so a later change on the iPhone carries over.
        if choice == Self.systemCode { select(nil) }
        confirmed = true
        UserDefaults.standard.set(true, forKey: Self.confirmedKey)
    }

    private func apply() {
        let code = self.code
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let lproj = Bundle(path: path) {
            bundle = lproj
        } else {
            bundle = .main
        }
        locale = choice == nil ? .autoupdatingCurrent : Self.locale(for: code)
    }

    /// The chosen language with the person's own region and clock setting, so dates and numbers still look local.
    private static func locale(for code: String) -> Locale {
        var components = Locale.Components(identifier: code)
        if components.region == nil, let region = Locale.current.region {
            components.region = region
        }
        components.hourCycle = Locale.current.hourCycle
        return Locale(components: components)
    }
}
