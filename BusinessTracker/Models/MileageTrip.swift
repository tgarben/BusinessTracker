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

    /// IRS standard mileage rate — update each tax year
    static let ratePerMile: Double = 0.70

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
