import Foundation
import UserNotifications

/// Local reminders during a fast: milestone alerts and twice-daily check-in prompts,
/// matching the twice-daily checks used in supervised clinics.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let maxCheckInReminders = 40

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleFast(start: Date, targetHours: Int) async {
        guard await requestPermission() else { return }
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let target = Double(targetHours)
        let targetDate = start.addingTimeInterval(target * 3600)
        var items: [(date: Date, title: String, body: String)] = []

        let milestones: [(hours: Double, title: String, body: String)] = [
            (12, "12 hours in", "Liver glycogen is running down and fat stores are opening up."),
            (36, "36 hours: the metabolic switch", "Ketone production is climbing. Get up slowly: lightheadedness on standing is common now."),
            (72, "The 72-hour threshold", "Body-wide protein changes appear around now. Fasts beyond this point belong under medical supervision."),
            (168, "Day 7", "Weight loss is slowing and the kidneys are saving sodium. Keep checking in twice a day."),
        ]
        for m in milestones where m.hours < target {
            let date = start.addingTimeInterval(m.hours * 3600)
            if date > now { items.append((date: date, title: m.title, body: m.body)) }
        }
        if targetDate > now {
            items.append((date: targetDate, title: "Target reached",
                          body: "You reached your \(Fmt.target(targetHours)) target. End the fast in Waterline to get your refeeding plan."))
        }

        let calendar = Calendar.current
        let lastReminder = targetDate.addingTimeInterval(86_400)
        var day = calendar.startOfDay(for: max(start, now))
        var count = 0
        while day < lastReminder && count < maxCheckInReminders {
            for hour in [9, 21] {
                guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                if date > now && date > start && date < lastReminder && count < maxCheckInReminders {
                    items.append((date: date, title: "Time to check in", body: "Log lying and standing blood pressure, pulse, weight and how you feel."))
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
