import Foundation
import SwiftData

/// A manually-entered line on an invoice (product or service). Separate from time-entry
/// billing — an invoice's total combines linked time entries + these line items.
@Model
final class InvoiceLineItem {
    var itemDescription: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var sortOrder: Int = 0
    var invoice: Invoice? = nil

    var lineTotal: Double { quantity * unitPrice }

    init(itemDescription: String = "", quantity: Double = 1, unitPrice: Double = 0, sortOrder: Int = 0, invoice: Invoice? = nil) {
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.sortOrder = sortOrder
        self.invoice = invoice
    }
}
