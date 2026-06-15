import Foundation
import SwiftData

@Model
final class IncomeEntry: SoftDeletable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var source: String = ""
    var amount: Double = 0
    var notes: String = ""
    var client: Client? = nil
    var deletedDate: Date? = nil

    init(date: Date = .now, source: String, amount: Double, notes: String = "", client: Client? = nil) {
        self.id = UUID()
        self.date = date
        self.source = source
        self.amount = amount
        self.notes = notes
        self.client = client
    }
}
