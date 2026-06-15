import SwiftUI
import SwiftData

struct ExpensePresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpensePreset.sortOrder) private var presets: [ExpensePreset]

    @State private var showAdd = false
    @State private var presetToEdit: ExpensePreset?

    var body: some View {
        List {
            if presets.isEmpty {
                Text("No expense presets yet. Tap + to save a recurring expense template.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(presets) { preset in
                    Button {
                        presetToEdit = preset
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: Expense.categoryIcon(preset.category))
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).font(.body).foregroundStyle(.primary)
                                Text(preset.category).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let amount = preset.amount {
                                Text(amount.formatted(.currency(code: "USD")))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(presets[i]) }
                }
                .onMove { source, dest in
                    var reordered = presets
                    reordered.move(fromOffsets: source, toOffset: dest)
                    for (i, p) in reordered.enumerated() { p.sortOrder = i }
                }
            }
        }
        .navigationTitle("Expense Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showAdd) { AddEditExpensePresetView() }
        .sheet(item: $presetToEdit) { AddEditExpensePresetView(preset: $0) }
    }
}

struct AddEditExpensePresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpensePreset.sortOrder) private var existing: [ExpensePreset]

    var preset: ExpensePreset?

    @State private var name = ""
    @State private var category = Expense.categories[0]
    @State private var useAmount = false
    @State private var amountText = ""
    @State private var notes = ""

    private var isEditing: Bool { preset != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. Adobe Subscription", text: $name)
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(Expense.categories, id: \.self) { cat in
                            Label(cat, systemImage: Expense.categoryIcon(cat)).tag(cat)
                        }
                    }
                    Toggle("Fixed Amount", isOn: $useAmount)
                    if useAmount {
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
                } header: {
                    Text("Details")
                } footer: {
                    Text(useAmount
                         ? "This amount pre-fills when you use the preset (still editable)."
                         : "Leave off for expenses where the amount varies each time.")
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let preset else { return }
        name = preset.name
        category = preset.category.isEmpty ? Expense.categories[0] : preset.category
        notes = preset.notes
        if let amount = preset.amount {
            useAmount = true
            amountText = String(format: "%.2f", amount)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let amount: Double? = useAmount ? (Double(amountText) ?? 0) : nil
        if let preset {
            preset.name = trimmed
            preset.category = category
            preset.amount = amount
            preset.notes = notes
        } else {
            modelContext.insert(ExpensePreset(
                name: trimmed, amount: amount, category: category, notes: notes, sortOrder: existing.count
            ))
        }
        dismiss()
    }
}
