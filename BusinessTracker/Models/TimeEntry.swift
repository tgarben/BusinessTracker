import Foundation
import SwiftData

@Model
final class TimeEntry: SoftDeletable {
    var date: Date = Date.now
    var client: Client?
    var project: Project?
    var hours: Double = 0
    var hourlyRate: Double = 0
    var notes: String = ""
    var invoice: Invoice? = nil
    var deletedDate: Date? = nil

    var earnings: Double { hours * hourlyRate }

    init(
        date: Date = .now,
        client: Client? = nil,
        project: Project? = nil,
        hours: Double,
        hourlyRate: Double,
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
