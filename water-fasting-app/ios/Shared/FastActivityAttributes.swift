import ActivityKit
import Foundation

/// The Live Activity for a running fast: on the Lock Screen and in the Dynamic Island. Compiled into both targets.
/// The timer and progress bar count by themselves; the app refreshes the phase and labels whenever it is opened.
struct FastActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The current phase, shown until the next phase begins (the content's stale date).
        var phaseName: String
        var nextLabel: String?
        var fastingLabel: String
        var targetLabel: String
        var reachedLabel: String
        var rightToLeft: Bool
    }

    var startedAt: Date
    var targetAt: Date
}
