import SwiftUI
import SwiftData

struct MileageMonthDetailView: View {
    let monthStart: Date
    @Environment(\.modelContext) private var modelContext

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }) private var trips: [MileageTrip]

    init(monthStart: Date) {
        self.monthStart = monthStart
        let end = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _trips = Query(
            filter: #Predicate<MileageTrip> { trip in
                trip.date >= monthStart && trip.date < end && trip.deletedDate == nil
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

    @State private var editingTrip: MileageTrip?
    @State private var pendingDelete: ([MileageTrip], IndexSet)?

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
                            .contentShape(Rectangle())
                            .onTapGesture { editingTrip = trip }
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
        .sheet(item: $editingTrip) { trip in
            MileageTripEditView(trip: trip)
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

    private func deleteTrips(from trips: [MileageTrip], at offsets: IndexSet) {
        for index in offsets { trips[index].deletedDate = .now }
    }
}
