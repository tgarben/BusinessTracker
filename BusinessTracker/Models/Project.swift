import Foundation
import SwiftData

@Model
final class Project {
    var name: String
    var hourlyRate: Decimal
    var client: Client?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project)
    var timeEntries: [TimeEntry] = []

    init(name: String, hourlyRate: Decimal = 0, client: Client? = nil) {
        self.name = name
        self.hourlyRate = hourlyRate
        self.client = client
    }
}
