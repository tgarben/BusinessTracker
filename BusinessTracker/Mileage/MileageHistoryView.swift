import SwiftUI
import SwiftData

struct MileageHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MileageTrip.date, order: .reverse) private var allTrips: [MileageTrip]

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
                    let miles = monthTrips.reduce(0.0) { $0 + $1.miles }
                    let reimbursement = monthTrips.reduce(0.0) { $0 + $1.reimbursementAmount }
                    let count = monthTrips.count

                    NavigationLink {
                        MileageMonthDetailView(monthStart: monthStart)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center) {
                                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f mi", miles))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.blue.opacity(0.12), in: Capsule())
                            }
                            HStack(spacing: 4) {
                                Text("\(count) \(count == 1 ? "trip" : "trips")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(reimbursement, format: .currency(code: "USD"))
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
