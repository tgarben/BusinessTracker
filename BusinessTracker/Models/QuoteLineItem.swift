import Foundation
import SwiftData

/// A manually-entered line on a quote (product or service). Mirrors
/// `InvoiceLineItem` — kept as a distinct type because SwiftData relationships
/// need a single owning inverse, and a quote's items are copied into fresh
/// `InvoiceLineItem`s when the quote is converted to an invoice.
@Model
final class QuoteLineItem {
    var itemDescription: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var sortOrder: Int = 0
    var quote: Quote? = nil

    var lineTotal: Double { quantity * unitPrice }

    init(itemDescription: String = "", quantity: Double = 1, unitPrice: Double = 0, sortOrder: Int = 0, quote: Quote? = nil) {
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.sortOrder = sortOrder
        self.quote = quote
    }
}
