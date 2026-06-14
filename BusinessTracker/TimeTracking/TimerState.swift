import Foundation
import Observation

private let kTimerStartKey = "timerStartDate"

enum WidgetAction {
    case startTimer, logTime, logTrip, addExpense
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

    init() {
        if let stored = UserDefaults.standard.object(forKey: kTimerStartKey) as? Double {
            startDate = Date(timeIntervalSince1970: stored)
        }
    }

    func start(client: Client?, project: Project?) {
        self.client = client
        self.project = project
        let now = Date.now
        startDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: kTimerStartKey)
    }

    /// Stops the timer and returns the elapsed hours (rounded to 2 decimal places).
    @discardableResult
    func stop() -> Double {
        let hours = (elapsedHours * 100).rounded() / 100
        startDate = nil
        client = nil
        project = nil
        UserDefaults.standard.removeObject(forKey: kTimerStartKey)
        return hours
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
