import SwiftUI
import SwiftData
import PhotosUI

private let incomeSourcePresets = [
    "Invoice Payment", "Retainer", "Project Fee", "Consulting", "Other"
]

// MARK: - Clients Tab

struct ClientsView: View {
    @Query(sort: \Client.name) private var clients: [Client]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddClient = false
    @State private var showSettings = false
    @State private var pendingDelete: IndexSet?

    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddClient = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClient) { AddEditClientView() }
            .sheet(isPresented: $showSettings)   { SettingsView() }
            .confirmationDialog("Delete Client?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDelete {
                        for index in offsets { modelContext.delete(clients[index]) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This will also delete all projects under this client. This cannot be undone.")
            }
        }
    }
}

// MARK: - Client cell

private struct ClientCell: View {
    let client: Client

    private var totalEarnings: Decimal {
        let time   = client.timeEntries.reduce(Decimal(0)) { $0 + $1.earnings }
        let income = client.incomeEntries.reduce(Decimal(0)) { $0 + $1.amount }
        return time + income
    }

    private var totalHours: Double {
        client.timeEntries.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(photoData: client.photoData, name: client.name, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name).font(.headline)
                let payments = client.incomeEntries.count
                Text(String(format: "%.1f hrs · %d payment%@",
                            totalHours, payments, payments == 1 ? "" : "s"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(totalEarnings.formatted(.currency(code: "USD")))
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
                    Color.indigo.opacity(0.15)
                    Text(initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(.indigo)
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

    @Query private var timeEntries: [TimeEntry]
    @Query private var incomeEntries: [IncomeEntry]

    init(client: Client) {
        self.client = client
        let id = client.persistentModelID
        _timeEntries = Query(
            filter: #Predicate<TimeEntry> { $0.client?.persistentModelID == id },
            sort: \TimeEntry.date, order: .reverse
        )
        _incomeEntries = Query(
            filter: #Predicate<IncomeEntry> { $0.client?.persistentModelID == id },
            sort: \IncomeEntry.date, order: .reverse
        )
    }

    @State private var showEditClient = false
    @State private var showLogIncome = false
    @State private var editingIncome: IncomeEntry?
    @State private var editingTimeEntry: TimeEntry?
    @State private var pendingDeleteIncome: ([IncomeEntry], IndexSet)?
    @State private var pendingDeleteTime: ([TimeEntry], IndexSet)?

    private var totalEarnings: Decimal {
        let time   = timeEntries.reduce(Decimal(0)) { $0 + $1.earnings }
        let income = incomeEntries.reduce(Decimal(0)) { $0 + $1.amount }
        return time + income
    }

    private var totalHours: Double {
        timeEntries.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        List {
            // MARK: Photo header
            Section {
                VStack(spacing: 12) {
                    ClientAvatar(photoData: client.photoData, name: client.name, size: 100)

                    Text(client.name).font(.title2.bold())

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text(totalEarnings.formatted(.currency(code: "USD")))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                            Text("Total Earned").font(.caption2).foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 28)
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f hrs", totalHours))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.indigo)
                            Text("Hours Tracked").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // MARK: Income section
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
                }
            }

            // MARK: Time entries section
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
        .listStyle(.insetGrouped)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditClient = true }
            }
        }
        .sheet(isPresented: $showEditClient)  { AddEditClientView(existingClient: client) }
        .sheet(isPresented: $showLogIncome)   { LogIncomeForClientView(client: client) }
        .sheet(item: $editingIncome)          { IncomeEditView(entry: $0) }
        .sheet(item: $editingTimeEntry)       { TimeEntryEditView(entry: $0) }
        .confirmationDialog("Delete Income Entry?", isPresented: Binding(
            get: { pendingDeleteIncome != nil },
            set: { if !$0 { pendingDeleteIncome = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteIncome {
                    for i in offsets { modelContext.delete(items[i]) }
                }
                pendingDeleteIncome = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteIncome = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog("Delete Time Entry?", isPresented: Binding(
            get: { pendingDeleteTime != nil },
            set: { if !$0 { pendingDeleteTime = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let (items, offsets) = pendingDeleteTime {
                    for i in offsets { modelContext.delete(items[i]) }
                }
                pendingDeleteTime = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteTime = nil }
        } message: { Text("This cannot be undone.") }
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
                Text(entry.earnings.formatted(.currency(code: "USD")))
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
        (Decimal(string: amountText) ?? 0) > 0
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
            amount: Decimal(string: amountText) ?? 0,
            notes: notes,
            client: client
        )
        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    ClientsView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, IncomeEntry.self], inMemory: true)
}
