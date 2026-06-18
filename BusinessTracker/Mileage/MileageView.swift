import SwiftUI
import SwiftData

struct MileageView: View {
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }, sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Environment(\.modelContext) private var modelContext

    @State private var showLogTrip = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var editingTrip: MileageTrip?
    @State private var pendingDelete: ([MileageTrip], IndexSet)?

    private var monthTrips: [MileageTrip] {
        let start = Calendar.current.startOfMonth(for: .now)
        return trips.filter { $0.date >= start }
    }

    private var monthMiles: Double        { monthTrips.reduce(0) { $0 + $1.miles } }
    private var monthReimbursement: Double { monthTrips.reduce(0) { $0 + $1.reimbursementAmount } }

    var body: some View {
        NavigationStack {
            List {
                if !trips.isEmpty {
                    Section {
                        MileageSummaryCard(
                            miles: monthMiles,
                            reimbursement: monthReimbursement,
                            label: "\(Date.now.formatted(.dateTime.month(.wide))) Miles"
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if !trips.isEmpty {
                    let grouped = Dictionary(grouping: trips) {
                        Calendar.current.startOfDay(for: $0.date)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)

                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(day, style: .date)) {
                            ForEach(grouped[day] ?? []) { trip in
                                TripRow(trip: trip)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTrip = trip }
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
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Logged",
                        systemImage: "car",
                        description: Text("Tap + to log your first business trip.")
                    )
                }
            }
            .navigationTitle("Mileage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("History") { showHistory = true }
                        .disabled(trips.isEmpty)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showLogTrip = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.blue, in: Circle())
                        .shadow(color: .blue.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showLogTrip) {
                LogTripView()
            }
            .sheet(isPresented: $showHistory) {
                MileageHistoryView()
            }
            .sheet(item: $editingTrip) { trip in
                MileageTripEditView(trip: trip)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .confirmationDialog("Delete Trip?", isPresented: Binding(
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

    private func deleteTrips(from trips: [MileageTrip], at offsets: IndexSet) {
        for index in offsets { trips[index].deletedDate = .now }
    }
}

// MARK: - Shared summary card (used by MileageView + MileageHistoryView)

struct MileageSummaryCard: View {
    let miles: Double
    let reimbursement: Double
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(value: String(format: "%.1f", miles), unit: "mi", label: label)
            Divider().frame(height: 40)
            summaryItem(value: reimbursement.asCurrency, unit: nil, label: "Reimbursement")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func summaryItem(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.bold())
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared trip row (used by MileageView + MileageMonthDetailView)

struct TripRow: View {
    let trip: MileageTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Purpose + miles badge
            HStack(alignment: .center) {
                Text(trip.purpose)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f mi", trip.miles))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.12), in: Capsule())
            }

            // Route visualization
            HStack(spacing: 10) {
                // Icon column
                VStack(spacing: 0) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 1.5, height: 14)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                // Labels column
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.startLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !trip.waypoints.isEmpty {
                        Text("via \(trip.waypoints.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(trip.endLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(trip.reimbursementAmount.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    MileageView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
