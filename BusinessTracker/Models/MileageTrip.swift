import Foundation
import SwiftData
import CoreLocation

@Model
final class MileageTrip: SoftDeletable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var startLocation: String = ""
    var endLocation: String = ""
    var miles: Double = 0
    var purpose: String = ""
    var notes: String = ""
    var waypoints: [String] = []   // intermediate stops between start and end (in order)
    var startAddress: String = ""  // full address for export (startLocation is the short display label)
    var endAddress: String = ""
    var deletedDate: Date? = nil

    /// Optional client this trip is associated with (for per-client reports / tax).
    /// Inverse declared on `Client.mileageTrips` (nullify).
    var client: Client? = nil

    // Automatic Drive Detection (Auto-Mileage, Phase 0). Auto-logged trips start
    // as needs-review so the user can categorize/confirm/delete them.
    var isAutoDetected: Bool = false
    var needsReview: Bool = false
    // Captured GPS route (Phase 2), flattened as [lat, lon, lat, lon, …] — empty
    // for manual/legacy trips. Downsampled to keep the CloudKit field small.
    var routePoints: [Double] = []

    /// The captured route as coordinates (empty when none recorded).
    var routeCoordinates: [CLLocationCoordinate2D] {
        guard routePoints.count >= 4 else { return [] }
        var coords: [CLLocationCoordinate2D] = []
        var i = 0
        while i + 1 < routePoints.count {
            coords.append(CLLocationCoordinate2D(latitude: routePoints[i], longitude: routePoints[i + 1]))
            i += 2
        }
        return coords
    }

    /// Full address if captured, otherwise the display label (older trips).
    var startAddressForExport: String { startAddress.isEmpty ? startLocation : startAddress }
    var endAddressForExport: String { endAddress.isEmpty ? endLocation : endAddress }

    /// Full ordered route: start → waypoints… → end (empties dropped).
    var allStops: [String] {
        ([startLocation] + waypoints + [endLocation]).filter { !$0.isEmpty }
    }

    /// "Start → Via → End" for display.
    var routeDescription: String {
        allStops.joined(separator: " → ")
    }

    /// IRS standard mileage rate — stored in UserDefaults, editable in Settings
    static let defaultRatePerMile: Double = 0.70
    static var ratePerMile: Double {
        let stored = UserDefaults.standard.double(forKey: "mileage_ratePerMile")
        return stored > 0 ? stored : defaultRatePerMile
    }

    var reimbursementAmount: Double { miles * MileageTrip.ratePerMile }

    init(date: Date = .now, startLocation: String, endLocation: String, miles: Double, purpose: String, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.miles = miles
        self.purpose = purpose
        self.notes = notes
    }
}
