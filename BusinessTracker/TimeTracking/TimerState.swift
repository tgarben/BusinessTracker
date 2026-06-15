import ActivityKit
import Foundation
import Observation

private let kAppGroupSuite  = "group.com.garbenTechnologies.BusinessTracker"
private let kTimerStartKey  = "timerStartDate"

enum WidgetAction {
    case startTimer, logTime, logTrip, addExpense, createInvoice
}

/// Shared observable object that tracks whether a timer is currently running.
/// Persisted to UserDefaults so the timer survives backgrounding.
@Observable
final class TimerState {
    var startDate: Date?
    var client: Client?
    var project: Project?
    var pendingWidgetAction: WidgetAction?

    var isRunning: Bool { startDate != nil }

    var elapsed: TimeInterval {
        guard let start = startDate else { return 0 }
        return Date.now.timeIntervalSince(start)
    }

    var elapsedHours: Double { elapsed / 3600 }

    // Shared with the widget extension via App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: kAppGroupSuite)
    }

    init() {
        // Prefer App Group store (also written by StartTimerIntent in widget)
        if let stored = sharedDefaults?.object(forKey: kTimerStartKey) as? Double, stored > 0 {
            let date = Date(timeIntervalSince1970: stored)
            startDate = date
            // Start the Live Activity here so a widget-started timer shows on Dynamic Island
            // even when the app was not running at all when the widget fired.
            startLiveActivity(clientName: "", projectName: "", startDate: date)
        } else if let stored = UserDefaults.standard.object(forKey: kTimerStartKey) as? Double, stored > 0 {
            // One-time migration from pre-App Group builds
            let date = Date(timeIntervalSince1970: stored)
            startDate = date
            sharedDefaults?.set(stored, forKey: kTimerStartKey)
            UserDefaults.standard.removeObject(forKey: kTimerStartKey)
            startLiveActivity(clientName: "", projectName: "", startDate: date)
        }
    }

    /// Called on foreground to pick up timers started by the widget extension.
    /// Widget extensions cannot start Live Activities, so this is where we start it.
    func syncFromSharedStore() {
        let stored = sharedDefaults?.double(forKey: kTimerStartKey) ?? 0
        if stored > 0 && startDate == nil {
            let date = Date(timeIntervalSince1970: stored)
            startDate = date
            startLiveActivity(clientName: "", projectName: "", startDate: date)
        } else if stored == 0 && startDate != nil {
            // Timer was stopped externally (edge case — honour it)
            startDate = nil
            client = nil
            project = nil
        }
    }

    func start(client: Client?, project: Project?) {
        self.client = client
        self.project = project
        let now = Date.now
        startDate = now
        sharedDefaults?.set(now.timeIntervalSince1970, forKey: kTimerStartKey)
        startLiveActivity(
            clientName: client?.name ?? "",
            projectName: project?.name ?? "",
            startDate: now
        )
    }

    /// Stops the timer and returns the elapsed hours (rounded to 2 decimal places).
    @discardableResult
    func stop() -> Double {
        let hours = (elapsedHours * 100).rounded() / 100
        startDate = nil
        client = nil
        project = nil
        sharedDefaults?.removeObject(forKey: kTimerStartKey)
        endLiveActivity()
        return hours
    }

    private func startLiveActivity(clientName: String, projectName: String, startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = TimerActivityAttributes(clientName: clientName, projectName: projectName)
        let state = TimerActivityAttributes.ContentState(startDate: startDate)
        try? Activity<TimerActivityAttributes>.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private func endLiveActivity() {
        Task {
            for activity in Activity<TimerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

extension TimeInterval {
    /// Formats an elapsed interval as  H:MM:SS
    var timerFormatted: String {
        let totalSeconds = Int(self)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
