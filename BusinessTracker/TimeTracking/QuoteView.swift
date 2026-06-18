import SwiftUI
import SwiftData

// MARK: - Quote list row

struct QuoteRow: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(quote.formattedNumber)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(quote.total.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.teal.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 12)
                Text(quote.issueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text("Valid to \(quote.validUntil.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let s = quote.displayStatus
        return Text(s.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(s.color)
    }
}

// MARK: - Create quote sheet

struct CreateQuoteView: View {
    let client: Client
    var body: some View {
        NavigationStack { CreateQuoteContent(client: client) }
    }
}

// MARK: - Quote quick action sheet (client picker → create quote)

struct QuoteQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients Yet",
                        systemImage: "person.2",
                        description: Text("Add clients from the Clients tab before creating a quote.")
                    )
                } else {
                    List(clients) { client in
                        NavigationLink(client.name) {
                            CreateQuoteContent(client: client, onComplete: { dismiss() })
                        }
                    }
                }
            }
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Create quote form content

/// A draft manual line item being edited in the create-quote form.
private struct DraftQuoteLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantityText: String = "1"
    var unitPriceText: String = ""

    var quantity: Double { Double(quantityText) ?? 0 }
    var unitPrice: Double { Double(unitPriceText) ?? 0 }
    var lineTotal: Double { quantity * unitPrice }
    var isValid: Bool { !description.trimmingCharacters(in: .whitespaces).isEmpty && lineTotal != 0 }
}

