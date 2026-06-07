import Foundation
import SwiftData

@Model
final class Project {
    var name: String
    var client: Client?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project)
    var timeEntries: [TimeEntry] = []

    init(name: String, client: Client? = nil) {
        self.name = name
        self.client = client
    }
}
