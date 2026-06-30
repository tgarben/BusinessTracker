import SwiftUI
import UIKit

// MARK: - Unified document PDF (invoices + estimates)
//
// One letter-size (612×792pt, 56pt margins) multi-page PDF generator shared by
// invoices and estimates. Everything that differs between the two document types
// is captured in `DocumentPDFSpec`; the layout code below is identical for both,
// so there's a single place to evolve the document design.

/// One row in a document's line-item table.
struct DocPDFRow: Identifiable {
    let id = UUID()
    let description: String
    /// Optional subtitle (e.g. a time entry's date/notes). Nil for plain items.
    let detail: String?
    let qty: String
    let rate: String
    let amount: String
}

/// All the values that vary between an invoice and an estimate.
struct DocumentPDFSpec {
    let business: BusinessInfo
    let logoData: Data?              // optional business logo for the header
    let typeLabel: String            // "INVOICE" / "QUOTE"
    let number: String               // formatted number shown in the header (e.g. "INV-001")
    var fileName: String? = nil      // PDF filename without extension; defaults to `number`

    // Recipient block
    let recipientLabel: String       // "BILL TO" / "QUOTE FOR"
    let recipientName: String
    let recipientCompany: String
    let recipientAddress: String
    let recipientAddress2: String
    let recipientEmail: String
    let recipientPhone: String

    // Header meta (right column): [(label, value)]
    let meta: [(String, String)]

    // Table
    let rateColumnHeader: String     // "RATE" / "UNIT PRICE"
    let rows: [DocPDFRow]

    // Totals
    let subtotal: Double
    let discountAmount: Double
    let taxRate: Double
    let taxAmount: Double
    let total: Double
    let totalLabel: String           // "TOTAL DUE" / "QUOTED TOTAL"

    // Footer
    let paymentTerms: String
    let acceptedPayments: String
    let paymentInstructions: String
    var paymentLink: String = ""     // optional "pay online" URL printed in the payment block
    let notes: String
    let showAcceptanceLine: Bool     // estimates add an Accepted By / Date line
    var showTaxID: Bool = true       // print the business Tax ID / EIN in the footer (per-document toggle)
}

// MARK: - Shared helpers

private func docPDFDivider() -> some View {
    Rectangle().fill(Color(white: 0.85)).frame(height: 1).padding(.horizontal, 56)
}

private func docPDFLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(Color(white: 0.55))
        .tracking(1.5)
}

private func docPDFMeta(_ label: String, _ value: String) -> some View {
    HStack(spacing: 8) {
        Text(label).font(.system(size: 10)).foregroundColor(Color(white: 0.5))
        Text(value).font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
    }
}

private func docPDFTableHeader(rateHeader: String) -> some View {
    VStack(spacing: 0) {
        HStack {
            Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading)
            Text("QTY").frame(width: 50, alignment: .trailing)
            Text(rateHeader).frame(width: 72, alignment: .trailing)
            Text("AMOUNT").frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(Color(white: 0.5))
        .tracking(1)
        .padding(.horizontal, 56)
        .padding(.vertical, 10)
        .background(Color(white: 0.96))

        Rectangle().fill(Color(white: 0.88)).frame(height: 1)
    }
}

private func docPDFRowView(_ row: DocPDFRow) -> some View {
    VStack(spacing: 0) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
                if let detail = row.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.qty).frame(width: 50, alignment: .trailing)
                .font(.system(size: 12)).foregroundColor(Color(white: 0.4))
            Text(row.rate).frame(width: 72, alignment: .trailing)
                .font(.system(size: 12)).foregroundColor(Color(white: 0.4))
            Text(row.amount).frame(width: 80, alignment: .trailing)
                .font(.system(size: 12, weight: .medium)).foregroundColor(.black)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 12)

        Rectangle().fill(Color(white: 0.92)).frame(height: 1)
    }
}

private func docTotalsLine(_ label: String, _ value: String, bold: Bool) -> some View {
    HStack {
        Text(label).font(.system(size: 11)).foregroundColor(Color(white: 0.45))
        Spacer(minLength: 24)
        Text(value).font(.system(size: 11, weight: bold ? .bold : .medium)).foregroundColor(Color(white: 0.2))
    }
    .frame(width: 220)
}

