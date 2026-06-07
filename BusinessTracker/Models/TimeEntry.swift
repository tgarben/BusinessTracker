import Foundation
import SwiftData

@Model
final class TimeEntry {
    var date: Date
    var client: Client?
    var project: Project?
    var hours: Double
    var hourlyRate: Decimal
    var notes: String

    var earnings: Decimal { Decimal(hours) * hourlyRate }

    init(
        date: Date = .now,
        client: Client? = nil,
        project: Project? = nil,
        hours: Double,
        hourlyRate: Decimal,
        notes: String = ""
    ) {
        self.date = date
        self.client = client
        self.project = project
        self.hours = hours
        self.hourlyRate = hourlyRate
        self.notes = notes
    }
}
