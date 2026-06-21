import ActivityKit
import Foundation

/// Live Activity attributes for a manually-tracked mileage trip.
/// Shared with FreelancedWidget/TripLiveActivity.swift — keep both in sync.
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Synthetic effective start so `now - startDate == elapsed` (accounts for pauses).
        var startDate: Date
        /// Live distance in miles.
        var miles: Double
        /// When set, the elapsed timer freezes here (paused). Nil = running.
        var pauseTime: Date? = nil
    }
}
