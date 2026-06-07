import Foundation
import SwiftData

@Model
final class Client {
    var name: String
    var defaultHourlyRate: Decimal

    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    var projects: [Project] = []

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.client)
    var timeEntries: [TimeEntry] = []

    init(name: String, defaultHourlyRate: Decimal) {
        self.name = name
        self.defaultHourlyRate = defaultHourlyRate
    }
}
