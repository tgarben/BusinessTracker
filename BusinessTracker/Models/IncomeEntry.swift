import Foundation
import SwiftData

@Model
final class IncomeEntry {
    var id: UUID
    var date: Date
    var source: String
    var amount: Decimal
    var notes: String
    var client: Client? = nil

    init(date: Date = .now, source: String, amount: Decimal, notes: String = "", client: Client? = nil) {
        self.id = UUID()
        self.date = date
        self.source = source
        self.amount = amount
        self.notes = notes
        self.client = client
    }
}
