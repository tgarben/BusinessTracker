import Foundation
import SwiftData

@Model
final class Client {
    var name: String
    var photoData: Data? = nil

    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    var projects: [Project] = []

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.client)
    var timeEntries: [TimeEntry] = []

    @Relationship(deleteRule: .nullify, inverse: \IncomeEntry.client)
    var incomeEntries: [IncomeEntry] = []

    init(name: String) {
        self.name = name
    }
}
