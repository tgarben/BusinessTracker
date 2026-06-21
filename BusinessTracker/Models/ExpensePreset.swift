import Foundation
import SwiftData

/// A saved expense template. Tapping it in `AddExpenseView` pre-fills category, amount
/// (when set), and notes. `amount` is optional — some presets are category+notes templates
/// where the amount varies each time. No relationships — standalone, CloudKit-safe.
@Model
final class ExpensePreset {
    var name: String = ""
    var amount: Double? = nil          // nil = no fixed amount (user types it each time)
    var category: String = ""
    var notes: String = ""
    var sortOrder: Int = 0
    /// When true, tapping this preset in the Expenses speed-dial logs it immediately
    /// (only takes effect for presets with a fixed `amount`). Per-preset replacement
    /// for the old global `expense_presetInstantSave` toggle.
    var instantLog: Bool = false

    init(name: String, amount: Double? = nil, category: String = "", notes: String = "", sortOrder: Int = 0, instantLog: Bool = false) {
        self.name = name
        self.amount = amount
        self.category = category
        self.notes = notes
        self.sortOrder = sortOrder
        self.instantLog = instantLog
    }
}
