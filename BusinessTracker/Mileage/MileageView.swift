import SwiftUI
import SwiftData

struct MileageView: View {
    @Query(sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Environment(\.modelContext) private var modelContext

    @State private var showLogTrip = false

    // Month summary
    private var monthTrips: [MileageTrip] {
        let start = Calendar.current.startOfMonth(for: .now)
        return trips.filter { $0.date >= start }
    }

    private var monthMiles: Double { monthTrips.reduce(0) { $0 + $1.miles } }
    private var monthReimbursement: Double { monthTrips.reduce(0) { $0 + $1.reimbursementAmount } }

    var body: some View {
        NavigationStack {
            List {
                // Month summary card
                Section {
                    MonthSummaryCard(miles: monthMiles, reimbursement: monthReimbursement)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Trips grouped by date
                if trips.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Trips Logged",
                            systemImage: "car",
                            description: Text("Tap + to log your first business trip.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    let grouped = Dictionary(grouping: trips) {
                        Calendar.current.startOfDay(for: $0.date)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)

                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(day, style: .date)) {
                            ForEach(grouped[day] ?? []) { trip in
                                TripRow(trip: trip)
                            }
                            .onDelete { offsets in
                                deleteTrips(from: grouped[day] ?? [], at: offsets)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Mileage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showLogTrip = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showLogTrip) {
                LogTripView()
            }
        }
    }

    private func deleteTrips(from trips: [MileageTrip], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(trips[index]) }
    }
}

// MARK: - Month Summary Card

private struct MonthSummaryCard: View {
    let miles: Double
    let reimbursement: Double

    private var monthName: String {
        Date.now.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: String(format: "%.1f", miles),
                unit: "mi",
                label: "\(monthName) Miles"
            )
            Divider().frame(height: 40)
            summaryItem(
                value: reimbursement.formatted(.currency(code: "USD")),
                unit: nil,
                label: "Reimbursement"
            )
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
                if let unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trip Row

private struct TripRow: View {
    let trip: MileageTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.purpose)
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "%.1f mi", trip.miles))
                    .font(.subheadline.bold())
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(trip.startLocation, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.green, .secondary)
                    Label(trip.endLocation, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .secondary)
                }
                Spacer()
                Text(trip.reimbursementAmount.formatted(.currency(code: "USD")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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
