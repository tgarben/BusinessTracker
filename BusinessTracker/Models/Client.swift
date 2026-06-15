import Foundation
import SwiftData

@Model
final class Client: SoftDeletable {
    var name: String = ""
    var photoData: Data? = nil
    var deletedDate: Date? = nil

    // Customer billing details (used on invoices)
    var companyName: String = ""
    var billingAddress: String = ""
    var email: String = ""
    var phone: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    var projects: [Project]? = nil

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.client)
    var timeEntries: [TimeEntry]? = nil

    @Relationship(deleteRule: .nullify, inverse: \IncomeEntry.client)
    var incomeEntries: [IncomeEntry]? = nil

    @Relationship(deleteRule: .nullify, inverse: \Expense.client)
    var expenses: [Expense]? = nil

    @Relationship(deleteRule: .nullify, inverse: \TimePreset.client)
    var timePresets: [TimePreset]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Invoice.client)
    var invoices: [Invoice]? = nil

    init(name: String) {
        self.name = name
    }
}
