import Foundation
import SwiftData

@Model
final class IncomeEntry {
    var id: UUID
    var date: Date
    var source: String
    var amount: Decimal
    var notes: String

    init(date: Date = .now, source: String, amount: Decimal, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.source = source
        self.amount = amount
        self.notes = notes
    }
}
