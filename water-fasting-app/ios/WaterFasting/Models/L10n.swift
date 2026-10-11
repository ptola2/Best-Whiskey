import Foundation

// All user-facing text lives in Localizable.xcstrings under stable keys (for example "today.title"), with English
// as one language among the others. The catalog is generated from Localization/*.json by
// Localization/build_catalog.py, which also checks every translation.
//
// Strings with values use printf-style specifiers: %@ for text, %lld for whole numbers, and positional forms
// (%1$@, %2$lld) when there are several, so each language can put them in its own order.

/// Looks up a translated string and fills in any values.
func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    guard !args.isEmpty else { return format }
    return String(format: format, locale: Locale.current, arguments: args)
}

/// Looks up a count-dependent string ("1 day", "2 days"). Plural rules come from the catalog, so languages with
/// several plural forms (Arabic, Polish, Russian) get the right one.
func trCount(_ key: String, _ count: Int) -> String {
    String.localizedStringWithFormat(Bundle.main.localizedString(forKey: key, value: nil, table: nil), count)
}
