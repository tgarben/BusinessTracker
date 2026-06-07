import Foundation
import SwiftData

@Model
final class Client {
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    var projects: [Project] = []

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.client)
    var timeEntries: [TimeEntry] = []

    init(name: String) {
        self.name = name
    }
}
