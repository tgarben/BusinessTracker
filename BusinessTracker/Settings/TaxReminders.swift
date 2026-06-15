import Foundation
import UserNotifications

/// Schedules local notifications ahead of each quarterly IRS estimated-tax deadline.
/// Opt-in via `@AppStorage("tax_remindersEnabled")`. No server / no push entitlement —
/// these are local `UNCalendarNotificationTrigger`s, rescheduled on launch so they roll forward.
enum TaxReminders {
    static let enabledKey = "tax_remindersEnabled"
    private static let idPrefix = "tax-deadline-"
    private static let leadDays = [7, 1]   // notify a week out and the day before
    private static let fireHour = 9         // 9am local

    /// The four quarterly deadlines for the current cycle (Q4 rolls into next year).
    static func dueDates(from ref: Date = .now, calendar: Calendar = .current) -> [(label: String, date: Date)] {
        let year = calendar.component(.year, from: ref)
        let specs: [(label: String, month: Int, day: Int, nextYear: Bool)] = [
            ("Q1", 4, 15, false), ("Q2", 6, 15, false), ("Q3", 9, 15, false), ("Q4", 1, 15, true),
        ]
        return specs.map { s in
            var c = DateComponents()
            c.year = s.nextYear ? year + 1 : year
            c.month = s.month
            c.day = s.day
            return (s.label, calendar.date(from: c) ?? ref)
        }
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Clears our previously-scheduled reminders and (if enabled) schedules upcoming ones.
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let now = Date.now
        let cal = Calendar.current
        for due in dueDates() {
            for lead in leadDays {
                guard let fire = cal.date(byAdding: .day, value: -lead, to: due.date), fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Estimated Tax Due Soon"
                let dateStr = due.date.formatted(date: .abbreviated, time: .omitted)
                content.body = lead == 1
                    ? "Your \(due.label) estimated tax payment is due tomorrow (\(dateStr))."
                    : "Your \(due.label) estimated tax payment is due in \(lead) days (\(dateStr))."
                content.sound = .default

                var comps = cal.dateComponents([.year, .month, .day], from: fire)
                comps.hour = fireHour
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "\(idPrefix)\(due.label)-\(lead)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// Called from the Settings toggle. Requests authorization when turning on.
    static func handleToggle(enabled: Bool) async {
        if enabled {
            _ = await requestAuthorization()
        }
        await reschedule()
    }
}
