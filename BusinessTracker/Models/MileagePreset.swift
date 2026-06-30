import Foundation
import SwiftData

/// A saved route template. Tapping it in `LogTripView` pre-fills the start/end/purpose
/// (and optional client) and triggers a distance calculation.
@Model
final class MileagePreset {
    var name: String = ""
    var startLocation: String = ""
    var endLocation: String = ""
    var purpose: String = ""
    var notes: String = ""
    var sortOrder: Int = 0

    /// Optional client this preset's trips are for — pre-fills the trip's client.
    /// Inverse declared on `Client.mileagePresets` (nullify).
    var client: Client? = nil

    init(name: String, startLocation: String = "", endLocation: String = "", purpose: String = "", notes: String = "", sortOrder: Int = 0, client: Client? = nil) {
        self.name = name
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.purpose = purpose
        self.notes = notes
        self.sortOrder = sortOrder
        self.client = client
    }
}
