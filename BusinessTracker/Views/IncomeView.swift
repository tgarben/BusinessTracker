import SwiftUI
import SwiftData

// MARK: - Income row (used in ClientDetailView)

struct IncomeRow: View {
    let entry: IncomeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(entry.source)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.amount.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 12)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Income edit sheet (used in ClientDetailView)

struct IncomeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    let entry: IncomeEntry

    @State private var date: Date = .now
    @State private var source: String = ""
    @State private var amountText: String = ""
    @State private var selectedClient: Client?
    @State private var notes: String = ""

    private let sourcePresets = [
        "Invoice Payment", "Retainer", "Project Fee", "Consulting", "Other"
    ]

    private var canSave: Bool {
        !source.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
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
                            ForEach(sourcePresets, id: \.self) { preset in
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

                Section("Client") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit Income")
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
        .onAppear { load() }
    }

    private func load() {
        date = entry.date
        source = entry.source
        amountText = String(format: "%.2f", entry.amount)
        selectedClient = entry.client
        notes = entry.notes
    }

    private func save() {
        entry.date = date
        entry.source = source.trimmingCharacters(in: .whitespaces)
        entry.amount = Double(amountText) ?? 0
        entry.client = selectedClient
        entry.notes = notes
        dismiss()
    }
}
