import Foundation

enum AppLinks {
    /// Public page for PRIVACY_POLICY.md. App Review requires this link inside the app as well as in App Store
    /// Connect (guideline 5.1.1). After publishing the page, open the live address in a browser and update it here
    /// if it differs: WordPress sometimes adds "-2" to a slug that already exists.
    static let privacyPolicy = URL(string: "https://malebolabs.com/waterline-privacy-policy/")!
}
