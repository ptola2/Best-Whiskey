import ActivityKit
import Foundation
import WidgetKit

/// Keeps the Home Screen widget and the Live Activity in step with the running fast.
///
/// Called whenever the data is saved, when the language changes and when the app comes forward. Writing the shared
/// data is skipped when nothing changed, so frequent saves (water taps) cost nothing.
@MainActor
enum WidgetBridge {
    static func refresh() {
        let data = snapshot(FastStore.shared.data.active)
        if data != FastWidgetData.load() {
            data.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        LiveActivities.sync(data)
    }

    /// Everything the widget shows, written in the language the app is showing.
    private static func snapshot(_ fast: ActiveFast?) -> FastWidgetData {
        let language = AppLanguage.shared
        let target = fast?.targetHours ?? 0
        return FastWidgetData(
            startedAt: fast?.startedAt,
            targetHours: target,
            phases: Research.phases.map { FastWidgetData.Phase(startHours: $0.from, name: $0.name) },
            labels: FastWidgetData.Labels(
                fasting: tr("live.fasting"),
                target: target > 0 ? tr("live.target", Fmt.target(target)) : "",
                reached: tr("live.reached"),
                nextFormat: tr("live.next", "%@"),
                idleTitle: tr("live.idle.title"),
                idleBody: tr("live.idle.body")),
            rightToLeft: language.isRightToLeft,
            localeIdentifier: language.locale.identifier)
    }
}

/// Starts, updates and ends the Live Activity. iOS ends a Live Activity after about eight hours, so a long fast gets a
/// fresh one each time the app is opened.
@MainActor
enum LiveActivities {
    static func sync(_ data: FastWidgetData) {
        let activities = Activity<FastActivityAttributes>.activities
        guard let startedAt = data.startedAt, let targetAt = data.targetDate else {
            for activity in activities { end(activity) }
            return
        }

        let now = Date()
        let state = FastActivityAttributes.ContentState(
            phaseName: data.phase(at: now)?.name ?? "",
            nextLabel: data.nextLabel(after: now),
            fastingLabel: data.labels.fasting,
            targetLabel: data.labels.target,
            reachedLabel: data.labels.reached,
            rightToLeft: data.rightToLeft)
        // Once the next phase begins the shown phase is out of date, so the view hides it until the app refreshes it.
        let content = ActivityContent(state: state, staleDate: data.nextPhase(after: now)?.at)

        var current: Activity<FastActivityAttributes>?
        for activity in activities {
            let running = activity.activityState == .active || activity.activityState == .stale
            if running, current == nil, activity.attributes.startedAt == startedAt, activity.attributes.targetAt == targetAt {
                current = activity
            } else {
                end(activity)
            }
        }

        if let current {
            // Saves happen often (every water tap), so the activity is only touched when what it shows changes.
            if current.content.state != state || current.content.staleDate != content.staleDate {
                Task { await current.update(content) }
            }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Only possible while the app is in the foreground; at other times iOS refuses and the next launch retries.
            _ = try? Activity.request(attributes: FastActivityAttributes(startedAt: startedAt, targetAt: targetAt),
                                      content: content, pushType: nil)
        }
    }

    private static func end(_ activity: Activity<FastActivityAttributes>) {
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
