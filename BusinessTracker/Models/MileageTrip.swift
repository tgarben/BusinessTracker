import Foundation
import SwiftData

@Model
final class MileageTrip {
    var id: UUID
    var date: Date
    var startLocation: String
    var endLocation: String
    var miles: Double
    var purpose: String
    var notes: String

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
