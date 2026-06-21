import Foundation
import SwiftData
import SwiftUI

/// Lifecycle state of a quote/estimate. Stored as a raw `String` on the model
/// (CloudKit-safe); the enum is the UI-facing helper for labels/colors.
enum QuoteStatus: String, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case accepted = "Accepted"
    case declined = "Declined"
    case expired = "Expired"

    var icon: String {
        switch self {
        case .draft:    return "pencil.circle.fill"
        case .sent:     return "paperplane.circle.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark"
        case .expired:  return "clock.badge.exclamationmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .draft:    return .gray
        case .sent:     return .blue
        case .accepted: return .green
        case .declined: return .red
        case .expired:  return .orange
        }
    }
}

/// A quote / estimate — the pre-sale counterpart to an `Invoice`. Manual line
/// items only (no time-entry billing, since the work hasn't happened yet).
/// Mirrors `Invoice`'s totals math so the same business header, client billing
/// details, and PDF approach can be reused, and an accepted quote can be
/// converted into an `Invoice`.
@Model
final class Quote: SoftDeletable {
    var quoteNumber: Int = 0
    var issueDate: Date = Date.now
    var validUntil: Date = Date.now
    var notes: String = ""

    /// Raw `QuoteStatus` value. Defaults to Draft.
    var status: String = QuoteStatus.draft.rawValue

    /// Invoice number this quote was converted into (0 = not converted).
    var convertedInvoiceNumber: Int = 0

    var deletedDate: Date? = nil

    // Totals adjustments (mirror Invoice)
    var discountAmount: Double = 0
    var discountIsPercent: Bool = false       // when true, `discountAmount` is a percent of the subtotal
    var taxRate: Double = 0

    // Terms (carried over to the invoice on conversion)
    var paymentTerms: String = ""
    var paymentInstructions: String = ""
    var acceptedPayments: String = ""
    var poNumber: String = ""

    var client: Client? = nil

    @Relationship(deleteRule: .cascade, inverse: \QuoteLineItem.quote)
    var lineItems: [QuoteLineItem]? = nil

    var formattedNumber: String { Quote.formatted(number: quoteNumber, issueDate: issueDate) }

    /// Share filename (no extension), e.g. `2026_06_19_ClancyBros_QUO_001`.
    var shareFileName: String {
        DocumentNaming.fileName(date: issueDate, clientName: client?.name, number: formattedNumber)
    }

    /// In-app label that includes the client name, e.g. `QUO-001 · Clancy Bros`.
    var displayTitle: String {
        DocumentNaming.displayTitle(clientName: client?.name, number: formattedNumber)
    }

    /// Formats a quote number using the user's configurable prefix
    /// (`doc_quotePrefix`, default "QUO-") and optional per-year reset
    /// (`doc_numberResetYearly`, which inserts the year, e.g. "QUO-2026-001").
    static func formatted(number: Int, issueDate: Date) -> String {
        let d = UserDefaults.standard
        let prefix = (d.string(forKey: "doc_quotePrefix")?.isEmpty == false)
            ? d.string(forKey: "doc_quotePrefix")! : "QUO-"
        let padded = String(format: "%03d", number)
        if d.bool(forKey: "doc_numberResetYearly") {
            let year = Calendar.current.component(.year, from: issueDate)
            return "\(prefix)\(year)-\(padded)"
        }
        return "\(prefix)\(padded)"
    }

    /// Pre-tax, pre-discount sum of all line items.
    var subtotal: Double {
        (lineItems ?? []).reduce(0.0) { $0 + $1.lineTotal }
    }

    /// The discount as an actual dollar figure (resolves the percent case).
    var effectiveDiscount: Double { discountIsPercent ? subtotal * (discountAmount / 100) : discountAmount }
    var discountedSubtotal: Double { max(0, subtotal - effectiveDiscount) }
    var taxAmount: Double { discountedSubtotal * (taxRate / 100) }

    /// Final quoted total.
    var total: Double { discountedSubtotal + taxAmount }

    /// The stored status, falling back to Draft for unknown values.
    var statusValue: QuoteStatus { QuoteStatus(rawValue: status) ?? .draft }

    var isConverted: Bool { convertedInvoiceNumber > 0 }

    /// Display status — surfaces "Expired" when an open quote's `validUntil` has
    /// passed without being accepted/declined, without mutating the stored value.
    var displayStatus: QuoteStatus {
        let s = statusValue
        if (s == .draft || s == .sent),
           validUntil < Calendar.current.startOfDay(for: .now) {
            return .expired
        }
        return s
    }

    init(
        quoteNumber: Int,
        issueDate: Date = .now,
        validUntil: Date,
        client: Client? = nil,
        notes: String = ""
    ) {
        self.quoteNumber = quoteNumber
        self.issueDate = issueDate
        self.validUntil = validUntil
        self.client = client
        self.notes = notes
    }
}
