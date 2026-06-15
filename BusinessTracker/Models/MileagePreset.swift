import Foundation
import SwiftData

/// A saved route template. Tapping it in `LogTripView` pre-fills the start/end/purpose
/// and triggers a distance calculation. No relationships — standalone, CloudKit-safe.
@Model
final class MileagePreset {
    var name: String = ""
    var startLocation: String = ""
    var endLocation: String = ""
    var purpose: String = ""
    var notes: String = ""
    var sortOrder: Int = 0

    init(name: String, startLocation: String = "", endLocation: String = "", purpose: String = "", notes: String = "", sortOrder: Int = 0) {
        self.name = name
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.purpose = purpose
        self.notes = notes
        self.sortOrder = sortOrder
    }
}
