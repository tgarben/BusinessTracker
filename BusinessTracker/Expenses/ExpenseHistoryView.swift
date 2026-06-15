import SwiftUI
import SwiftData

struct ExpenseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }, sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]

    private var months: [Date] {
        let cal = Calendar.current
        let starts = Set(allExpenses.map { cal.startOfMonth(for: $0.date) })
        return starts.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(months, id: \.self) { monthStart in
                    let monthExpenses = expenses(for: monthStart)
                    let total = monthExpenses.reduce(0.0) { $0 + $1.amount }
                    let count = monthExpenses.count

                    NavigationLink {
                        ExpenseMonthDetailView(monthStart: monthStart)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center) {
                                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                                    .font(.headline)
                                Spacer()
                                Text(total.formatted(.currency(code: "USD")))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.1), in: Capsule())
                            }
                            Text("\(count) \(count == 1 ? "transaction" : "transactions")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expense History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if allExpenses.isEmpty {
                    ContentUnavailableView(
                        "No Expenses Yet",
                        systemImage: "creditcard",
                        description: Text("Logged expenses will appear here grouped by month.")
                    )
                }
            }
        }
    }

    private func expenses(for monthStart: Date) -> [Expense] {
        let cal = Calendar.current
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return allExpenses.filter { $0.date >= monthStart && $0.date < monthEnd }
    }
}
