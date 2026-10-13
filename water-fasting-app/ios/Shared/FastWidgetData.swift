import Foundation

/// What the app shares with the widget and the Live Activity. Compiled into both targets.
///
/// The app writes it into the shared App Group whenever the fast or the language changes. Every label is already in
/// the language chosen inside Waterline, so the widget shows the same language as the app and needs no translations
/// of its own for this content.
struct FastWidgetData: Codable, Equatable {
    struct Phase: Codable, Equatable {
        var startHours: Double
        var name: String
    }

    struct Labels: Codable, Equatable {
        /// "Fasting"
        var fasting: String
        /// "Target 72 h"
        var target: String
        /// "Target reached"
        var reached: String
        /// "Next: The metabolic switch", with %@ filled in per phase by the widget.
        var nextFormat: String
        var idleTitle: String
        var idleBody: String
    }

    /// When the running fast started. nil when no fast is running.
    var startedAt: Date?
    var targetHours: Int
    var phases: [Phase]
    var labels: Labels
    var rightToLeft: Bool
    var localeIdentifier: String

    static let appGroup = "group.com.malebolabs.waterline"
    private static let key = "waterline.widget"

    static func load() -> FastWidgetData? {
        guard let bytes = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FastWidgetData.self, from: bytes)
    }

    func save() {
        guard let bytes = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(bytes, forKey: Self.key)
    }

    var targetDate: Date? {
        startedAt.map { $0.addingTimeInterval(Double(targetHours) * 3600) }
    }

    /// The metabolic phase at a moment of the running fast.
    func phase(at date: Date) -> Phase? {
        guard let startedAt else { return nil }
        let hours = date.timeIntervalSince(startedAt) / 3600
        return phases.last { $0.startHours <= hours }
    }

    /// The next phase after a moment, and when it starts.
    func nextPhase(after date: Date) -> (phase: Phase, at: Date)? {
        guard let startedAt else { return nil }
        let hours = date.timeIntervalSince(startedAt) / 3600
        guard let next = phases.first(where: { $0.startHours > hours }) else { return nil }
        return (next, startedAt.addingTimeInterval(next.startHours * 3600))
    }

    func nextLabel(after date: Date) -> String? {
        nextPhase(after: date).map { String(format: labels.nextFormat, $0.phase.name) }
    }
}
