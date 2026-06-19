import ActivityKit
import Foundation
import Observation

private let kAppGroupSuite   = "group.com.garbenTechnologies.BusinessTracker"
private let kRunningSinceKey = "timerRunningSince"   // epoch of current running segment; 0/absent = paused or stopped
private let kAccumulatedKey  = "timerAccumulated"    // banked seconds from prior segments (presence = active session)
private let kPausedKey       = "timerPaused"         // Bool
private let kLegacyStartKey  = "timerStartDate"      // pre-pause builds stored only a start date

enum WidgetAction {
    case startTimer, logTime, logTrip, addExpense, createInvoice
}

/// Shared observable object tracking the active timer, which now supports
/// **pause / resume**. State is persisted to the App Group so it survives
/// backgrounding/relaunch, and mirrored into the Live Activity (whose timer
/// text freezes via `pauseTime` while paused).
@Observable
final class TimerState {
    /// Start of the current *running* segment; nil when paused or stopped.
    var runningSince: Date?
    /// Seconds banked from prior running segments (before the current pause/resume).
    var accumulated: TimeInterval = 0
    /// True when a session exists but is currently paused.
    var isPaused: Bool = false

    var client: Client?
    var project: Project?
    var pendingWidgetAction: WidgetAction?

    /// A session exists (whether running or paused).
    var isActive: Bool { runningSince != nil || isPaused }
    /// Actively counting up right now.
    var isRunning: Bool { runningSince != nil }

    var elapsed: TimeInterval {
        if let since = runningSince { return accumulated + Date.now.timeIntervalSince(since) }
        return accumulated
    }

    var elapsedHours: Double { elapsed / 3600 }

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: kAppGroupSuite) }

    init() {
        let d = sharedDefaults
        if let d, d.object(forKey: kAccumulatedKey) != nil {
            // Restore an in-progress (running or paused) session.
            accumulated = d.double(forKey: kAccumulatedKey)
            let since = d.double(forKey: kRunningSinceKey)
            runningSince = since > 0 ? Date(timeIntervalSince1970: since) : nil
            isPaused = d.bool(forKey: kPausedKey)
            refreshLiveActivity(requestIfNeeded: true)
        } else if let stored = d?.object(forKey: kLegacyStartKey) as? Double, stored > 0 {
            // Migrate a pre-pause running timer from the App Group.
            runningSince = Date(timeIntervalSince1970: stored)
            d?.removeObject(forKey: kLegacyStartKey)
            persist()
            refreshLiveActivity(requestIfNeeded: true)
        } else if let stored = UserDefaults.standard.object(forKey: kLegacyStartKey) as? Double, stored > 0 {
            // One-time migration from pre-App Group builds.
            runningSince = Date(timeIntervalSince1970: stored)
            UserDefaults.standard.removeObject(forKey: kLegacyStartKey)
            persist()
            refreshLiveActivity(requestIfNeeded: true)
        }
    }

    /// Called on foreground. With lock-screen widgets removed, nothing else writes
    /// the timer, so this just honours an external stop (defensive).
    func syncFromSharedStore() {
        guard let d = sharedDefaults else { return }
        if d.object(forKey: kAccumulatedKey) == nil && isActive {
            // Cleared elsewhere — drop our session.
            runningSince = nil
            accumulated = 0
            isPaused = false
            client = nil
            project = nil
        }
    }

    func start(client: Client?, project: Project?) {
        self.client = client
        self.project = project
        accumulated = 0
        runningSince = .now
        isPaused = false
        persist()
        startLiveActivity(clientName: client?.name ?? "", projectName: project?.name ?? "")
    }

    /// Pauses a running timer, banking the elapsed segment.
    func pause() {
        guard let since = runningSince else { return }
        accumulated += Date.now.timeIntervalSince(since)
        runningSince = nil
        isPaused = true
        persist()
        refreshLiveActivity(requestIfNeeded: false)
    }

    /// Resumes a paused timer.
    func resume() {
        guard isPaused else { return }
        runningSince = .now
        isPaused = false
        persist()
        refreshLiveActivity(requestIfNeeded: false)
    }

    /// Stops the timer and returns the elapsed hours (rounded to 2 decimal places).
    @discardableResult
    func stop() -> Double {
        let hours = (elapsedHours * 100).rounded() / 100
        runningSince = nil
        accumulated = 0
        isPaused = false
        client = nil
        project = nil
        clearPersisted()
        endLiveActivity()
        return hours
    }

    // MARK: - Persistence

    private func persist() {
        guard let d = sharedDefaults else { return }
        if isActive {
            d.set(accumulated, forKey: kAccumulatedKey)
            d.set(runningSince?.timeIntervalSince1970 ?? 0, forKey: kRunningSinceKey)
            d.set(isPaused, forKey: kPausedKey)
        } else {
            clearPersisted()
        }
    }

    private func clearPersisted() {
        guard let d = sharedDefaults else { return }
        d.removeObject(forKey: kAccumulatedKey)
        d.removeObject(forKey: kRunningSinceKey)
        d.removeObject(forKey: kPausedKey)
    }

    // MARK: - Live Activity

    /// Effective content state — a synthetic start so `now - startDate == elapsed`,
    /// plus a `pauseTime` that freezes the Live Activity timer while paused.
    private func liveContentState() -> TimerActivityAttributes.ContentState {
        let now = Date.now
        if isPaused {
            return .init(startDate: now.addingTimeInterval(-accumulated), pauseTime: now)
        } else {
            let effectiveStart = (runningSince ?? now).addingTimeInterval(-accumulated)
            return .init(startDate: effectiveStart, pauseTime: nil)
        }
    }

    private func startLiveActivity(clientName: String, projectName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = TimerActivityAttributes(clientName: clientName, projectName: projectName)
        try? Activity<TimerActivityAttributes>.request(
            attributes: attrs,
            content: .init(state: liveContentState(), staleDate: nil),
            pushType: nil
        )
    }

    /// Pushes the current state to the running activity; optionally requests one
    /// if none exists (e.g. after relaunch restoring a session).
    private func refreshLiveActivity(requestIfNeeded: Bool) {
        let activities = Activity<TimerActivityAttributes>.activities
        if activities.isEmpty {
            if requestIfNeeded {
                startLiveActivity(clientName: client?.name ?? "", projectName: project?.name ?? "")
            }
            return
        }
        let state = liveContentState()
        Task {
            for activity in Activity<TimerActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
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
