import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }, sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \ExpensePreset.sortOrder) private var presets: [ExpensePreset]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("expense_presetInstantSave") private var instantSave: Bool = false

    @State private var showAddExpense = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var editingExpense: Expense?
    @State private var prefillPreset: ExpensePreset?
    @State private var fabExpanded = false
    @State private var pendingDelete: ([Expense], IndexSet)?

    private var monthStart: Date {
        Calendar.current.startOfMonth(for: .now)
    }

    private var monthExpenses: [Expense] {
        expenses.filter { $0.date >= monthStart }
    }

    private var monthTotal: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if !expenses.isEmpty {
                    Section {
                        ExpenseSummaryCard(
                            total: monthTotal,
                            count: monthExpenses.count,
                            label: "\(Date.now.formatted(.dateTime.month(.wide))) Expenses"
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if !expenses.isEmpty {
                    let grouped = Dictionary(grouping: expenses) {
                        Calendar.current.startOfDay(for: $0.date)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)

                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(day, style: .date)) {
                            ForEach(grouped[day] ?? []) { expense in
                                ExpenseRow(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingExpense = expense }
                            }
                            .onDelete { offsets in
                                pendingDelete = (grouped[day] ?? [], offsets)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "No Expenses",
                        systemImage: "creditcard",
                        description: Text("Tap + to log your first business expense.")
                    )
                }
            }
            .overlay(alignment: .bottomTrailing) { expenseFAB }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("History") { showHistory = true }
                        .disabled(expenses.isEmpty)
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
            .sheet(item: $prefillPreset) { preset in
                AddExpenseView(prefillPreset: preset)
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseEditView(expense: expense)
            }
            .sheet(isPresented: $showHistory) {
                ExpenseHistoryView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .confirmationDialog("Delete Expense?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let (items, offsets) = pendingDelete {
                        for index in offsets { items[index].deletedDate = .now }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("You can restore this from Recently Deleted for 30 days.")
            }
        }
    }

    private func deleteExpenses(from list: [Expense], at offsets: IndexSet) {
        for index in offsets { list[index].deletedDate = .now }
    }

    // MARK: - Floating action button + preset speed-dial

    @ViewBuilder
    private var expenseFAB: some View {
        ZStack(alignment: .bottomTrailing) {
            // Tap-to-dismiss scrim while expanded
            if fabExpanded {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .onTapGesture { collapseFAB() }
                    .transition(.opacity)
            }

            VStack(alignment: .trailing, spacing: 12) {
                if fabExpanded {
                    ForEach(presets) { preset in
                        speedDialItem(
                            title: preset.name,
                            subtitle: preset.amount.map { $0.asCurrency } ?? preset.category,
                            icon: Expense.categoryIcon(preset.category)
                        ) { selectPreset(preset) }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    speedDialItem(title: "New Expense", subtitle: "Blank form", icon: "square.and.pencil") {
                        collapseFAB()
                        showAddExpense = true
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button {
                    if presets.isEmpty {
                        showAddExpense = true
                    } else {
                        withAnimation(.spring(duration: 0.3)) { fabExpanded.toggle() }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.red, in: Circle())
                        .rotationEffect(.degrees(fabExpanded ? 45 : 0))
                        .shadow(color: .red.opacity(0.35), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    private func speedDialItem(title: String, subtitle: String?, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                ZStack {
                    Circle().fill(.red).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func collapseFAB() {
        withAnimation(.spring(duration: 0.3)) { fabExpanded = false }
    }

    private func selectPreset(_ preset: ExpensePreset) {
        collapseFAB()
        if instantSave, let amount = preset.amount, amount > 0 {
            let expense = Expense(
                date: .now,
                amount: amount,
                category: preset.category,
                notes: preset.notes,
                client: nil
            )
            modelContext.insert(expense)
        } else {
            prefillPreset = preset
        }
    }
}

// MARK: - Summary card

struct ExpenseSummaryCard: View {
    let total: Double
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(total.asCurrency)
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 3) {
                Text("\(count)")
                    .font(.title2.bold())
                Text("Transactions").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Expense row

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category badge + amount
            HStack(alignment: .center) {
                Label(expense.category, systemImage: Expense.categoryIcon(expense.category))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(expense.amount.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.1), in: Capsule())
            }

            // Client + notes row
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 12)

                if let client = expense.client {
                    Text(client.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No client")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !expense.notes.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(expense.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                let receiptCount = expense.receiptImagesData.isEmpty
                    ? (expense.receiptImageData != nil ? 1 : 0)
                    : expense.receiptImagesData.count
                if receiptCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "paperclip")
                        if receiptCount > 1 {
                            Text("\(receiptCount)").font(.caption2)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpensesView()
        .modelContainer(for: [Expense.self, Client.self], inMemory: true)
}
