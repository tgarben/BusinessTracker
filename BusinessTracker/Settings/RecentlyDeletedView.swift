import SwiftUI
import SwiftData

/// Shows all soft-deleted records across every type. Items can be restored
/// (clears `deletedDate`) or permanently deleted. Anything left untouched is
/// automatically purged 30 days after deletion by `BusinessTrackerApp.purgeExpiredTrash()`.
struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TimeEntry>   { $0.deletedDate != nil }) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate != nil }) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense>     { $0.deletedDate != nil }) private var expenses: [Expense]
    @Query(filter: #Predicate<IncomeEntry> { $0.deletedDate != nil }) private var incomeEntries: [IncomeEntry]
    @Query(filter: #Predicate<Invoice>     { $0.deletedDate != nil }) private var invoices: [Invoice]
    @Query(filter: #Predicate<Quote>       { $0.deletedDate != nil }) private var quotes: [Quote]
    @Query(filter: #Predicate<Client>      { $0.deletedDate != nil }) private var clients: [Client]

    @State private var pendingPurgeAll = false

    // MARK: Row model

    private struct Row: Identifiable {
        let id: PersistentIdentifier
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let deletedDate: Date
        let daysLeft: Int
        let restore: () -> Void
        let purge: () -> Void
    }

    private func row(for model: some SoftDeletable & PersistentModel,
                     icon: String, color: Color, title: String, subtitle: String) -> Row {
        Row(
            id: model.persistentModelID,
            icon: icon, color: color, title: title, subtitle: subtitle,
            deletedDate: model.deletedDate ?? .now,
            daysLeft: model.trashDaysRemaining,
            restore: { model.deletedDate = nil },
            purge: { modelContext.delete(model) }
        )
    }

    private var rows: [Row] {
        var all: [Row] = []

        for t in timeEntries {
            let label = t.project?.name ?? t.client?.name ?? "Uncategorized"
            all.append(row(for: t, icon: "clock.fill", color: .indigo, title: label,
                           subtitle: "\(String(format: "%.2f", t.hours)) hrs · \(t.date.formatted(date: .abbreviated, time: .omitted))"))
        }
        for trip in trips {
            let route = "\(trip.startLocation) → \(trip.endLocation)"
            all.append(row(for: trip, icon: "car.fill", color: .blue, title: route,
                           subtitle: "\(String(format: "%.1f", trip.miles)) mi · \(trip.date.formatted(date: .abbreviated, time: .omitted))"))
        }
        for e in expenses {
            all.append(row(for: e, icon: Expense.categoryIcon(e.category), color: .red, title: e.category,
                           subtitle: "\(e.amount.asCurrency) · \(e.date.formatted(date: .abbreviated, time: .omitted))"))
        }
        for inc in incomeEntries {
            all.append(row(for: inc, icon: "dollarsign.circle.fill", color: .green, title: inc.source.isEmpty ? "Income" : inc.source,
                           subtitle: "\(inc.amount.asCurrency) · \(inc.date.formatted(date: .abbreviated, time: .omitted))"))
        }
        for inv in invoices {
            all.append(row(for: inv, icon: "doc.text.fill", color: .purple, title: inv.displayTitle,
                           subtitle: "\(inv.subtotal.asCurrency) · \(inv.issueDate.formatted(date: .abbreviated, time: .omitted))"))
        }
        for q in quotes {
            all.append(row(for: q, icon: "list.clipboard.fill", color: .teal, title: q.displayTitle,
                           subtitle: "\(q.total.asCurrency) · \(q.issueDate.formatted(date: .abbreviated, time: .omitted))"))
        }
        for c in clients {
            all.append(row(for: c, icon: "person.fill", color: .indigo, title: c.name.isEmpty ? "Client" : c.name,
                           subtitle: "Client"))
        }

        return all.sorted { $0.deletedDate > $1.deletedDate }
    }

    var body: some View {
        List {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(row.color)
                        .frame(width: 26, height: 26)
                        .background(row.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(row.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }

                    Spacer()

                    Text(row.daysLeft == 0 ? "Today" : "\(row.daysLeft)d left")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(row.daysLeft <= 3 ? .orange : .secondary)
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { row.restore() } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { row.purge() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView(
                    "Nothing Deleted",
                    systemImage: "trash.slash",
                    description: Text("Deleted items appear here for 30 days, then are removed permanently.")
                )
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !rows.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) { pendingPurgeAll = true }
                }
            }
        }
        .confirmationDialog("Permanently Delete All?", isPresented: $pendingPurgeAll, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { purgeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every item in Recently Deleted. This cannot be undone.")
        }
    }

    private func purgeAll() {
        for t in timeEntries   { modelContext.delete(t) }
        for t in trips         { modelContext.delete(t) }
        for e in expenses      { modelContext.delete(e) }
        for i in incomeEntries { modelContext.delete(i) }
        for i in invoices      { modelContext.delete(i) }
        for q in quotes        { modelContext.delete(q) }
        for c in clients       { modelContext.delete(c) }
    }
}
