import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var date: Date
    var amount: Decimal
    var category: String
    var notes: String
    var receiptImageData: Data?

    init(date: Date = .now, amount: Decimal, category: String, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category
        self.notes = notes
    }
}

extension Expense {
    static let categories = [
        "Supplies", "Equipment", "Software", "Travel", "Meals",
        "Marketing", "Utilities", "Rent", "Insurance", "Other"
    ]
}
