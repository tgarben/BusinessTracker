import SwiftUI
import SwiftData

// MARK: - Invoice list row

struct InvoiceRow: View {
    let invoice: Invoice

    /// Three-state status: Paid (green), Overdue (red), Unpaid (orange).
    private var statusColor: Color {
        invoice.isPaid ? .green : (invoice.isOverdue ? .red : .orange)
    }
    private var statusText: String {
        invoice.isPaid ? "Paid" : (invoice.isOverdue ? "Overdue" : "Unpaid")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(invoice.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(invoice.total.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 12)
                Text(invoice.issueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text("Due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Overdue invoices sheet (opened from the Home card)

struct OverdueInvoicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil && $0.isPaid == false },
           sort: \Invoice.dueDate) private var unpaid: [Invoice]
    @State private var viewing: Invoice?

    private var overdue: [Invoice] { unpaid.filter { $0.isOverdue } }

    var body: some View {
        NavigationStack {
            List {
                ForEach(overdue) { invoice in
                    VStack(alignment: .leading, spacing: 2) {
                        InvoiceRow(invoice: invoice)
                        if let name = invoice.client?.name, !name.isEmpty {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewing = invoice }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if overdue.isEmpty {
                    ContentUnavailableView(
                        "No Overdue Invoices",
                        systemImage: "checkmark.circle",
                        description: Text("You're all caught up.")
                    )
                }
            }
            .navigationTitle("Overdue Invoices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $viewing) { InvoiceDetailView(invoice: $0) }
        }
    }
}

// MARK: - Create invoice sheet

struct CreateInvoiceView: View {
    let client: Client
    var body: some View {
        NavigationStack { CreateInvoiceContent(client: client) }
    }
}

// MARK: - Invoice quick action sheet (client picker → create invoice)

struct InvoiceQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients Yet",
                        systemImage: "person.2",
                        description: Text("Add clients from the Clients tab before creating an invoice.")
                    )
                } else {
                    List(clients) { client in
                        NavigationLink(client.name) {
                            CreateInvoiceContent(client: client, onComplete: { dismiss() })
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

// MARK: - Create invoice form content (used by CreateInvoiceView and InvoiceQuickActionSheet)

/// A draft manual line item being edited in the create-invoice form.
private struct DraftLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantityText: String = "1"
    var unitPriceText: String = ""

    var quantity: Double { Double(quantityText) ?? 0 }
    var unitPrice: Double { Double(unitPriceText) ?? 0 }
    var lineTotal: Double { quantity * unitPrice }
    var isValid: Bool { !description.trimmingCharacters(in: .whitespaces).isEmpty && lineTotal != 0 }
}

private struct CreateInvoiceContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let client: Client
    /// Closes the whole flow after creating. When pushed inside the quick-action
    /// client picker, the plain `dismiss()` only pops back to the picker, so that
    /// path passes a closure that dismisses the entire sheet instead.
    let onComplete: (() -> Void)?

    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil }, sort: \Invoice.invoiceNumber, order: .reverse) private var allInvoices: [Invoice]
    @Query private var clientTimeEntries: [TimeEntry]

    // Business invoicing defaults
    @AppStorage("business_defaultTaxRate") private var defaultTaxRate: Double = 0
    @AppStorage("business_defaultPaymentTerms") private var defaultPaymentTerms: String = "Due Upon Receipt"
    @AppStorage("business_acceptedPayments") private var defaultAcceptedPayments: String = ""
    @AppStorage("business_paymentInstructions") private var defaultPaymentInstructions: String = ""

    @State private var invoiceNumberText: String = ""
    @State private var issueDate: Date = .now
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var selectedEntryIDs: Set<PersistentIdentifier> = []
    @State private var drafts: [DraftLineItem] = []
    @State private var discountText: String = ""
    @State private var discountIsPercent: Bool = false
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

    /// Next invoice number — highest existing + 1, scoped to the current year
    /// when per-year reset is on.
    private var nextNumber: Int {
        if resetYearly {
            let year = Calendar.current.component(.year, from: .now)
            let inYear = allInvoices.filter { Calendar.current.component(.year, from: $0.issueDate) == year }
            return (inYear.map(\.invoiceNumber).max() ?? 0) + 1
        }
        return (allInvoices.map(\.invoiceNumber).max() ?? 0) + 1
    }

    init(client: Client, onComplete: (() -> Void)? = nil) {
        self.client = client
        self.onComplete = onComplete
        let id = client.persistentModelID
        _clientTimeEntries = Query(
            filter: #Predicate<TimeEntry> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \TimeEntry.date, order: .reverse
        )
    }

    /// Fully closes the create flow (preferring `onComplete` when supplied).
    private func finish() {
        if let onComplete { onComplete() } else { dismiss() }
    }

    private var unbilledEntries: [TimeEntry] {
        // Available = not yet billed, OR billed to an invoice that's since been
        // (soft-)deleted — so deleting an invoice frees its time entries again.
        clientTimeEntries.filter { $0.invoice == nil || $0.invoice?.deletedDate != nil }
    }

    private var selectedTotal: Double {
        clientTimeEntries
            .filter { selectedEntryIDs.contains($0.persistentModelID) }
            .reduce(0) { $0 + $1.earnings }
    }

    private var itemsTotal: Double { drafts.reduce(0) { $0 + $1.lineTotal } }
    private var subtotal: Double { selectedTotal + itemsTotal }
    private var discountInput: Double { Double(discountText) ?? 0 }
    /// Discount as a dollar figure (resolves the percent case for live totals).
    private var discount: Double { discountIsPercent ? subtotal * (discountInput / 100) : discountInput }
    private var taxRate: Double { Double(taxRateText) ?? 0 }
    private var discountedSubtotal: Double { max(0, subtotal - discount) }
    private var taxAmount: Double { discountedSubtotal * (taxRate / 100) }
    private var invoiceTotal: Double { discountedSubtotal + taxAmount }

    private var canSave: Bool {
        !invoiceNumberText.isEmpty &&
        (!selectedEntryIDs.isEmpty || drafts.contains(where: \.isValid))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Bill To", value: client.name)
                if !client.companyName.isEmpty {
                    LabeledContent("Company", value: client.companyName)
                }
                if client.billingAddress.isEmpty || client.email.isEmpty {
                    Text("Tip: add this client's billing address, email & phone in their profile to include them on the invoice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Invoice Details") {
                HStack {
                    Text("Invoice #")
                    Spacer()
                    TextField("001", text: $invoiceNumberText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .onChange(of: invoiceNumberText) { _, new in
                            invoiceNumberText = new.filter(\.isNumber)
                        }
                }
                DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                DatePicker("Due Date", selection: $dueDate, in: issueDate..., displayedComponents: .date)
                HStack {
                    Text("PO Number")
                    Spacer()
                    TextField("Optional", text: $poNumber)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
            }

            Section {
                if unbilledEntries.isEmpty {
                    Text("No unbilled time entries for this client.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(unbilledEntries) { entry in
                        entrySelectionRow(entry)
                            .contentShape(Rectangle())
                            .onTapGesture { toggleEntry(entry) }
                    }
                }
            } header: {
                Text("Time Entries")
            } footer: {
                if !unbilledEntries.isEmpty {
                    Text("Tap to include or exclude entries from this invoice.")
                }
            }

            // MARK: Manual line items
            Section {
                ForEach($drafts) { $draft in
                    VStack(spacing: 6) {
                        TextField("Description (e.g. Logo design)", text: $draft.description)
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
                                .foregroundStyle(.indigo)
                                .frame(width: 76, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { drafts.remove(atOffsets: $0) }

                Button {
                    drafts.append(DraftLineItem())
                } label: {
                    Label("Add Line Item", systemImage: "plus")
                }
            } header: {
                Text("Products & Services")
            } footer: {
                Text("Add arbitrary items with quantity and unit price.")
            }

            // MARK: Totals
            Section {
                totalRow("Subtotal", subtotal, weight: .regular)
                HStack {
                    Text("Discount")
                    Picker("", selection: $discountIsPercent) {
                        Text("$").tag(false)
                        Text("%").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 88)
                    Spacer()
                    if !discountIsPercent { Text("$").foregroundStyle(.secondary) }
                    TextField(discountIsPercent ? "0" : "0.00", text: $discountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    if discountIsPercent { Text("%").foregroundStyle(.secondary) }
                    if discountIsPercent {
                        Text("−\(discount.asCurrency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
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
                    Text("Total Due").font(.headline)
                    Spacer()
                    Text(invoiceTotal.asCurrency)
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Totals")
            }

            // MARK: Payment
            Section("Payment") {
                Picker("Terms", selection: $paymentTerms) {
                    ForEach(paymentTermsOptions, id: \.self) { Text($0) }
                }
                TextField("Accepted payments (e.g. Bank transfer, Check)", text: $acceptedPayments, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Payment instructions", text: $paymentInstructions, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section("Notes") {
                TextField("Thank-you message or notes…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("New Invoice")
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
            invoiceNumberText = String(format: "%03d", nextNumber)
            selectedEntryIDs = Set(unbilledEntries.map(\.persistentModelID))
            // Pre-fill from business defaults
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

    private func entrySelectionRow(_ entry: TimeEntry) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.persistentModelID)
        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.indigo : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.project?.name ?? "Uncategorized")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(entry.date, style: .date)
                    Text("·").foregroundStyle(.tertiary)
                    Text(String(format: "%.2f hrs", entry.hours))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.earnings.asCurrency)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.indigo)
        }
        .padding(.vertical, 2)
    }

    private func toggleEntry(_ entry: TimeEntry) {
        if selectedEntryIDs.contains(entry.persistentModelID) {
            selectedEntryIDs.remove(entry.persistentModelID)
        } else {
            selectedEntryIDs.insert(entry.persistentModelID)
        }
    }

    private func save() {
        let number = Int(invoiceNumberText) ?? nextNumber
        let invoice = Invoice(
            invoiceNumber: number,
            issueDate: issueDate,
            dueDate: dueDate,
            client: client,
            notes: notes
        )
        invoice.discountAmount = discountInput
        invoice.discountIsPercent = discountIsPercent
        invoice.taxRate = taxRate
        invoice.paymentTerms = paymentTerms
        invoice.acceptedPayments = acceptedPayments
        invoice.paymentInstructions = paymentInstructions
        invoice.poNumber = poNumber
        modelContext.insert(invoice)

        for entry in clientTimeEntries where selectedEntryIDs.contains(entry.persistentModelID) {
            entry.invoice = invoice
        }

        for (index, draft) in drafts.enumerated() where draft.isValid {
            let item = InvoiceLineItem(
                itemDescription: draft.description.trimmingCharacters(in: .whitespaces),
                quantity: draft.quantity,
                unitPrice: draft.unitPrice,
                sortOrder: index,
                invoice: invoice
            )
            modelContext.insert(item)
        }
        // Persist so the PDF render sees the finalized relationships, then preview it.
        try? modelContext.save()
        if let url = makeInvoicePDF(invoice: invoice, userName: userFullName()) {
            preview = PreviewDoc(url: url, title: invoice.displayTitle, toast: "Invoice Created")
        } else {
            finish()
        }
    }
}

// MARK: - Invoice detail sheet

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let invoice: Invoice

    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil }, sort: \Invoice.invoiceNumber, order: .reverse) private var allInvoices: [Invoice]
    @AppStorage("doc_numberResetYearly") private var resetYearly = false

    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("business_paymentLink") private var businessPaymentLink: String = ""

    @State private var duplicated: Invoice?

    /// Next invoice number — highest existing + 1 (year-scoped when reset-yearly is on).
    private var nextInvoiceNumber: Int {
        if resetYearly {
            let year = Calendar.current.component(.year, from: .now)
            let inYear = allInvoices.filter { Calendar.current.component(.year, from: $0.issueDate) == year }
            return (inYear.map(\.invoiceNumber).max() ?? 0) + 1
        }
        return (allInvoices.map(\.invoiceNumber).max() ?? 0) + 1
    }

    /// The configured pay-online link, normalized to an openable https URL string.
    private var payLinkURL: String {
        let raw = businessPaymentLink.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return "" }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
        return "https://\(raw)"
    }

    @State private var showMarkPaidSheet = false
    @State private var showUnpaidConfirm = false
    @State private var pdfURL: URL? = nil

    private var lineItems: [TimeEntry] {
        (invoice.timeEntries ?? []).sorted { $0.date < $1.date }
    }

    private var manualItems: [InvoiceLineItem] {
        (invoice.lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Invoice Info") {
                    LabeledContent("Invoice #", value: invoice.formattedNumber)
                    LabeledContent("Client", value: invoice.client?.name ?? "—")
                    if let company = invoice.client?.companyName, !company.isEmpty {
                        LabeledContent("Company", value: company)
                    }
                    LabeledContent("Issued", value: invoice.issueDate.formatted(date: .long, time: .omitted))
                    LabeledContent("Due", value: invoice.dueDate.formatted(date: .long, time: .omitted))
                    if !invoice.poNumber.isEmpty {
                        LabeledContent("PO Number", value: invoice.poNumber)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        let color: Color = invoice.isPaid ? .green : (invoice.isOverdue ? .red : .orange)
                        let label = invoice.isPaid ? "Paid" : (invoice.isOverdue ? "Overdue" : "Unpaid")
                        Text(invoice.isOverdue ? "\(label) · \(invoice.daysOverdue)d" : label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12), in: Capsule())
                    }
                    if invoice.isPaid, let paid = invoice.paidDate {
                        LabeledContent("Paid On", value: paid.formatted(date: .long, time: .omitted))
                    }
                }

                if !lineItems.isEmpty || !manualItems.isEmpty || invoice.additionalAmount > 0 {
                    Section("Line Items") {
                        ForEach(lineItems) { entry in
                            lineItemRow(entry)
                        }
                        ForEach(manualItems) { item in
                            manualItemRow(item)
                        }
                        if invoice.additionalAmount > 0 {
                            additionalItemRow
                        }
                    }
                }

                Section("Totals") {
                    detailTotalRow("Subtotal", invoice.subtotal, color: .primary)
                    if invoice.effectiveDiscount > 0 {
                        let label = invoice.discountIsPercent
                            ? "Discount (\(invoice.discountAmount.formatted(.number.precision(.fractionLength(0...2))))%)"
                            : "Discount"
                        detailTotalRow(label, -invoice.effectiveDiscount, color: .secondary)
                    }
                    if invoice.taxRate > 0 {
                        detailTotalRow("Sales Tax (\(invoice.taxRate.formatted(.number.precision(.fractionLength(0...2))))%)", invoice.taxAmount, color: .secondary)
                    }
                    HStack {
                        Text("Total Due").font(.headline)
                        Spacer()
                        Text(invoice.total.asCurrency)
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                if !invoice.paymentTerms.isEmpty || !invoice.acceptedPayments.isEmpty || !invoice.paymentInstructions.isEmpty || !payLinkURL.isEmpty {
                    Section("Payment") {
                        if !invoice.paymentTerms.isEmpty {
                            LabeledContent("Terms", value: invoice.paymentTerms)
                        }
                        if !invoice.acceptedPayments.isEmpty {
                            LabeledContent("Accepted", value: invoice.acceptedPayments)
                        }
                        if let url = URL(string: payLinkURL), !payLinkURL.isEmpty {
                            Link(destination: url) {
                                Label("Pay Online", systemImage: "link")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        if !invoice.paymentInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instructions").font(.caption).foregroundStyle(.secondary)
                                Text(invoice.paymentInstructions).font(.subheadline)
                            }
                        }
                    }
                }

                if !invoice.notes.isEmpty {
                    Section("Notes") {
                        Text(invoice.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        duplicateInvoice()
                    } label: {
                        Label("Duplicate Invoice", systemImage: "doc.on.doc")
                    }
                } footer: {
                    Text("Creates a new unpaid invoice with the same line items and settings. Billed time entries aren't copied.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(invoice.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Group {
                        if let url = pdfURL {
                            ShareLink(item: url, subject: Text(invoice.displayTitle)) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share Invoice")
                        } else {
                            Button {
                                pdfURL = makeInvoicePDF(invoice: invoice, userName: userFullName())
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share Invoice")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if invoice.isPaid {
                        Button { showUnpaidConfirm = true } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .accessibilityLabel("Mark as Unpaid")
                    } else {
                        Button { showMarkPaidSheet = true } label: {
                            Image(systemName: "checkmark.circle")
                        }
                        .accessibilityLabel("Mark as Paid")
                    }
                }
            }
            .onChange(of: invoice.isPaid) { _, _ in
                pdfURL = nil  // invalidate cached PDF when status changes
            }
            .sheet(isPresented: $showMarkPaidSheet) {
                MarkPaidSheet(invoice: invoice)
            }
            .confirmationDialog("Mark as Unpaid?", isPresented: $showUnpaidConfirm, titleVisibility: .visible) {
                Button("Mark Unpaid", role: .destructive) {
                    invoice.isPaid = false
                    invoice.paidDate = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear the payment date.")
            }
            .sheet(item: $duplicated) { InvoiceDetailView(invoice: $0) }
        }
    }

    /// Clones this invoice into a new unpaid one (manual line items + settings;
    /// not the billed time entries) and opens it.
    private func duplicateInvoice() {
        let gap = Calendar.current.dateComponents([.day], from: invoice.issueDate, to: invoice.dueDate).day ?? 30
        let new = Invoice(
            invoiceNumber: nextInvoiceNumber,
            issueDate: .now,
            dueDate: Calendar.current.date(byAdding: .day, value: max(0, gap), to: .now) ?? .now,
            client: invoice.client,
            notes: invoice.notes
        )
        new.discountAmount = invoice.discountAmount
        new.discountIsPercent = invoice.discountIsPercent
        new.taxRate = invoice.taxRate
        new.paymentTerms = invoice.paymentTerms
        new.acceptedPayments = invoice.acceptedPayments
        new.paymentInstructions = invoice.paymentInstructions
        new.poNumber = invoice.poNumber
        modelContext.insert(new)
        for item in (invoice.lineItems ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            modelContext.insert(InvoiceLineItem(
                itemDescription: item.itemDescription,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                sortOrder: item.sortOrder,
                invoice: new
            ))
        }
        try? modelContext.save()
        duplicated = new
    }

    private func lineItemRow(_ entry: TimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.project?.name ?? "Uncategorized")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(entry.earnings.asCurrency)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
            HStack(spacing: 4) {
                Text(String(format: "%.2f hrs × \(entry.hourlyRate.asCurrency)/hr", entry.hours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var additionalItemRow: some View {
        HStack {
            Text(invoice.additionalDescription.isEmpty ? "Additional Charges" : invoice.additionalDescription)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(invoice.additionalAmount.asCurrency)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
        }
        .padding(.vertical, 4)
    }

    private func manualItemRow(_ item: InvoiceLineItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.itemDescription.isEmpty ? "Item" : item.itemDescription)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(item.lineTotal.asCurrency)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
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
}

// MARK: - Mark paid sheet

private struct MarkPaidSheet: View {
    @Environment(\.dismiss) private var dismiss
    let invoice: Invoice
    @State private var paidDate: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Payment Date", selection: $paidDate, in: ...Date.now, displayedComponents: .date)
                }
            }
            .navigationTitle("Mark as Paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        invoice.isPaid = true
                        invoice.paidDate = paidDate
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PDF data helpers

/// Standardized business "from" info, read from the same UserDefaults keys as Settings.
struct BusinessInfo {
    var name: String, address: String, address2: String, phone: String, email: String, website: String, taxID: String
    var paymentLink: String = ""
    var logoData: Data? = nil

    static func load(fallbackName: String) -> BusinessInfo {
        let d = UserDefaults.standard
        let name = d.string(forKey: "business_name") ?? ""
        return BusinessInfo(
            name: name.isEmpty ? fallbackName : name,
            address: d.string(forKey: "business_address") ?? "",
            address2: d.string(forKey: "business_address2") ?? "",
            phone: d.string(forKey: "business_phone") ?? "",
            email: d.string(forKey: "business_email") ?? "",
            website: d.string(forKey: "business_website") ?? "",
            taxID: d.string(forKey: "business_taxID") ?? "",
            paymentLink: d.string(forKey: "business_paymentLink") ?? "",
            logoData: d.data(forKey: "business_logo")
        )
    }

    var contactLines: [String] { [phone, email, website].filter { !$0.isEmpty } }
}

/// Builds the unified table rows for an invoice (time entries + manual line items + legacy extra).
private func invoiceDocRows(for invoice: Invoice) -> [DocPDFRow] {
    var rows: [DocPDFRow] = []
    for entry in (invoice.timeEntries ?? []).sorted(by: { $0.date < $1.date }) {
        let detail = "\(entry.date.formatted(date: .abbreviated, time: .omitted))\(entry.notes.isEmpty ? "" : " · \(entry.notes)")"
        rows.append(DocPDFRow(
            description: entry.project?.name ?? "Uncategorized",
            detail: detail,
            qty: String(format: "%.2f", entry.hours),
            rate: entry.hourlyRate.asCurrency,
            amount: entry.earnings.asCurrency
        ))
    }
    for item in (invoice.lineItems ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
        rows.append(DocPDFRow(
            description: item.itemDescription.isEmpty ? "Item" : item.itemDescription,
            detail: nil,
            qty: item.quantity.formatted(.number.precision(.fractionLength(0...2))),
            rate: item.unitPrice.asCurrency,
            amount: item.lineTotal.asCurrency
        ))
    }
    if invoice.additionalAmount > 0 {
        rows.append(DocPDFRow(
            description: invoice.additionalDescription.isEmpty ? "Additional Charges" : invoice.additionalDescription,
            detail: nil, qty: "—", rate: "—",
            amount: invoice.additionalAmount.asCurrency
        ))
    }
    return rows
}

// MARK: - PDF generation (delegates to the shared document renderer in DocumentPDF.swift)

@MainActor
func makeInvoicePDF(invoice: Invoice, userName: String) -> URL? {
    var meta: [(String, String)] = [
        ("Issue Date", invoice.issueDate.formatted(date: .abbreviated, time: .omitted)),
        ("Due Date", invoice.dueDate.formatted(date: .abbreviated, time: .omitted)),
    ]
    if !invoice.poNumber.isEmpty { meta.append(("PO Number", invoice.poNumber)) }
    if !invoice.paymentTerms.isEmpty { meta.append(("Terms", invoice.paymentTerms)) }
    meta.append(("Status", invoice.isPaid ? "Paid" : "Unpaid"))

    let business = BusinessInfo.load(fallbackName: userName)
    let spec = DocumentPDFSpec(
        business: business,
        logoData: business.logoData,
        typeLabel: "INVOICE",
        number: invoice.formattedNumber,
        fileName: invoice.shareFileName,
        recipientLabel: "BILL TO",
        recipientName: invoice.client?.name ?? "",
        recipientCompany: invoice.client?.companyName ?? "",
        recipientAddress: invoice.client?.billingAddress ?? "",
        recipientAddress2: invoice.client?.billingAddress2 ?? "",
        recipientEmail: invoice.client?.email ?? "",
        recipientPhone: invoice.client?.phone ?? "",
        meta: meta,
        rateColumnHeader: "RATE",
        rows: invoiceDocRows(for: invoice),
        subtotal: invoice.subtotal,
        discountAmount: invoice.effectiveDiscount,
        taxRate: invoice.taxRate,
        taxAmount: invoice.taxAmount,
        total: invoice.total,
        totalLabel: "TOTAL DUE",
        paymentTerms: invoice.paymentTerms,
        acceptedPayments: invoice.acceptedPayments,
        paymentInstructions: invoice.paymentInstructions,
        paymentLink: business.paymentLink,
        notes: invoice.notes,
        showAcceptanceLine: false
    )
    return makeDocumentPDF(spec: spec)
}
