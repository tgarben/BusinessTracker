import Foundation
import SwiftData

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
