import Foundation
import SwiftData

@Model
final class TimePreset {
    var name: String
    var client: Client?
    var project: Project?
    var sortOrder: Int

    /// If set, overrides the project's hourly rate when saving via this preset.
    var hourlyRateOverride: Decimal?

    /// Pre-filled notes template. Appears in the entry's notes field; still editable after save.
    var notesTemplate: String

    /// The effective rate: override if set, otherwise falls back to the project rate.
    var effectiveRate: Decimal {
        hourlyRateOverride ?? project?.hourlyRate ?? 0
    }

    init(
        name: String,
        client: Client? = nil,
        project: Project? = nil,
        sortOrder: Int = 0,
        hourlyRateOverride: Decimal? = nil,
        notesTemplate: String = ""
    ) {
        self.name = name
        self.client = client
        self.project = project
        self.sortOrder = sortOrder
        self.hourlyRateOverride = hourlyRateOverride
        self.notesTemplate = notesTemplate
    }
}
