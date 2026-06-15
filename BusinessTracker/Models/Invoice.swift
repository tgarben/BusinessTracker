import Foundation
import SwiftData

@Model
final class Invoice: SoftDeletable {
    var invoiceNumber: Int = 0
    var issueDate: Date = Date.now
    var dueDate: Date = Date.now
    var notes: String = ""
    var isPaid: Bool = false
    var paidDate: Date? = nil
    var additionalAmount: Double = 0          // legacy single extra charge (kept for migration)
    var additionalDescription: String = ""
    var deletedDate: Date? = nil

    // Totals adjustments
    var discountAmount: Double = 0            // flat discount applied before tax
    var taxRate: Double = 0                   // sales tax percent applied to discounted subtotal

    // Payment & terms
    var paymentTerms: String = ""             // e.g. "Net 30", "Due Upon Receipt"
    var paymentInstructions: String = ""
    var acceptedPayments: String = ""
    var poNumber: String = ""

    var client: Client? = nil

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.invoice)
    var timeEntries: [TimeEntry]? = nil

    @Relationship(deleteRule: .cascade, inverse: \InvoiceLineItem.invoice)
    var lineItems: [InvoiceLineItem]? = nil

    var formattedNumber: String { String(format: "INV-%03d", invoiceNumber) }

    /// Pre-tax, pre-discount sum of all charges (time entries + manual line items + legacy extra).
    var subtotal: Double {
        let timeTotal = (timeEntries ?? []).reduce(0.0) { $0 + $1.earnings }
        let itemsTotal = (lineItems ?? []).reduce(0.0) { $0 + $1.lineTotal }
        return timeTotal + itemsTotal + additionalAmount
    }

    var discountedSubtotal: Double { max(0, subtotal - discountAmount) }
    var taxAmount: Double { discountedSubtotal * (taxRate / 100) }

    /// Final amount due.
    var total: Double { discountedSubtotal + taxAmount }

    init(
        invoiceNumber: Int,
        issueDate: Date = .now,
        dueDate: Date,
        client: Client? = nil,
        notes: String = ""
    ) {
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.client = client
        self.notes = notes
    }
}
