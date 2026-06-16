import SwiftUI
import SwiftData

struct TimeHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    private var months: [Date] {
        let cal = Calendar.current
        let starts = Set(allEntries.map { cal.startOfMonth(for: $0.date) })
        return starts.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(months, id: \.self) { monthStart in
                    let monthEntries = entries(for: monthStart)
                    let hours = monthEntries.reduce(0.0) { $0 + $1.hours }
                    let earnings = monthEntries.reduce(0.0) { $0 + $1.earnings }
                    let count = monthEntries.count

                    NavigationLink {
                        TimeMonthDetailView(monthStart: monthStart)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center) {
                                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f hrs", hours))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.indigo.opacity(0.12), in: Capsule())
                            }
                            HStack(spacing: 4) {
                                Text("\(count) \(count == 1 ? "entry" : "entries")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(earnings, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Time History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if allEntries.isEmpty {
                    ContentUnavailableView(
                        "No Time Logged",
                        systemImage: "clock",
                        description: Text("Logged time will appear here grouped by month.")
                    )
                }
            }
        }
    }

    private func entries(for monthStart: Date) -> [TimeEntry] {
        let cal = Calendar.current
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return allEntries.filter { $0.date >= monthStart && $0.date < monthEnd }
    }
}

#Preview {
    TimeHistoryView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self], inMemory: true)
}
