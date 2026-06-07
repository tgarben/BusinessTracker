import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query private var timeEntries: [TimeEntry]
    @Query private var trips: [MileageTrip]

    // Fuel settings — persisted in UserDefaults
    @AppStorage("report_mpg") private var mpg: Double = 30.0
    @AppStorage("report_gasPrice") private var gasPrice: Double = 3.80

    @State private var showFuelSettings = false

    // MARK: - Current month window

    private var monthStart: Date {
        Calendar.current.startOfMonth(for: .now)
    }

    private var monthLabel: String {
        Date.now.formatted(.dateTime.month(.wide).year())
    }

    // MARK: - Month aggregates

    private var monthEntries: [TimeEntry] {
        timeEntries.filter { $0.date >= monthStart }
    }

    private var monthTrips: [MileageTrip] {
        trips.filter { $0.date >= monthStart }
    }

    private var totalHours: Double        { monthEntries.reduce(0) { $0 + $1.hours } }
    private var totalEarnings: Decimal    { monthEntries.reduce(0) { $0 + $1.earnings } }
    private var totalMiles: Double        { monthTrips.reduce(0) { $0 + $1.miles } }
    private var totalReimbursement: Double { monthTrips.reduce(0) { $0 + $1.reimbursementAmount } }

    // Fuel math
    private var estimatedGallons: Double  { mpg > 0 ? totalMiles / mpg : 0 }
    private var estimatedFuelCost: Double { estimatedGallons * gasPrice }
    private var netMileage: Double        { totalReimbursement - estimatedFuelCost }

    // Top clients by hours
    private var topClients: [(name: String, hours: Double, earnings: Decimal)] {
        var map: [String: (hours: Double, earnings: Decimal)] = [:]
        for entry in monthEntries {
            let name = entry.client?.name ?? "Uncategorized"
            let current = map[name] ?? (0, 0)
            map[name] = (current.hours + entry.hours, current.earnings + entry.earnings)
        }
        return map
            .map { (name: $0.key, hours: $0.value.hours, earnings: $0.value.earnings) }
            .sorted { $0.hours > $1.hours }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Month at a glance
                Section {
                    glanceCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // MARK: Mileage fuel analysis
                if totalMiles > 0 {
                    Section {
                        fuelCard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } header: {
                        HStack {
                            Text("Mileage Analysis")
                            Spacer()
                            Button("Edit") { showFuelSettings = true }
                                .font(.caption)
                        }
                    }
                }

                // MARK: Top clients
                if !topClients.isEmpty {
                    Section("Top Clients — \(monthLabel)") {
                        ForEach(topClients, id: \.name) { client in
                            ClientReportRow(
                                name: client.name,
                                hours: client.hours,
                                earnings: client.earnings,
                                totalHours: totalHours
                            )
                        }
                    }
                }

                // Empty state
                if monthEntries.isEmpty && monthTrips.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Data Yet",
                            systemImage: "chart.bar",
                            description: Text("Log time or trips to see your monthly report.")
                        )
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reports")
            .sheet(isPresented: $showFuelSettings) {
                FuelSettingsSheet(mpg: $mpg, gasPrice: $gasPrice)
            }
        }
    }

    // MARK: - Glance card

    private var glanceCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                glanceItem(
                    value: String(format: "%.1f", totalHours),
                    unit: "hrs",
                    label: "Hours",
                    color: .indigo
                )
                Divider().frame(height: 44)
                glanceItem(
                    value: totalEarnings.formatted(.currency(code: "USD")),
                    unit: nil,
                    label: "Earned",
                    color: .indigo
                )
            }
            Divider()
            HStack(spacing: 0) {
                glanceItem(
                    value: String(format: "%.1f", totalMiles),
                    unit: "mi",
                    label: "Miles",
                    color: .blue
                )
                Divider().frame(height: 44)
                glanceItem(
                    value: totalReimbursement.formatted(.currency(code: "USD")),
                    unit: nil,
                    label: "Reimbursement",
                    color: .blue
                )
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .topLeading) {
            Text(monthLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
    }

    private func glanceItem(value: String, unit: String?, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title3.bold()).foregroundStyle(color)
                if let unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Fuel card

    private var fuelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Inputs summary
            HStack(spacing: 16) {
                fuelStat(label: "MPG", value: String(format: "%.0f", mpg), icon: "fuelpump.fill", color: .orange)
                fuelStat(label: "Per Gallon", value: gasPrice.formatted(.currency(code: "USD")), icon: "dollarsign.circle.fill", color: .orange)
                fuelStat(label: "Gallons Used", value: String(format: "%.1f", estimatedGallons), icon: "drop.fill", color: .orange)
            }

            Divider()

            // Net breakdown
            HStack(spacing: 0) {
                netItem(label: "Reimbursement", value: totalReimbursement.formatted(.currency(code: "USD")), color: .green)
                Text("−")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                netItem(label: "Fuel Cost", value: estimatedFuelCost.formatted(.currency(code: "USD")), color: .red)
                Text("=")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                netItem(
                    label: "Net",
                    value: netMileage.formatted(.currency(code: "USD")),
                    color: netMileage >= 0 ? .green : .red
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func fuelStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func netItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Client report row

private struct ClientReportRow: View {
    let name: String
    let hours: Double
    let earnings: Decimal
    let totalHours: Double

    private var fraction: Double {
        totalHours > 0 ? hours / totalHours : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f hrs", hours))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.indigo.opacity(0.12), in: Capsule())
            }
            HStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.15))
                            .frame(height: 5)
                        Capsule().fill(.indigo.opacity(0.7))
                            .frame(width: geo.size.width * fraction, height: 5)
                    }
                }
                .frame(height: 5)
                Spacer(minLength: 12)
                Text(earnings.formatted(.currency(code: "USD")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fuel settings sheet

private struct FuelSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mpg: Double
    @Binding var gasPrice: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Vehicle") {
                    LabeledContent("Average MPG") {
                        TextField("30", value: $mpg, format: .number.precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Fuel Price") {
                    LabeledContent("Price per Gallon") {
                        TextField("3.80", value: $gasPrice, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                Section {
                    Text("Used to estimate fuel cost vs. IRS reimbursement. These settings are saved and used across all reports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fuel Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [TimeEntry.self, MileageTrip.self, Client.self, Project.self], inMemory: true)
}
