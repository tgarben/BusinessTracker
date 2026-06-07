import SwiftUI
import SwiftData

struct MileageMonthDetailView: View {
    let monthStart: Date
    @Environment(\.modelContext) private var modelContext

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    @Query private var trips: [MileageTrip]

    init(monthStart: Date) {
        self.monthStart = monthStart
        let end = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _trips = Query(
            filter: #Predicate<MileageTrip> { trip in
                trip.date >= monthStart && trip.date < end
            },
            sort: \MileageTrip.date,
            order: .reverse
        )
    }

    private var totalMiles: Double        { trips.reduce(0) { $0 + $1.miles } }
    private var totalReimbursement: Double { trips.reduce(0) { $0 + $1.reimbursementAmount } }

    private var title: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        List {
            // Month summary at top
            Section {
                MileageSummaryCard(
                    miles: totalMiles,
                    reimbursement: totalReimbursement,
                    label: "\(title) Miles"
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Trips grouped by day
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
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteTrips(from trips: [MileageTrip], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(trips[index]) }
    }
}
