import Foundation
import SwiftData

/// A saved one-tap preset for the timer stop sheet.
/// Links a display name to an optional client + project so the user
/// can save a time entry instantly with zero additional input.
@Model
final class TimePreset {
    var name: String
    var client: Client?
    var project: Project?
    var sortOrder: Int

    init(name: String, client: Client? = nil, project: Project? = nil, sortOrder: Int = 0) {
        self.name = name
        self.client = client
        self.project = project
        self.sortOrder = sortOrder
    }
}
