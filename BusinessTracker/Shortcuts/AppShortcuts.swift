import AppIntents
import Foundation

// Siri / Shortcuts / Spotlight entry points. Each intent opens the app and queues an
// action in the App Group store; `BusinessTrackerApp.consumePendingShortcutAction()`
// reads it on launch/foreground and routes to the right sheet via `pendingWidgetAction`.

private let kAppGroupSuite = "group.com.garbenTechnologies.BusinessTracker"
private let kPendingShortcutKey = "pendingShortcutAction"

private func queueShortcutAction(_ action: String) {
    UserDefaults(suiteName: kAppGroupSuite)?.set(action, forKey: kPendingShortcutKey)
}

struct StartTimerShortcut: AppIntent {
    static var title: LocalizedStringResource = "Start Timer"
    static var description = IntentDescription("Open Freelanced and start a time-tracking timer.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        queueShortcutAction("startTimer")
        return .result()
    }
}

struct LogTimeShortcut: AppIntent {
    static var title: LocalizedStringResource = "Log Time"
    static var description = IntentDescription("Open Freelanced to log a time entry.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        queueShortcutAction("logTime")
        return .result()
    }
}

struct LogTripShortcut: AppIntent {
    static var title: LocalizedStringResource = "Log Trip"
    static var description = IntentDescription("Open Freelanced to log a mileage trip.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        queueShortcutAction("logTrip")
        return .result()
    }
}

struct LogExpenseShortcut: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Open Freelanced to add an expense.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        queueShortcutAction("addExpense")
        return .result()
    }
}

// MARK: - App Shortcuts (auto-registered, no user setup; phrases must include the app name)

struct FreelancedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerShortcut(),
            phrases: [
                "Start a timer in \(.applicationName)",
                "Start tracking time in \(.applicationName)",
                "Start the clock in \(.applicationName)",
            ],
            shortTitle: "Start Timer",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: LogTripShortcut(),
            phrases: [
                "Log a trip in \(.applicationName)",
                "Log mileage in \(.applicationName)",
            ],
            shortTitle: "Log Trip",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: LogExpenseShortcut(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log an expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: LogTimeShortcut(),
            phrases: [
                "Log time in \(.applicationName)",
            ],
            shortTitle: "Log Time",
            systemImageName: "clock.fill"
        )
    }
}
