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
    var discountAmount: Double = 0            // discount applied before tax — a flat $ amount, or a percent when `discountIsPercent`
    var discountIsPercent: Bool = false       // when true, `discountAmount` is a percent of the subtotal
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

    var formattedNumber: String { Invoice.formatted(number: invoiceNumber, issueDate: issueDate) }

    /// Share filename (no extension), e.g. `2026_06_19_ClancyBros_INV_001`.
    var shareFileName: String {
        DocumentNaming.fileName(date: issueDate, clientName: client?.name, number: formattedNumber)
    }

    /// In-app label that includes the client name, e.g. `INV-001 · Clancy Bros`.
    var displayTitle: String {
        DocumentNaming.displayTitle(clientName: client?.name, number: formattedNumber)
    }

    /// Formats a document number using the user's configurable prefix
    /// (`doc_invoicePrefix`, default "INV-") and optional per-year reset
    /// (`doc_numberResetYearly`, which inserts the year, e.g. "INV-2026-001").
    static func formatted(number: Int, issueDate: Date) -> String {
        let d = UserDefaults.standard
        let prefix = (d.string(forKey: "doc_invoicePrefix")?.isEmpty == false)
            ? d.string(forKey: "doc_invoicePrefix")! : "INV-"
        let padded = String(format: "%03d", number)
        if d.bool(forKey: "doc_numberResetYearly") {
            let year = Calendar.current.component(.year, from: issueDate)
            return "\(prefix)\(year)-\(padded)"
        }
        return "\(prefix)\(padded)"
    }

    /// Pre-tax, pre-discount sum of all charges (time entries + manual line items + legacy extra).
    var subtotal: Double {
        let timeTotal = (timeEntries ?? []).reduce(0.0) { $0 + $1.earnings }
        let itemsTotal = (lineItems ?? []).reduce(0.0) { $0 + $1.lineTotal }
        return timeTotal + itemsTotal + additionalAmount
    }

    /// The discount as an actual dollar figure (resolves the percent case).
    var effectiveDiscount: Double { discountIsPercent ? subtotal * (discountAmount / 100) : discountAmount }
    var discountedSubtotal: Double { max(0, subtotal - effectiveDiscount) }
    var taxAmount: Double { discountedSubtotal * (taxRate / 100) }

    /// Final amount due.
    var total: Double { discountedSubtotal + taxAmount }

    /// Unpaid and past its due date (date-only comparison; due *today* is not overdue).
    var isOverdue: Bool {
        !isPaid && deletedDate == nil && dueDate < Calendar.current.startOfDay(for: .now)
    }

    /// Whole days past the due date (0 if not overdue).
    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: dueDate), to: cal.startOfDay(for: .now)).day ?? 0
    }

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