private func docAcceptanceField(_ label: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Rectangle().fill(Color(white: 0.7)).frame(height: 1)
        Text(label)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(Color(white: 0.55))
            .tracking(1)
    }
    .frame(maxWidth: .infinity)
}

private func docContinuedIndicator() -> some View {
    HStack {
        Spacer()
        Text("Continued on next page →")
            .font(.system(size: 9)).foregroundColor(Color(white: 0.6)).italic()
    }
    .padding(.horizontal, 56)
    .padding(.top, 12)
}

// Totals + payment + notes (+ acceptance) footer, shown on the last page only.
private func docPDFFooter(spec: DocumentPDFSpec) -> some View {
    let usd: (Double) -> String = { $0.asCurrency }
    return VStack(alignment: .leading, spacing: 0) {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                docTotalsLine("Subtotal", usd(spec.subtotal), bold: false)
                if spec.discountAmount > 0 {
                    docTotalsLine("Discount", "−\(usd(spec.discountAmount))", bold: false)
                }
                if spec.taxRate > 0 {
                    docTotalsLine("Sales Tax (\(spec.taxRate.formatted(.number.precision(.fractionLength(0...2))))%)", usd(spec.taxAmount), bold: false)
                }
                Rectangle().fill(Color(white: 0.75)).frame(width: 220, height: 1).padding(.vertical, 2)
                HStack {
                    Text(spec.totalLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.45))
                        .tracking(1)
                    Spacer(minLength: 24)
                    Text(usd(spec.total))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(width: 220)
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 14)
        .padding(.bottom, 18)

        let hasPayment = !spec.paymentTerms.isEmpty || !spec.acceptedPayments.isEmpty || !spec.paymentInstructions.isEmpty || !spec.paymentLink.isEmpty
        let showTax = spec.showTaxID && !spec.business.taxID.isEmpty
        if hasPayment || !spec.notes.isEmpty || showTax {
            docPDFDivider()
            VStack(alignment: .leading, spacing: 10) {
                if hasPayment {
                    VStack(alignment: .leading, spacing: 3) {
                        docPDFLabel("PAYMENT")
                        if !spec.paymentTerms.isEmpty {
                            Text("Terms: \(spec.paymentTerms)").font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                        if !spec.acceptedPayments.isEmpty {
                            Text("Accepted: \(spec.acceptedPayments)").font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                        if !spec.paymentLink.isEmpty {
                            Text("Pay online: \(spec.paymentLink)").font(.system(size: 10, weight: .semibold)).foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.85))
                        }
                        if !spec.paymentInstructions.isEmpty {
                            Text(spec.paymentInstructions).font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                    }
                }
                if !spec.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        docPDFLabel("NOTES")
                        Text(spec.notes).font(.system(size: 11)).foregroundColor(Color(white: 0.4))
                    }
                }
                if showTax {
                    Text("Tax ID / EIN: \(spec.business.taxID)")
                        .font(.system(size: 9)).foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 14)
        }

        if spec.showAcceptanceLine {
            docPDFDivider().padding(.top, 14)
            HStack(spacing: 40) {
                docAcceptanceField("ACCEPTED BY")
                docAcceptanceField("DATE")
            }
            .padding(.horizontal, 56)
            .padding(.top, 18)
        }
    }
}

// MARK: - Page 1 layout

