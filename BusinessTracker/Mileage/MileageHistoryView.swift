import SwiftUI
import SwiftData

struct MileageHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MileageTrip.date, order: .reverse) private var allTrips: [MileageTrip]

    /// All unique month start dates that have at least one trip, most recent first
    private var months: [Date] {
        let cal = Calendar.current
        let starts = Set(allTrips.map { cal.startOfMonth(for: $0.date) })
        return starts.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(months, id: \.self) { monthStart in
                    let monthTrips = trips(for: monthStart)
                    let miles = monthTrips.reduce(0) { $0 + $1.miles }
                    let reimbursement = monthTrips.reduce(0) { $0 + $1.reimbursementAmount }

                    NavigationLink {
                        MileageMonthDetailView(monthStart: monthStart)
                    } label: {
                        VStack(spacing: 0) {
                            MileageSummaryCard(
                                miles: miles,
                                reimbursement: reimbursement,
                                label: monthStart.formatted(.dateTime.month(.wide).year())
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mileage History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if allTrips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "car",
                        description: Text("Logged trips will appear here grouped by month.")
                    )
                }
            }
        }
    }

    private func trips(for monthStart: Date) -> [MileageTrip] {
        let cal = Calendar.current
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return allTrips.filter { $0.date >= monthStart && $0.date < monthEnd }
    }
}

#Preview {
    MileageHistoryView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
