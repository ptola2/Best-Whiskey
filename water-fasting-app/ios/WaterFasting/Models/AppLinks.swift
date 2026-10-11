import Foundation

enum AppLinks {
    /// Public page for PRIVACY_POLICY.md. App Review requires this link inside the app as well as in App Store
    /// Connect (guideline 5.1.1). Opened from Welcome and from Profile, then Your data. Use the same address in
    /// App Store Connect.
    static let privacyPolicy = URL(string: "https://malebolabs.com/waterline-privacy-policy/")!
}
