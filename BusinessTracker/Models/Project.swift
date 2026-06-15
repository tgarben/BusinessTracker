import Foundation
import SwiftData

@Model
final class Project {
    var name: String = ""
    var hourlyRate: Double = 0
    var client: Client?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project)
    var timeEntries: [TimeEntry]? = nil

    @Relationship(deleteRule: .nullify, inverse: \TimePreset.project)
    var timePresets: [TimePreset]? = nil

    init(name: String, hourlyRate: Double = 0, client: Client? = nil) {
        self.name = name
        self.hourlyRate = hourlyRate
        self.client = client
    }
}
