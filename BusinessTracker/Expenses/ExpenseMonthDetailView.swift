import SwiftUI
import SwiftData

struct ExpenseMonthDetailView: View {
    let monthStart: Date
    @Environment(\.modelContext) private var modelContext

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    @Query private var expenses: [Expense]

    init(monthStart: Date) {
        self.monthStart = monthStart
        let end = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= monthStart && expense.date < end
            },
            sort: \Expense.date,
            order: .reverse
        )
    }

    private var total: Decimal { expenses.reduce(0) { $0 + $1.amount } }

    private var title: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    @State private var editingExpense: Expense?
    @State private var pendingDelete: ([Expense], IndexSet)?

    var body: some View {
        List {
            Section {
                ExpenseSummaryCard(
                    total: total,
                    count: expenses.count,
                    label: "\(title) Expenses"
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

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
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
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

    private func deleteExpenses(from list: [Expense], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(list[index]) }
    }
}
