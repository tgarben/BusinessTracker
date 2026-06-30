import SwiftUI
import SwiftData
import PhotosUI

private let incomeSourcePresets = [
    "Invoice Payment", "Retainer", "Project Fee", "Consulting", "Other"
]

// MARK: - Clients Tab

struct ClientsView: View {
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]
    @Environment(\.modelContext) private var modelContext
    @Environment(Entitlements.self) private var pro

    @State private var showAddClient = false
    @State private var showSettings = false
    @State private var pendingDelete: IndexSet?
    @State private var paywall: ProFeature?

    /// Soft-deletes a client and cascades the trash to all of its child records
    /// (time, income, expenses, mileage, invoices, quotes) so none linger in global
    /// lists during the 30-day window. Projects aren't soft-deletable — they're removed
    /// by the real cascade when the client is permanently purged. Restoring the
    /// client (from Recently Deleted) brings back the client only; the children
    /// keep their own 30-day trash timers.
    private func softDeleteClient(_ client: Client) {
        let now = Date.now
        for t in (client.timeEntries ?? [])   where t.deletedDate == nil { t.deletedDate = now }
        for i in (client.incomeEntries ?? []) where i.deletedDate == nil { i.deletedDate = now }
        for e in (client.expenses ?? [])      where e.deletedDate == nil { e.deletedDate = now }
        for m in (client.mileageTrips ?? [])  where m.deletedDate == nil { m.deletedDate = now }
        for inv in (client.invoices ?? [])    where inv.deletedDate == nil { inv.deletedDate = now }
        for q in (client.quotes ?? [])        where q.deletedDate == nil { q.deletedDate = now }
        client.deletedDate = now
    }

    var body: some View {
        NavigationStack {
            List {
                // ===== Free-tier usage hint — REMOVE this block (and the
                // FreeClientUsageHint view below) to drop the feature entirely. =====
                if Entitlements.monetizationEnabled && !pro.isProEffective {
                    FreeClientUsageHint(used: clients.count)
                }
                // ====================================================================

                ForEach(clients) { client in
                    NavigationLink {
                        ClientDetailView(client: client)
                    } label: {
                        ClientCell(client: client)
                    }
                }
                .onDelete { pendingDelete = $0 }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients",
                        systemImage: "person.2",
                        description: Text("Tap + to add your first client.")
                    )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if pro.canCreateClient(currentCount: clients.count) {
                        showAddClient = true
                    } else {
                        paywall = .unlimitedClients
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 55, height: 55)
                        .background(.teal, in: Circle())
                        .shadow(color: .teal.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .accessibilityLabel("Add Client")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        ProfileToolbarLabel()
                    }
                    .accessibilityLabel("Profile & Settings")
                }
            }
            .sheet(isPresented: $showAddClient) { AddEditClientView() }
            .sheet(isPresented: $showSettings)   { SettingsView() }
            .proPaywall($paywall)
            .confirmationDialog("Delete Client?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDelete {
                        for index in offsets { softDeleteClient(clients[index]) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("The client and all its time, income, expenses, mileage, invoices and quotes are moved to Recently Deleted. Restoring brings back the client only.")
            }
        }
    }
}

// ===== Free-tier usage hint (REMOVABLE) =================================
// Self-contained "X of N free clients used" row, shown only when monetization
// is live and the user is on the free tier. To remove the feature, delete this
// view and its single call site in `ClientsView.body`.
private struct FreeClientUsageHint: View {
    let used: Int

