import SwiftUI
import SwiftData

struct TimeMonthDetailView: View {
    let monthStart: Date
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }) private var entries: [TimeEntry]

    init(monthStart: Date) {
        self.monthStart = monthStart
        let end = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _entries = Query(
            filter: #Predicate<TimeEntry> { entry in
                entry.date >= monthStart && entry.date < end && entry.deletedDate == nil
            },
            sort: \TimeEntry.date,
            order: .reverse
        )
    }

    private var totalHours: Double    { entries.reduce(0) { $0 + $1.hours } }
    private var totalEarnings: Double { entries.reduce(0) { $0 + $1.earnings } }

    private var title: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    @State private var entryToEdit: TimeEntry?
    @State private var pendingDelete: ([TimeEntry], IndexSet)?

    var body: some View {
        List {
            // Month summary at top
            Section {
                MonthHoursSummaryCard(hours: totalHours, earnings: totalEarnings, label: "\(title) Hours")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Entries grouped by day
            let grouped = Dictionary(grouping: entries) {
                Calendar.current.startOfDay(for: $0.date)
            }
            let sortedDays = grouped.keys.sorted(by: >)

            ForEach(sortedDays, id: \.self) { day in
                Section(header: Text(day, style: .date)) {
                    ForEach(grouped[day] ?? []) { entry in
                        TimeEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { entryToEdit = entry }
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
        .sheet(item: $entryToEdit) { entry in
            TimeEntryEditView(entry: entry)
        }
        .confirmationDialog("Delete Time Entry?", isPresented: Binding(
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

// MARK: - Month summary card

private struct MonthHoursSummaryCard: View {
    let hours: Double
    let earnings: Double
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            item(value: String(format: "%.1f", hours), unit: "hrs", caption: label)
            Divider().frame(height: 40)
            item(value: earnings.formatted(.currency(code: "USD")), unit: nil, caption: "Earned")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func item(value: String, unit: String?, caption: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.bold())
                if let unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
