import Foundation
import SwiftData

@Model
final class Expense: SoftDeletable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var amount: Double = 0
    var category: String = ""
    var notes: String = ""
    var receiptImageData: Data? = nil     // legacy single-image field; kept for migration
    var receiptImagesData: [Data] = []   // multi-image storage
    var client: Client?
    var deletedDate: Date? = nil

    init(date: Date = .now, amount: Double, category: String, notes: String = "", client: Client? = nil) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category
        self.notes = notes
        self.receiptImagesData = []
        self.client = client
    }
}

extension Expense {
    static let categories = [
        "Supplies", "Equipment", "Software", "Travel", "Meals",
        "Marketing", "Utilities", "Rent", "Insurance", "Other"
    ]

    static func categoryIcon(_ category: String) -> String {
        switch category {
        case "Supplies":   return "shippingbox.fill"
        case "Equipment":  return "wrench.and.screwdriver.fill"
        case "Software":   return "laptopcomputer"
        case "Travel":     return "airplane"
        case "Meals":      return "fork.knife"
        case "Marketing":  return "megaphone.fill"
        case "Utilities":  return "bolt.fill"
        case "Rent":       return "building.2.fill"
        case "Insurance":  return "shield.fill"
        default:           return "creditcard.fill"
        }
    }

    static func categoryColor(_ category: String) -> String {
        switch category {
        case "Supplies":   return "orange"
        case "Equipment":  return "gray"
        case "Software":   return "blue"
        case "Travel":     return "teal"
        case "Meals":      return "green"
        case "Marketing":  return "pink"
        case "Utilities":  return "yellow"
        case "Rent":       return "brown"
        case "Insurance":  return "indigo"
        default:           return "secondary"
        }
    }
}
