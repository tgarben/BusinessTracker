import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for unpaid invoices as their due date approaches.
/// Opt-in via `@AppStorage("invoice_remindersEnabled")`. Local `UNCalendarNotificationTrigger`s
/// (no server/push), rescheduled on launch + foreground so new/edited invoices are picked up.
/// Mirrors `TaxReminders`, but it has to fetch invoices, so it takes the `ModelContainer`.
enum InvoiceReminders {
    static let enabledKey = "invoice_remindersEnabled"
    private static let idPrefix = "invoice-due-"
    private static let leadDays = [1, 0]    // the day before, and the due date itself

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Clears our previously-scheduled invoice reminders and (if enabled) schedules
    /// upcoming ones for every unpaid invoice whose due date is today or later.
    @MainActor
    static func reschedule(container: ModelContainer) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.deletedDate == nil && $0.isPaid == false }
        )
        guard let invoices = try? context.fetch(descriptor) else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let now = Date.now

        for invoice in invoices {
            let dueDay = cal.startOfDay(for: invoice.dueDate)
            guard dueDay >= today else { continue }   // already overdue — can't schedule a past fire

            for lead in leadDays {
                guard let fireDay = cal.date(byAdding: .day, value: -lead, to: dueDay) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
                comps.hour = ReminderTime.hour
                comps.minute = ReminderTime.minute
                guard let fireDate = cal.date(from: comps), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                let who = invoice.client?.name ?? "your client"
                content.title = lead == 0 ? "Invoice Due Today" : "Invoice Due Tomorrow"
                content.body = "\(invoice.formattedNumber) for \(who) — \(invoice.total.asCurrency)."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(idPrefix)\(invoice.invoiceNumber)-\(lead)",
                    content: content, trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    /// Called from the Settings toggle. Requests authorization when turning on.
    @MainActor
    static func handleToggle(enabled: Bool, container: ModelContainer) async {
        if enabled { _ = await requestAuthorization() }
        await reschedule(container: container)
    }
}
