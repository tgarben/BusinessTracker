import ActivityKit
import Foundation

// Shared with FreelancedWidget/FreelancedLiveActivity.swift — keep both in sync.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
    }
    var clientName: String
    var projectName: String
}
