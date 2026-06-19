import Foundation

/// The time of day local notifications fire, user-configurable in Settings
/// (defaults to 9:00am). Shared by every local-notification scheduler
/// (`TaxReminders`, `InvoiceReminders`). Stored device-local (not iCloud-synced),
/// matching the other notification preferences.
enum ReminderTime {
    static let hourKey = "notify_hour"
    static let minuteKey = "notify_minute"

    /// Hour (0–23). Defaults to 9 when unset.
    static var hour: Int { (UserDefaults.standard.object(forKey: hourKey) as? Int) ?? 9 }

    /// Minute (0–59). Defaults to 0 (`integer(forKey:)` returns 0 when unset).
    static var minute: Int { UserDefaults.standard.integer(forKey: minuteKey) }
}