private struct CreateQuoteContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let client: Client
    /// Closes the whole flow after creating (the quick-action picker passes a
    /// closure that dismisses the entire sheet rather than just popping).
    var onComplete: (() -> Void)? = nil

    @Query(filter: #Predicate<Quote> { $0.deletedDate == nil }, sort: \Quote.quoteNumber, order: .reverse) private var allQuotes: [Quote]

    // Business defaults reused from invoicing
    @AppStorage("business_defaultTaxRate") private var defaultTaxRate: Double = 0
    @AppStorage("business_defaultPaymentTerms") private var defaultPaymentTerms: String = "Due Upon Receipt"
    @AppStorage("business_acceptedPayments") private var defaultAcceptedPayments: String = ""
    @AppStorage("business_paymentInstructions") private var defaultPaymentInstructions: String = ""

    @State private var quoteNumberText: String = ""
    @State private var issueDate: Date = .now
    @State private var validUntil: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var drafts: [DraftQuoteLineItem] = [DraftQuoteLineItem()]
    @State private var discountText: String = ""
    @State private var taxRateText: String = ""
    @State private var paymentTerms: String = "Due Upon Receipt"
    @State private var acceptedPayments: String = ""
    @State private var paymentInstructions: String = ""
    @State private var poNumber: String = ""
    @State private var notes: String = ""
    @State private var didPrefill = false
    @State private var preview: PreviewDoc?

    @AppStorage("doc_numberResetYearly") private var resetYearly = false

    private let paymentTermsOptions = ["Due Upon Receipt", "Net 15", "Net 30", "Net 45", "Net 60"]

    /// Next estimate number — highest existing + 1, scoped to the current year
    /// when per-year reset is on.
    private var nextNumber: Int {
        if resetYearly {
            let year = Calendar.current.component(.year, from: .now)
            let inYear = allQuotes.filter { Calendar.current.component(.year, from: $0.issueDate) == year }
            return (inYear.map(\.quoteNumber).max() ?? 0) + 1
        }
        return (allQuotes.map(\.quoteNumber).max() ?? 0) + 1
    }

    private var itemsTotal: Double { drafts.reduce(0) { $0 + $1.lineTotal } }
    private var subtotal: Double { itemsTotal }
    private var discount: Double { Double(discountText) ?? 0 }
    private var taxRate: Double { Double(taxRateText) ?? 0 }
    private var discountedSubtotal: Double { max(0, subtotal - discount) }
    private var taxAmount: Double { discountedSubtotal * (taxRate / 100) }
    private var quoteTotal: Double { discountedSubtotal + taxAmount }

    private var canSave: Bool {
        !quoteNumberText.isEmpty && drafts.contains(where: \.isValid)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Quote For", value: client.name)
                if !client.companyName.isEmpty {
                    LabeledContent("Company", value: client.companyName)
                }
                if client.billingAddress.isEmpty || client.email.isEmpty {
                    Text("Tip: add this client's billing address, email & phone in their profile to include them on the estimate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Estimate Details") {
                HStack {
                    Text("Estimate #")
                    Spacer()
                    TextField("001", text: $quoteNumberText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .onChange(of: quoteNumberText) { _, new in
                            quoteNumberText = new.filter(\.isNumber)
                        }
                }
                DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                DatePicker("Valid Until", selection: $validUntil, in: issueDate..., displayedComponents: .date)
                HStack {
                    Text("PO Number")
                    Spacer()
                    TextField("Optional", text: $poNumber)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
            }

            // MARK: Line items
            Section {
                ForEach($drafts) { $draft in
                    VStack(spacing: 6) {
                        TextField("Description (e.g. Website redesign)", text: $draft.description)
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Text("Qty").font(.caption).foregroundStyle(.secondary)
                                TextField("1", text: $draft.quantityText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 44)
                            }
                            Spacer()
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0.00", text: $draft.unitPriceText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 70)
                            }
                            Spacer()
                            Text(draft.lineTotal.asCurrency)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.teal)
                                .frame(width: 76, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { drafts.remove(atOffsets: $0) }

                Button {
                    drafts.append(DraftQuoteLineItem())
                } label: {
                    Label("Add Line Item", systemImage: "plus")
                }
            } header: {
                Text("Products & Services")
            } footer: {
                Text("Add the items you're quoting with quantity and unit price.")
            }

            // MARK: Totals
            Section {
                totalRow("Subtotal", subtotal, weight: .regular)
                HStack {
                    Text("Discount")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0.00", text: $discountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("Sales Tax")
                    Spacer()
                    TextField("0", text: $taxRateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                    Text("%").foregroundStyle(.secondary)
                    Text(taxAmount.asCurrency)
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }
                HStack {
                    Text("Quoted Total").font(.headline)
                    Spacer()
                    Text(quoteTotal.asCurrency)
                        .font(.headline)
                        .foregroundStyle(.teal)
                }
            } header: {
                Text("Totals")
            }

            // MARK: Payment
            Section("Payment Terms") {
                Picker("Terms", selection: $paymentTerms) {
                    ForEach(paymentTermsOptions, id: \.self) { Text($0) }
                }
                TextField("Accepted payments (e.g. Bank transfer, Check)", text: $acceptedPayments, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Payment instructions", text: $paymentInstructions, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section("Notes") {
                TextField("Scope notes, terms, or a thank-you…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("New Estimate")
        .navigationSubtitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            quoteNumberText = String(format: "%03d", nextNumber)
            taxRateText = defaultTaxRate > 0 ? String(format: "%.2f", defaultTaxRate) : ""
            paymentTerms = defaultPaymentTerms.isEmpty ? "Due Upon Receipt" : defaultPaymentTerms
            acceptedPayments = defaultAcceptedPayments
            paymentInstructions = defaultPaymentInstructions
        }
        // After creating, preview the finished PDF; closing it dismisses the form.
        .sheet(item: $preview, onDismiss: { finish() }) { doc in
            DocumentPreviewView(doc: doc)
        }
    }

    private func totalRow(_ label: String, _ value: Double, weight: Font.Weight) -> some View {
        HStack {
            Text(label).fontWeight(weight)
            Spacer()
            Text(value.asCurrency).fontWeight(weight)
        }
    }

    /// Fully closes the create flow (preferring `onComplete` when supplied).
    private func finish() {
        if let onComplete { onComplete() } else { dismiss() }
    }

    private func save() {
        let number = Int(quoteNumberText) ?? nextNumber
        let quote = Quote(
            quoteNumber: number,
            issueDate: issueDate,
            validUntil: validUntil,
            client: client,
            notes: notes
        )
        quote.discountAmount = discount
        quote.taxRate = taxRate
        quote.paymentTerms = paymentTerms
        quote.acceptedPayments = acceptedPayments
        quote.paymentInstructions = paymentInstructions
        quote.poNumber = poNumber
        modelContext.insert(quote)

        for (index, draft) in drafts.enumerated() where draft.isValid {
            let item = QuoteLineItem(
                itemDescription: draft.description.trimmingCharacters(in: .whitespaces),
                quantity: draft.quantity,
                unitPrice: draft.unitPrice,
                sortOrder: index,
                quote: quote
            )
            modelContext.insert(item)
        }
        // Persist so the PDF render sees the finalized line items, then preview it.
        try? modelContext.save()
        if let url = makeQuotePDF(quote: quote, userName: userFullName()) {
            preview = PreviewDoc(
                url: url, title: quote.formattedNumber, toast: "Estimate Created",
                onSent: { if quote.statusValue == .draft { quote.status = QuoteStatus.sent.rawValue } }
            )
        } else {
            finish()
        }
    }
}

// MARK: - Quote detail sheet

struct QuoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let quote: Quote

    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil }, sort: \Invoice.invoiceNumber, order: .reverse) private var allInvoices: [Invoice]

    @State private var shareItem: SharePDF?
    @State private var showConvertConfirm = false
    @State private var createdInvoice: Invoice?

    /// Marks a still-Draft estimate as Sent once it's actually shared (not saved).
    private func markSentIfDraft() {
        if quote.statusValue == .draft {
            quote.status = QuoteStatus.sent.rawValue
        }
    }

    private var items: [QuoteLineItem] {
        (quote.lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Estimate Info") {
                    LabeledContent("Estimate #", value: quote.formattedNumber)
                    LabeledContent("Client", value: quote.client?.name ?? "—")
                    if let company = quote.client?.companyName, !company.isEmpty {
                        LabeledContent("Company", value: company)
                    }
                    LabeledContent("Issued", value: quote.issueDate.formatted(date: .long, time: .omitted))
                    LabeledContent("Valid Until", value: quote.validUntil.formatted(date: .long, time: .omitted))
                    if !quote.poNumber.isEmpty {
                        LabeledContent("PO Number", value: quote.poNumber)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        let s = quote.displayStatus
                        Label(s.rawValue, systemImage: s.icon)
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(s.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(s.color.opacity(0.12), in: Capsule())
                    }
                    if quote.isConverted {
                        LabeledContent("Converted To", value: Invoice.formatted(number: quote.convertedInvoiceNumber, issueDate: .now))
                    }
                }

                // MARK: Set status
                Section("Set Status") {
                    Picker("Status", selection: Binding(
                        get: { quote.statusValue },
                        set: { quote.status = $0.rawValue }
                    )) {
                        ForEach(QuoteStatus.allCases.filter { $0 != .expired }, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !items.isEmpty {
                    Section("Line Items") {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                }

                Section("Totals") {
                    detailTotalRow("Subtotal", quote.subtotal, color: .primary)
                    if quote.discountAmount > 0 {
                        detailTotalRow("Discount", -quote.discountAmount, color: .secondary)
                    }
                    if quote.taxRate > 0 {
                        detailTotalRow("Sales Tax (\(quote.taxRate.formatted(.number.precision(.fractionLength(0...2))))%)", quote.taxAmount, color: .secondary)
                    }
                    HStack {
                        Text("Quoted Total").font(.headline)
                        Spacer()
                        Text(quote.total.asCurrency)
                            .font(.headline)
                            .foregroundStyle(.teal)
                    }
                }

                if !quote.paymentTerms.isEmpty || !quote.acceptedPayments.isEmpty || !quote.paymentInstructions.isEmpty {
                    Section("Payment Terms") {
                        if !quote.paymentTerms.isEmpty {
                            LabeledContent("Terms", value: quote.paymentTerms)
                        }
                        if !quote.acceptedPayments.isEmpty {
                            LabeledContent("Accepted", value: quote.acceptedPayments)
                        }
                        if !quote.paymentInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instructions").font(.caption).foregroundStyle(.secondary)
                                Text(quote.paymentInstructions).font(.subheadline)
                            }
                        }
                    }
                }

                if !quote.notes.isEmpty {
                    Section("Notes") {
                        Text(quote.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Convert
                Section {
                    Button {
                        showConvertConfirm = true
                    } label: {
                        Label(quote.isConverted ? "Convert to Invoice Again" : "Accept & Convert to Invoice",
                              systemImage: "arrow.right.doc.on.clipboard")
                    }
                } footer: {
                    Text("Creates a new invoice from this estimate's line items and marks it Accepted.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(quote.formattedNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let url = makeQuotePDF(quote: quote, userName: userFullName()) {
                            shareItem = SharePDF(url: url, onSent: { markSentIfDraft() })
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share Estimate")
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityShareSheet(items: [item.url]) { activity, completed in
                    if ShareOutcome.wasSent(activity: activity, completed: completed) {
                        item.onSent?()
                    }
                }
            }
            .confirmationDialog("Convert to Invoice?", isPresented: $showConvertConfirm, titleVisibility: .visible) {
                Button("Create Invoice") { convertToInvoice() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A new invoice will be created from this estimate and the estimate marked Accepted.")
            }
            .sheet(item: $createdInvoice) { InvoiceDetailView(invoice: $0) }
        }
    }

    private func itemRow(_ item: QuoteLineItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.itemDescription.isEmpty ? "Item" : item.itemDescription)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(item.lineTotal.asCurrency)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...2)))) × \(item.unitPrice.asCurrency)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func detailTotalRow(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value.asCurrency)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
    }

    /// Copies the quote's line items into a new `Invoice`, marks the quote Accepted.
    private func convertToInvoice() {
        let number = (allInvoices.first?.invoiceNumber ?? 0) + 1
        let dueDate = max(quote.validUntil, Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now)
        let invoice = Invoice(
            invoiceNumber: number,
            issueDate: .now,
            dueDate: dueDate,
            client: quote.client,
            notes: quote.notes
        )
        invoice.discountAmount = quote.discountAmount
        invoice.taxRate = quote.taxRate
        invoice.paymentTerms = quote.paymentTerms
        invoice.acceptedPayments = quote.acceptedPayments
        invoice.paymentInstructions = quote.paymentInstructions
        invoice.poNumber = quote.poNumber
        modelContext.insert(invoice)

        for item in items {
            let line = InvoiceLineItem(
                itemDescription: item.itemDescription,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                sortOrder: item.sortOrder,
                invoice: invoice
            )
            modelContext.insert(line)
        }

        quote.status = QuoteStatus.accepted.rawValue
        quote.convertedInvoiceNumber = number
        createdInvoice = invoice
    }
}

// MARK: - PDF generation (delegates to the shared document renderer in DocumentPDF.swift)

private func quoteDocRows(for quote: Quote) -> [DocPDFRow] {
    (quote.lineItems ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
        DocPDFRow(
            description: item.itemDescription.isEmpty ? "Item" : item.itemDescription,
            detail: nil,
            qty: item.quantity.formatted(.number.precision(.fractionLength(0...2))),
            rate: item.unitPrice.asCurrency,
            amount: item.lineTotal.asCurrency
        )
    }
}

@MainActor
func makeQuotePDF(quote: Quote, userName: String) -> URL? {
    var meta: [(String, String)] = [
        ("Issue Date", quote.issueDate.formatted(date: .abbreviated, time: .omitted)),
        ("Valid Until", quote.validUntil.formatted(date: .abbreviated, time: .omitted)),
    ]
    if !quote.poNumber.isEmpty { meta.append(("PO Number", quote.poNumber)) }
    if !quote.paymentTerms.isEmpty { meta.append(("Terms", quote.paymentTerms)) }
    meta.append(("Status", quote.displayStatus.rawValue))

    let business = BusinessInfo.load(fallbackName: userName)
    let spec = DocumentPDFSpec(
        business: business,
        logoData: business.logoData,
        typeLabel: "ESTIMATE",
        number: quote.formattedNumber,
        recipientLabel: "QUOTE FOR",
        recipientName: quote.client?.name ?? "",
        recipientCompany: quote.client?.companyName ?? "",
        recipientAddress: quote.client?.billingAddress ?? "",
        recipientAddress2: quote.client?.billingAddress2 ?? "",
        recipientEmail: quote.client?.email ?? "",
        recipientPhone: quote.client?.phone ?? "",
        meta: meta,
        rateColumnHeader: "UNIT PRICE",
        rows: quoteDocRows(for: quote),
        subtotal: quote.subtotal,
        discountAmount: quote.discountAmount,
        taxRate: quote.taxRate,
        taxAmount: quote.taxAmount,
        total: quote.total,
        totalLabel: "QUOTED TOTAL",
        paymentTerms: quote.paymentTerms,
        acceptedPayments: quote.acceptedPayments,
        paymentInstructions: quote.paymentInstructions,
        notes: quote.notes,
        showAcceptanceLine: true
    )
    return makeDocumentPDF(spec: spec)
}