    var body: some View {
        let limit = Entitlements.freeClientLimit
        let atCap = used >= limit
        HStack(spacing: 12) {
            Image(systemName: atCap ? "lock.fill" : "person.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(atCap ? Color.orange : Color.teal, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(min(used, limit)) of \(limit) free clients used")
                    .font(.subheadline.weight(.medium))
                Text(atCap ? "Upgrade to Pro for unlimited clients." : "Your free plan includes \(limit) clients.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
// ========================================================================

// MARK: - Client cell

private struct ClientCell: View {
    let client: Client

    private var totalEarnings: Double {
        let time   = (client.timeEntries ?? []).filter { $0.deletedDate == nil }.reduce(0.0) { $0 + $1.earnings }
        let income = (client.incomeEntries ?? []).filter { $0.deletedDate == nil }.reduce(0.0) { $0 + $1.amount }
        return time + income
    }

    private var totalHours: Double {
        (client.timeEntries ?? []).filter { $0.deletedDate == nil }.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(photoData: client.photoData, name: client.name, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name).font(.headline)
                let payments = (client.incomeEntries ?? []).filter { $0.deletedDate == nil }.count
                Text(String(format: "%.1f hrs · %d payment%@",
                            totalHours, payments, payments == 1 ? "" : "s"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(totalEarnings.asCurrency)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.green.opacity(0.1), in: Capsule())
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Client avatar (shared with AddEditClientView)

struct ClientAvatar: View {
    let photoData: Data?
    let name: String
    let size: CGFloat

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let data = photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.teal.opacity(0.15)
                    Text(initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(.teal)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Client detail view

struct ClientDetailView: View {
    let client: Client
    @Environment(\.modelContext) private var modelContext
    @Environment(Entitlements.self) private var pro

    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<IncomeEntry> { $0.deletedDate == nil }) private var incomeEntries: [IncomeEntry]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }) private var expenses: [Expense]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }) private var mileageTrips: [MileageTrip]
    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil }) private var invoices: [Invoice]
    @Query(filter: #Predicate<Quote> { $0.deletedDate == nil }) private var quotes: [Quote]

    init(client: Client) {
        self.client = client
        let id = client.persistentModelID
        _timeEntries = Query(
            filter: #Predicate<TimeEntry> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \TimeEntry.date, order: .reverse
        )
        _incomeEntries = Query(
            filter: #Predicate<IncomeEntry> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \IncomeEntry.date, order: .reverse
        )
        _expenses = Query(
            filter: #Predicate<Expense> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \Expense.date, order: .reverse
        )
        _mileageTrips = Query(
            filter: #Predicate<MileageTrip> { $0.client?.persistentModelID == id && $0.deletedDate == nil && !$0.needsReview },
            sort: \MileageTrip.date, order: .reverse
        )
        _invoices = Query(
            filter: #Predicate<Invoice> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \Invoice.invoiceNumber, order: .reverse
        )
        _quotes = Query(
            filter: #Predicate<Quote> { $0.client?.persistentModelID == id && $0.deletedDate == nil },
            sort: \Quote.quoteNumber, order: .reverse
        )
    }

    @State private var showEditClient = false
    @State private var showLogIncome = false
    @State private var showCreateInvoice = false
    @State private var showCreateQuote = false
    @State private var viewingQuote: Quote?
    @State private var pendingDeleteQuote: ([Quote], IndexSet)?
    @State private var editingIncome: IncomeEntry?
    @State private var editingTimeEntry: TimeEntry?
    @State private var editingExpense: Expense?
    @State private var editingTrip: MileageTrip?
    @State private var pendingDeleteTrip: ([MileageTrip], IndexSet)?
    @State private var viewingInvoice: Invoice?
    @State private var pendingDeleteIncome: ([IncomeEntry], IndexSet)?
    @State private var pendingDeleteTime: ([TimeEntry], IndexSet)?
    @State private var pendingDeleteExpense: ([Expense], IndexSet)?
    @State private var pendingDeleteInvoice: ([Invoice], IndexSet)?
    @State private var paywall: ProFeature?

    // MARK: All-time aggregates (header stats)

    private var totalEarnings: Double {
        let time   = timeEntries.reduce(0.0) { $0 + $1.earnings }
        let income = incomeEntries.reduce(0.0) { $0 + $1.amount }
        return time + income
    }

    private var totalExpenses: Double {
        expenses.reduce(0.0) { $0 + $1.amount }
    }

    private var totalHours: Double {
        timeEntries.reduce(0) { $0 + $1.hours }
    }

    private var clientMiles: Double {
        mileageTrips.reduce(0) { $0 + $1.miles }
    }

    private var clientReimbursement: Double {
        mileageTrips.reduce(0) { $0 + $1.reimbursementAmount }
    }

    private var mileageSummaryLabel: String {
        let miles = clientMiles.formatted(.number.precision(.fractionLength(1)))
        return "\(miles) mi · \(clientReimbursement.asCurrency)"
    }

    // MARK: Monthly P&L aggregates

    private var monthStart: Date { Calendar.current.startOfMonth(for: .now) }

    private var monthTimeEarnings: Double {
        timeEntries.filter { $0.date >= monthStart }.reduce(0.0) { $0 + $1.earnings }
    }

    private var monthIncomeReceived: Double {
        incomeEntries.filter { $0.date >= monthStart }.reduce(0.0) { $0 + $1.amount }
    }

    private var monthExpenses: Double {
        expenses.filter { $0.date >= monthStart }.reduce(0.0) { $0 + $1.amount }
    }

    private var monthNet: Double { monthTimeEarnings + monthIncomeReceived - monthExpenses }

    private var hasMonthData: Bool {
        monthTimeEarnings > 0 || monthIncomeReceived > 0 || monthExpenses > 0
    }

    @ViewBuilder private var expensesSection: some View {
        Section("Expenses") {
            if expenses.isEmpty {
                Text("No expenses logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(expenses) { expense in
                    ExpenseRow(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture { editingExpense = expense }
                }
                .onDelete { pendingDeleteExpense = (expenses, $0) }
            }
        }
    }

    @ViewBuilder private var timeEntriesSection: some View {
        Section("Time Entries") {
            if timeEntries.isEmpty {
                Text("No time entries yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(timeEntries) { entry in
                    ClientTimeEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTimeEntry = entry }
                }
                .onDelete { pendingDeleteTime = (timeEntries, $0) }
            }
        }
    }

    @ViewBuilder private var mileageSection: some View {
        Section {
            if mileageTrips.isEmpty {
                Text("No trips linked yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(mileageTrips) { trip in
                    TripRow(trip: trip)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTrip = trip }
                }
                .onDelete { pendingDeleteTrip = (mileageTrips, $0) }
            }
        } header: {
            HStack {
                Text("Mileage")
                Spacer()
                if !mileageTrips.isEmpty {
                    Text(mileageSummaryLabel)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .textCase(nil)
                }
            }
        } footer: {
            Text("Link a trip to this client from the Mileage tab (tap a trip → Client) so it's grouped here for reports and taxes.")
        }
    }

    @ViewBuilder private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                ClientAvatar(photoData: client.photoData, name: client.name, size: 100)

                Text(client.name).font(.title2.bold())

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(totalEarnings.asCurrency)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        Text("Earned").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 28)
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f hrs", totalHours))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text("Hours").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 28)
                    VStack(spacing: 2) {
                        Text(totalExpenses.asCurrency)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        Text("Expenses").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder private var plSection: some View {
        if hasMonthData {
            Section {
                ClientPLCard(
                    monthLabel: Date.now.formatted(.dateTime.month(.wide)),
                    timeEarnings: monthTimeEarnings,
                    incomeReceived: monthIncomeReceived,
                    expenses: monthExpenses,
                    net: monthNet
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder private var quotesSection: some View {
        Section {
            if quotes.isEmpty {
                Text("No quotes yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(quotes) { quote in
                    QuoteRow(quote: quote)
                        .contentShape(Rectangle())
                        .onTapGesture { viewingQuote = quote }
                }
                .onDelete { pendingDeleteQuote = (quotes, $0) }
            }
        } header: {
            HStack {
                Text("Quotes")
                Spacer()
                Button {
                    if pro.isProEffective { showCreateQuote = true } else { paywall = .quotes }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("New Quote")
            }
        }
    }

    @ViewBuilder private var invoicesSection: some View {
        Section {
            if invoices.isEmpty {
                Text("No invoices yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(invoices) { invoice in
                    InvoiceRow(invoice: invoice)
                        .contentShape(Rectangle())
                        .onTapGesture { viewingInvoice = invoice }
                }
                .onDelete { pendingDeleteInvoice = (invoices, $0) }
            }
        } header: {
            HStack {
                Text("Invoices")
                Spacer()
                Button {
                    if pro.isProEffective { showCreateInvoice = true } else { paywall = .invoicing }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("New Invoice")
            }
        }
    }

    @ViewBuilder private var incomeSection: some View {
        Section {
            if incomeEntries.isEmpty {
                Text("No income logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(incomeEntries) { entry in
                    IncomeRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { editingIncome = entry }
                }
                .onDelete { pendingDeleteIncome = (incomeEntries, $0) }
            }
        } header: {
            HStack {
                Text("Income")
                Spacer()
                Button { showLogIncome = true } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("Log Income")
            }
        }
    }

    var body: some View {
        List {
            headerSection
            plSection
            quotesSection
            invoicesSection
            incomeSection
            expensesSection
            timeEntriesSection
            mileageSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditClient = true }
            }
        }
        .sheet(isPresented: $showEditClient)    { AddEditClientView(existingClient: client) }
        .sheet(isPresented: $showLogIncome)   { LogIncomeForClientView(client: client) }
        .sheet(isPresented: $showCreateInvoice) { CreateInvoiceView(client: client) }
        .sheet(isPresented: $showCreateQuote)   { CreateQuoteView(client: client) }
        .sheet(item: $viewingQuote)           { QuoteDetailView(quote: $0) }
        .proPaywall($paywall)
        .sheet(item: $editingIncome)          { IncomeEditView(entry: $0) }
        .sheet(item: $editingExpense)         { ExpenseEditView(expense: $0) }
        .sheet(item: $editingTimeEntry)       { TimeEntryEditView(entry: $0) }
        .sheet(item: $editingTrip)            { MileageTripEditView(trip: $0) }
        .sheet(item: $viewingInvoice)         { InvoiceDetailView(invoice: $0) }
        .confirmationDialog("Delete Income Entry?", isPresented: Binding(
            get: { pendingDeleteIncome != nil },
            set: { if !$0 { pendingDeleteIncome = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteIncome {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteIncome = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteIncome = nil }
        } message: { Text("You can restore this from Recently Deleted for 30 days.") }
        .confirmationDialog("Delete Expense?", isPresented: Binding(
            get: { pendingDeleteExpense != nil },
            set: { if !$0 { pendingDeleteExpense = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteExpense {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteExpense = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteExpense = nil }
        } message: { Text("You can restore this from Recently Deleted for 30 days.") }
        .confirmationDialog("Delete Time Entry?", isPresented: Binding(
            get: { pendingDeleteTime != nil },
            set: { if !$0 { pendingDeleteTime = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteTime {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteTime = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteTime = nil }
        } message: { Text("You can restore this from Recently Deleted for 30 days.") }
        .confirmationDialog("Delete Trip?", isPresented: Binding(
            get: { pendingDeleteTrip != nil },
            set: { if !$0 { pendingDeleteTrip = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteTrip {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteTrip = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteTrip = nil }
        } message: { Text("You can restore this from Recently Deleted for 30 days.") }
        .confirmationDialog("Delete Invoice?", isPresented: Binding(
            get: { pendingDeleteInvoice != nil },
            set: { if !$0 { pendingDeleteInvoice = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteInvoice {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteInvoice = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteInvoice = nil }
        } message: { Text("The invoice is moved to Recently Deleted. Restore within 30 days to recover it.") }
        .confirmationDialog("Delete Quote?", isPresented: Binding(
            get: { pendingDeleteQuote != nil },
            set: { if !$0 { pendingDeleteQuote = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteQuote {
                    for i in offsets { items[i].deletedDate = .now }
                }
                pendingDeleteQuote = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteQuote = nil }
        } message: { Text("The quote is moved to Recently Deleted. Restore within 30 days to recover it.") }
    }
}

// MARK: - Client P&L card

private struct ClientPLCard: View {
    let monthLabel: String
    let timeEarnings: Double
    let incomeReceived: Double
    let expenses: Double
    let net: Double

    var body: some View {
        VStack(spacing: 0) {
            if timeEarnings > 0 {
                plRow(label: "Time Earnings", value: timeEarnings, color: .indigo, negative: false)
            }
            if incomeReceived > 0 {
                plRow(label: "Income Received", value: incomeReceived, color: .green, negative: false)
            }
            if expenses > 0 {
                plRow(label: "Expenses", value: expenses, color: .red, negative: true)
            }

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Net \(monthLabel)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(net.asCurrency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(net >= 0 ? .green : .red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((net >= 0 ? Color.green : Color.red).opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func plRow(label: String, value: Double, color: Color, negative: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(negative ? "−" : "")\(value.asCurrency)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - Client time entry row

private struct ClientTimeEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(entry.project?.name ?? "Uncategorized")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.earnings.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.indigo.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 12)
                Text(String(format: "%.2f hrs", entry.hours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if !entry.notes.isEmpty {
                    Text("·").foregroundStyle(.tertiary)
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Log income for client sheet

struct LogIncomeForClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let client: Client

    @State private var date: Date = .now
    @State private var source: String = ""
    @State private var amountText: String = ""
    @State private var notes: String = ""

    private var canSave: Bool {
        !source.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ClientAvatar(photoData: client.photoData, name: client.name, size: 36)
                        Text(client.name).font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Client")
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .onChange(of: amountText) { _, new in
                                var s = new.filter { $0.isNumber || $0 == "." }
                                if let dot = s.firstIndex(of: ".") {
                                    let frac = String(s[s.index(after: dot)...].filter(\.isNumber).prefix(2))
                                    s = String(s[..<dot]) + "." + frac
                                }
                                if s != new { amountText = s }
                            }
                    }
                }

                Section {
                    TextField("e.g. Invoice Payment", text: $source)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(incomeSourcePresets, id: \.self) { preset in
                                Button(preset) { source = preset }
                                    .buttonStyle(.bordered)
                                    .tint(source == preset ? .green : .secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Text("Source")
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Log Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let entry = IncomeEntry(
            date: date,
            source: source.trimmingCharacters(in: .whitespaces),
            amount: Double(amountText) ?? 0,
            notes: notes,
            client: client
        )
        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    ClientsView()
        .environment(Entitlements())
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, IncomeEntry.self], inMemory: true)
}
