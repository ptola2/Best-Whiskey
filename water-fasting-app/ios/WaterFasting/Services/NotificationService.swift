import Foundation
import UserNotifications

/// Local reminders during a fast: milestone alerts and twice-daily check-in prompts, matching the
/// twice-daily checks used in supervised clinics. Check-in prompts run in a rolling window from now,
/// not up to the target, so a fast that runs past its target keeps getting them. The window is
/// renewed every time the app comes forward.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let windowDays = 14
    private let maxCheckInReminders = 28

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleFast(start: Date, targetHours: Int, supervised: Bool) async {
        guard await requestPermission() else { return }
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let target = Double(targetHours)
        let targetDate = start.addingTimeInterval(target * 3600)
        var items: [(date: Date, title: String, body: String)] = []

        let milestones: [(hours: Double, title: String, body: String)] = [
            (12, tr("notify.h12.title"), tr("notify.h12.body")),
            (36, tr("notify.h36.title"), tr("notify.h36.body")),
            (72, tr("notify.h72.title"), tr("notify.h72.body")),
            (168, tr("notify.d7.title"), tr("notify.d7.body")),
        ]
        for m in milestones where m.hours < target {
            let date = start.addingTimeInterval(m.hours * 3600)
            if date > now { items.append((date: date, title: m.title, body: m.body)) }
        }
        if targetDate > now {
            items.append((date: targetDate, title: tr("notify.target.title"),
                          body: tr("notify.target.body", Fmt.target(targetHours))))
        }
        let pastTarget = targetDate.addingTimeInterval(12 * 3600)
        if pastTarget > now {
            items.append((date: pastTarget, title: tr("notify.past_target.title"),
                          body: tr("notify.past_target.body")))
        }
        let unsupervisedLimit = start.addingTimeInterval(72 * 3600)
        // A 72 h target already gets "Target reached" at that moment; shorter fasts that overrun get this one.
        if !supervised && targetHours < 72 && unsupervisedLimit > now {
            items.append((date: unsupervisedLimit, title: tr("notify.unsupervised.title"),
                          body: tr("notify.unsupervised.body")))
        }

        let calendar = Calendar.current
        let windowEnd = now.addingTimeInterval(Double(windowDays) * 86_400)
        var day = calendar.startOfDay(for: max(start, now))
        var count = 0
        while day < windowEnd && count < maxCheckInReminders {
            for hour in [9, 21] {
                guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                if date > now && date > start && date < windowEnd && count < maxCheckInReminders {
                    items.append((date: date, title: tr("notify.checkin.title"), body: tr("notify.checkin.body")))
                    count += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        for (index, item) in items.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: "waterline.\(index)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
