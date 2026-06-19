import ActivityKit
import Foundation

// Shared with FreelancedWidget/FreelancedLiveActivity.swift — keep both in sync.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        /// When set, the Live Activity timer freezes here (paused). Nil = running.
        var pauseTime: Date? = nil
    }
    var clientName: String
    var projectName: String
}