private struct DocumentFirstPageLayout: View {
    let spec: DocumentPDFSpec
    let rows: [DocPDFRow]
    let isLastPage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — business info + type label + number
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if let logo = spec.logoData, let image = UIImage(data: logo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 52, alignment: .leading)
                            .padding(.bottom, 6)
                    }
                    Text(spec.business.name.isEmpty ? "Freelancer" : spec.business.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    if !spec.business.address.isEmpty {
                        Text(spec.business.address)
                            .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !spec.business.address2.isEmpty {
                        Text(spec.business.address2)
                            .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    ForEach(spec.business.contactLines, id: \.self) { line in
                        Text(line).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(spec.typeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                        .tracking(2)
                    Text(spec.number)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(white: 0.83))
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 56)
            .padding(.bottom, 24)

            docPDFDivider()

            // Recipient + meta
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    docPDFLabel(spec.recipientLabel)
                    Text(spec.recipientName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    if !spec.recipientCompany.isEmpty {
                        Text(spec.recipientCompany).font(.system(size: 11)).foregroundColor(Color(white: 0.4))
                    }
                    if !spec.recipientAddress.isEmpty {
                        Text(spec.recipientAddress).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !spec.recipientAddress2.isEmpty {
                        Text(spec.recipientAddress2).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    if !spec.recipientEmail.isEmpty {
                        Text(spec.recipientEmail).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    if !spec.recipientPhone.isEmpty {
                        Text(spec.recipientPhone).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(spec.meta, id: \.0) { pair in
                        docPDFMeta(pair.0, pair.1)
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 24)

            docPDFTableHeader(rateHeader: spec.rateColumnHeader)

            ForEach(rows) { docPDFRowView($0) }

            if isLastPage {
                docPDFFooter(spec: spec)
            } else {
                docContinuedIndicator()
            }

            Spacer(minLength: 40)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - Continuation page layout

private struct DocumentContinuationPageLayout: View {
    let spec: DocumentPDFSpec
    let rows: [DocPDFRow]
    let pageNumber: Int
    let totalPages: Int
    let isLastPage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.business.name.isEmpty ? "Freelancer" : spec.business.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                    Text(spec.number)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Text("Page \(pageNumber) of \(totalPages)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.6))
            }
            .padding(.horizontal, 56)
            .padding(.top, 36)
            .padding(.bottom, 16)

            docPDFTableHeader(rateHeader: spec.rateColumnHeader)

            ForEach(rows) { docPDFRowView($0) }

            if isLastPage {
                docPDFFooter(spec: spec)
            } else {
                docContinuedIndicator()
            }

            Spacer(minLength: 40)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - Generation (multi-page)

@MainActor
func makeDocumentPDF(spec: DocumentPDFSpec) -> URL? {
    let allRows = spec.rows

    // Page 1 has a taller header + recipient overhead; later pages are compact.
    let firstPageMax = 6
    let contPageMax  = 10

    var pageRows: [[DocPDFRow]] = []
    if allRows.count <= firstPageMax {
        pageRows = [allRows]
    } else {
        pageRows.append(Array(allRows.prefix(firstPageMax)))
        var remaining = Array(allRows.dropFirst(firstPageMax))
        while !remaining.isEmpty {
            pageRows.append(Array(remaining.prefix(contPageMax)))
            remaining = Array(remaining.dropFirst(contPageMax))
        }
    }

    let baseName = (spec.fileName?.isEmpty == false ? spec.fileName! : spec.number)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(baseName).pdf")

    var box = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData),
          let ctx = CGContext(consumer: consumer, mediaBox: &box, nil)
    else { return nil }

    let totalPages = pageRows.count

    for (idx, rows) in pageRows.enumerated() {
        let isLast = idx == totalPages - 1
        let renderer: ImageRenderer<AnyView>
        if idx == 0 {
            renderer = ImageRenderer(content: AnyView(DocumentFirstPageLayout(
                spec: spec, rows: rows, isLastPage: isLast
            )))
        } else {
            renderer = ImageRenderer(content: AnyView(DocumentContinuationPageLayout(
                spec: spec, rows: rows,
                pageNumber: idx + 1, totalPages: totalPages, isLastPage: isLast
            )))
        }
        renderer.proposedSize = ProposedViewSize(width: 612, height: 792)
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
    }

    ctx.closePDF()
    try? pdfData.write(to: url)
    return url
}

// MARK: - Document naming

/// Builds share filenames and in-app labels for invoices/quotes so a shared PDF
/// is identifiable (e.g. `2026_06_19_ClancyBros_INV_001`) while the in-app label
/// still carries the client name instead of a bare number.
enum DocumentNaming {
    /// Share filename (no extension), e.g. `2026_06_19_ClancyBros_INV_001`.
    static func fileName(date: Date, clientName: String?, number: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy_MM_dd"
        let datePart = f.string(from: date)
        let namePart = condensedClient(clientName)
        let numPart = number
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "")
        return [datePart, namePart, numPart].filter { !$0.isEmpty }.joined(separator: "_")
    }

    /// In-app label, e.g. `INV-001 · Clancy Bros` (falls back to just the number).
    static func displayTitle(clientName: String?, number: String) -> String {
        let name = (clientName ?? "").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? number : "\(number) · \(name)"
    }

    /// "Clancy Bros" → "ClancyBros"; strips punctuation, CamelCases words.
    private static func condensedClient(_ name: String?) -> String {
        guard let name else { return "" }
        let cleaned = name.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }
}
