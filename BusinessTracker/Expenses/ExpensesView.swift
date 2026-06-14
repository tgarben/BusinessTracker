import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddExpense = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var editingExpense: Expense?
    @State private var pendingDelete: ([Expense], IndexSet)?

    private var monthStart: Date {
        Calendar.current.startOfMonth(for: .now)
    }

    private var monthExpenses: [Expense] {
        expenses.filter { $0.date >= monthStart }
    }

    private var monthTotal: Decimal {
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
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarSpacer(placement: .topBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                    Button("History") { showHistory = true }
                        .disabled(expenses.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddExpense = true } label: {
                        Image(systemName: "plus")
                    }
                }

            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
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
                        for index in offsets { modelContext.delete(items[index]) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func deleteExpenses(from list: [Expense], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(list[index]) }
    }
}

// MARK: - Summary card

struct ExpenseSummaryCard: View {
    let total: Decimal
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(total.formatted(.currency(code: "USD")))
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
                Text(expense.amount.formatted(.currency(code: "USD")))
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
