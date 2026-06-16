import SwiftUI
import SwiftData

// MARK: - Invoice list row

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(invoice.formattedNumber)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(invoice.total.formatted(.currency(code: "USD")))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(invoice.isPaid ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((invoice.isPaid ? Color.green : Color.orange).opacity(0.1), in: Capsule())
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
                Text(invoice.isPaid ? "Paid" : "Unpaid")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(invoice.isPaid ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
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
                            CreateInvoiceContent(client: client)
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
    @State private var taxRateText: String = ""
    @State private var paymentTerms: String = "Due Upon Receipt"
    @State private var acceptedPayments: String = ""
    @State private var paymentInstructions: String = ""
    @State private var poNumber: String = ""
    @State private var notes: String = ""
    @State private var didPrefill = false

    private let paymentTermsOptions = ["Due Upon Receipt", "Net 15", "Net 30", "Net 45", "Net 60"]

    init(client: Client) {
        self.client = client
        let id = client.persistentModelID
        _clientTimeEntries = Query(
            filter: #Predicate<TimeEntry> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \TimeEntry.date, order: .reverse
        )
    }

    private var unbilledEntries: [TimeEntry] {
        clientTimeEntries.filter { $0.invoice == nil }
    }

    private var selectedTotal: Double {
        clientTimeEntries
            .filter { selectedEntryIDs.contains($0.persistentModelID) }
            .reduce(0) { $0 + $1.earnings }
    }

    private var itemsTotal: Double { drafts.reduce(0) { $0 + $1.lineTotal } }
    private var subtotal: Double { selectedTotal + itemsTotal }
    private var discount: Double { Double(discountText) ?? 0 }
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
                            Text(draft.lineTotal.formatted(.currency(code: "USD")))
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
                    Text(taxAmount.formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }
                HStack {
                    Text("Total Due").font(.headline)
                    Spacer()
                    Text(invoiceTotal.formatted(.currency(code: "USD")))
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
        .navigationTitle("New Invoice — \(client.name)")
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
            let next = (allInvoices.first?.invoiceNumber ?? 0) + 1
            invoiceNumberText = String(format: "%03d", next)
            selectedEntryIDs = Set(unbilledEntries.map(\.persistentModelID))
            // Pre-fill from business defaults
            taxRateText = defaultTaxRate > 0 ? String(format: "%.2f", defaultTaxRate) : ""
            paymentTerms = defaultPaymentTerms.isEmpty ? "Due Upon Receipt" : defaultPaymentTerms
            acceptedPayments = defaultAcceptedPayments
            paymentInstructions = defaultPaymentInstructions
        }
    }

    private func totalRow(_ label: String, _ value: Double, weight: Font.Weight) -> some View {
        HStack {
            Text(label).fontWeight(weight)
            Spacer()
            Text(value.formatted(.currency(code: "USD"))).fontWeight(weight)
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

            Text(entry.earnings.formatted(.currency(code: "USD")))
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
        let number = Int(invoiceNumberText) ?? ((allInvoices.first?.invoiceNumber ?? 0) + 1)
        let invoice = Invoice(
            invoiceNumber: number,
            issueDate: issueDate,
            dueDate: dueDate,
            client: client,
            notes: notes
        )
        invoice.discountAmount = discount
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
        dismiss()
    }
}

// MARK: - Invoice detail sheet

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let invoice: Invoice

    @AppStorage("user_name") private var userName: String = ""

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
                        Text(invoice.isPaid ? "Paid" : "Unpaid")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(invoice.isPaid ? .green : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background((invoice.isPaid ? Color.green : Color.orange).opacity(0.12), in: Capsule())
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
                    if invoice.discountAmount > 0 {
                        detailTotalRow("Discount", -invoice.discountAmount, color: .secondary)
                    }
                    if invoice.taxRate > 0 {
                        detailTotalRow("Sales Tax (\(invoice.taxRate.formatted(.number.precision(.fractionLength(0...2))))%)", invoice.taxAmount, color: .secondary)
                    }
                    HStack {
                        Text("Total Due").font(.headline)
                        Spacer()
                        Text(invoice.total.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                if !invoice.paymentTerms.isEmpty || !invoice.acceptedPayments.isEmpty || !invoice.paymentInstructions.isEmpty {
                    Section("Payment") {
                        if !invoice.paymentTerms.isEmpty {
                            LabeledContent("Terms", value: invoice.paymentTerms)
                        }
                        if !invoice.acceptedPayments.isEmpty {
                            LabeledContent("Accepted", value: invoice.acceptedPayments)
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
            }
            .listStyle(.insetGrouped)
            .navigationTitle(invoice.formattedNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Group {
                        if let url = pdfURL {
                            ShareLink(item: url, subject: Text(invoice.formattedNumber)) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                pdfURL = makeInvoicePDF(invoice: invoice, userName: userFullName())
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if invoice.isPaid {
                        Button { showUnpaidConfirm = true } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button { showMarkPaidSheet = true } label: {
                            Image(systemName: "checkmark.circle")
                        }
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
        }
    }

    private func lineItemRow(_ entry: TimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.project?.name ?? "Uncategorized")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(entry.earnings.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
            HStack(spacing: 4) {
                Text(String(format: "%.2f hrs × \(entry.hourlyRate.formatted(.currency(code: "USD")))/hr", entry.hours))
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
            Text(invoice.additionalAmount.formatted(.currency(code: "USD")))
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
                Text(item.lineTotal.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
            Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...2)))) × \(item.unitPrice.formatted(.currency(code: "USD")))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func detailTotalRow(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value.formatted(.currency(code: "USD")))
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
            taxID: d.string(forKey: "business_taxID") ?? ""
        )
    }

    var contactLines: [String] { [phone, email, website].filter { !$0.isEmpty } }
}

/// A unified row in the invoice line-item table (from a time entry or a manual line item).
struct InvoicePDFRow: Identifiable {
    let id = UUID()
    let description: String
    let detail: String?
    let qty: String
    let rate: String
    let amount: String
}

private func invoicePDFRows(for invoice: Invoice) -> [InvoicePDFRow] {
    var rows: [InvoicePDFRow] = []
    for entry in (invoice.timeEntries ?? []).sorted(by: { $0.date < $1.date }) {
        let detail = "\(entry.date.formatted(date: .abbreviated, time: .omitted))\(entry.notes.isEmpty ? "" : " · \(entry.notes)")"
        rows.append(InvoicePDFRow(
            description: entry.project?.name ?? "Uncategorized",
            detail: detail,
            qty: String(format: "%.2f", entry.hours),
            rate: entry.hourlyRate.formatted(.currency(code: "USD")),
            amount: entry.earnings.formatted(.currency(code: "USD"))
        ))
    }
    for item in (invoice.lineItems ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
        rows.append(InvoicePDFRow(
            description: item.itemDescription.isEmpty ? "Item" : item.itemDescription,
            detail: nil,
            qty: item.quantity.formatted(.number.precision(.fractionLength(0...2))),
            rate: item.unitPrice.formatted(.currency(code: "USD")),
            amount: item.lineTotal.formatted(.currency(code: "USD"))
        ))
    }
    if invoice.additionalAmount > 0 {
        rows.append(InvoicePDFRow(
            description: invoice.additionalDescription.isEmpty ? "Additional Charges" : invoice.additionalDescription,
            detail: nil, qty: "—", rate: "—",
            amount: invoice.additionalAmount.formatted(.currency(code: "USD"))
        ))
    }
    return rows
}

// MARK: - PDF shared helpers (letter size: 612×792pt, 56pt margins)

private func invoicePDFDivider() -> some View {
    Rectangle().fill(Color(white: 0.85)).frame(height: 1).padding(.horizontal, 56)
}

private func invoicePDFLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(Color(white: 0.55))
        .tracking(1.5)
}

private func invoicePDFMeta(_ label: String, _ value: String) -> some View {
    HStack(spacing: 8) {
        Text(label).font(.system(size: 10)).foregroundColor(Color(white: 0.5))
        Text(value).font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
    }
}

private func invoicePDFTableHeader() -> some View {
    VStack(spacing: 0) {
        HStack {
            Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading)
            Text("QTY").frame(width: 50, alignment: .trailing)
            Text("RATE").frame(width: 72, alignment: .trailing)
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

private func invoicePDFRowView(_ row: InvoicePDFRow) -> some View {
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

// Totals + payment + notes footer, shown on the last page only.
private func invoicePDFFooter(invoice: Invoice, business: BusinessInfo) -> some View {
    let usd: (Double) -> String = { $0.formatted(.currency(code: "USD")) }
    return VStack(alignment: .leading, spacing: 0) {
        // Totals
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                totalsLine("Subtotal", usd(invoice.subtotal), bold: false)
                if invoice.discountAmount > 0 {
                    totalsLine("Discount", "−\(usd(invoice.discountAmount))", bold: false)
                }
                if invoice.taxRate > 0 {
                    totalsLine("Sales Tax (\(invoice.taxRate.formatted(.number.precision(.fractionLength(0...2))))%)", usd(invoice.taxAmount), bold: false)
                }
                Rectangle().fill(Color(white: 0.75)).frame(width: 220, height: 1).padding(.vertical, 2)
                HStack {
                    Text("TOTAL DUE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.45))
                        .tracking(1)
                    Spacer(minLength: 24)
                    Text(usd(invoice.total))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(width: 220)
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 14)
        .padding(.bottom, 18)

        // Payment + notes + tax id
        let hasPayment = !invoice.paymentTerms.isEmpty || !invoice.acceptedPayments.isEmpty || !invoice.paymentInstructions.isEmpty
        if hasPayment || !invoice.notes.isEmpty || !business.taxID.isEmpty {
            invoicePDFDivider()
            VStack(alignment: .leading, spacing: 10) {
                if hasPayment {
                    VStack(alignment: .leading, spacing: 3) {
                        invoicePDFLabel("PAYMENT")
                        if !invoice.paymentTerms.isEmpty {
                            Text("Terms: \(invoice.paymentTerms)").font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                        if !invoice.acceptedPayments.isEmpty {
                            Text("Accepted: \(invoice.acceptedPayments)").font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                        if !invoice.paymentInstructions.isEmpty {
                            Text(invoice.paymentInstructions).font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                        }
                    }
                }
                if !invoice.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        invoicePDFLabel("NOTES")
                        Text(invoice.notes).font(.system(size: 11)).foregroundColor(Color(white: 0.4))
                    }
                }
                if !business.taxID.isEmpty {
                    Text("Tax ID / EIN: \(business.taxID)")
                        .font(.system(size: 9)).foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 14)
        }
    }
}

private func totalsLine(_ label: String, _ value: String, bold: Bool) -> some View {
    HStack {
        Text(label).font(.system(size: 11)).foregroundColor(Color(white: 0.45))
        Spacer(minLength: 24)
        Text(value).font(.system(size: 11, weight: bold ? .bold : .medium)).foregroundColor(Color(white: 0.2))
    }
    .frame(width: 220)
}

private func invoiceContinuedIndicator() -> some View {
    HStack {
        Spacer()
        Text("Continued on next page →")
            .font(.system(size: 9)).foregroundColor(Color(white: 0.6)).italic()
    }
    .padding(.horizontal, 56)
    .padding(.top, 12)
}

// MARK: - PDF page 1 layout

private struct InvoiceFirstPageLayout: View {
    let invoice: Invoice
    let business: BusinessInfo
    let rows: [InvoicePDFRow]
    let isLastPage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — business info + INVOICE number
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(business.name.isEmpty ? "Freelancer" : business.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    if !business.address.isEmpty {
                        Text(business.address)
                            .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !business.address2.isEmpty {
                        Text(business.address2)
                            .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    ForEach(business.contactLines, id: \.self) { line in
                        Text(line).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("INVOICE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                        .tracking(2)
                    Text(invoice.formattedNumber)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(white: 0.83))
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 56)
            .padding(.bottom, 24)

            invoicePDFDivider()

            // Bill To + meta
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    invoicePDFLabel("BILL TO")
                    Text(invoice.client?.name ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    if let company = invoice.client?.companyName, !company.isEmpty {
                        Text(company).font(.system(size: 11)).foregroundColor(Color(white: 0.4))
                    }
                    if let addr = invoice.client?.billingAddress, !addr.isEmpty {
                        Text(addr).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let addr2 = invoice.client?.billingAddress2, !addr2.isEmpty {
                        Text(addr2).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    if let email = invoice.client?.email, !email.isEmpty {
                        Text(email).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                    if let phone = invoice.client?.phone, !phone.isEmpty {
                        Text(phone).font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    invoicePDFMeta("Issue Date", invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
                    invoicePDFMeta("Due Date", invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
                    if !invoice.poNumber.isEmpty {
                        invoicePDFMeta("PO Number", invoice.poNumber)
                    }
                    if !invoice.paymentTerms.isEmpty {
                        invoicePDFMeta("Terms", invoice.paymentTerms)
                    }
                    invoicePDFMeta("Status", invoice.isPaid ? "Paid" : "Unpaid")
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 24)

            invoicePDFTableHeader()

            ForEach(rows) { invoicePDFRowView($0) }

            if isLastPage {
                invoicePDFFooter(invoice: invoice, business: business)
            } else {
                invoiceContinuedIndicator()
            }

            Spacer(minLength: 40)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - PDF continuation page layout

private struct InvoiceContinuationPageLayout: View {
    let invoice: Invoice
    let business: BusinessInfo
    let rows: [InvoicePDFRow]
    let pageNumber: Int
    let totalPages: Int
    let isLastPage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(business.name.isEmpty ? "Freelancer" : business.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                    Text(invoice.formattedNumber)
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

            invoicePDFTableHeader()

            ForEach(rows) { invoicePDFRowView($0) }

            if isLastPage {
                invoicePDFFooter(invoice: invoice, business: business)
            } else {
                invoiceContinuedIndicator()
            }

            Spacer(minLength: 40)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - PDF generation (multi-page)

@MainActor
func makeInvoicePDF(invoice: Invoice, userName: String) -> URL? {
    let business = BusinessInfo.load(fallbackName: userName)
    let allRows = invoicePDFRows(for: invoice)

    // Page 1 has a taller business header + bill-to overhead; later pages are compact.
    let firstPageMax = 6
    let contPageMax  = 10

    var pageRows: [[InvoicePDFRow]] = []
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

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(invoice.formattedNumber).pdf")

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
            renderer = ImageRenderer(content: AnyView(InvoiceFirstPageLayout(
                invoice: invoice, business: business, rows: rows, isLastPage: isLast
            )))
        } else {
            renderer = ImageRenderer(content: AnyView(InvoiceContinuationPageLayout(
                invoice: invoice, business: business, rows: rows,
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
