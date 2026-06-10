import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("mileage_ratePerMile") private var mileageRate: Double = MileageTrip.defaultRatePerMile
    @AppStorage("default_hourlyRate") private var defaultHourlyRate: Double = 0
    @AppStorage("report_mpg") private var mpg: Double = 30.0
    @AppStorage("report_gasPrice") private var gasPrice: Double = 3.80
    @AppStorage("tax_selfEmploymentRate") private var selfEmploymentRate: Double = 15.3
    @AppStorage("tax_incomeBracketRate") private var incomeBracketRate: Double = 22.0
    @AppStorage("tax_businessStructure") private var businessStructure: String = "Sole Proprietor"

    @Query(sort: \TimeEntry.date, order: .reverse) private var timeEntries: [TimeEntry]
    @Query(sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var showClients = false
    @State private var exportItem: ExportItem?

    private let businessStructures = [
        "Sole Proprietor", "Single-Member LLC", "Multi-Member LLC",
        "S-Corp", "C-Corp", "Partnership"
    ]

    var body: some View {
        NavigationStack {
            List {

                // MARK: Business
                Section("Business") {
                    Button {
                        showClients = true
                    } label: {
                        HStack {
                            SettingsIcon(symbol: "person.2.fill", color: .indigo)
                            Text("Clients & Projects")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // MARK: Rates & Defaults
                Section {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "car.fill", color: .blue)
                        Text("IRS Mileage Rate")
                        Spacer()
                        TextField("0.000", value: $mileageRate, format: .number.precision(.fractionLength(3)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "clock.fill", color: .indigo)
                        Text("Default Hourly Rate")
                        Spacer()
                        TextField("0.00", value: $defaultHourlyRate, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                    }
                } header: {
                    Text("Rates & Defaults")
                } footer: {
                    Text("Mileage rate defaults to the current IRS standard ($\(String(format: "%.2f", MileageTrip.defaultRatePerMile))/mi). Update each January.")
                }

                // MARK: Fuel
                Section {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "fuelpump.fill", color: .orange)
                        Text("Vehicle MPG")
                        Spacer()
                        TextField("30", value: $mpg, format: .number.precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "dollarsign.circle.fill", color: .orange)
                        Text("Gas Price / Gallon")
                        Spacer()
                        TextField("3.80", value: $gasPrice, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                    }
                } header: {
                    Text("Fuel")
                } footer: {
                    Text("Used in Reports to estimate fuel cost vs. mileage reimbursement.")
                }

                // MARK: Tax Information
                Section {
                    LabeledContent {
                        Picker("", selection: $businessStructure) {
                            ForEach(businessStructures, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "building.columns.fill", color: .green)
                            Text("Structure")
                        }
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "percent", color: .green)
                        Text("SE Tax Rate")
                        Spacer()
                        TextField("15.3", value: $selfEmploymentRate, format: .number.precision(.fractionLength(1)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 52)
                        Text("%").foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "chart.line.uptrend.xyaxis", color: .green)
                        Text("Income Bracket")
                        Spacer()
                        TextField("22", value: $incomeBracketRate, format: .number.precision(.fractionLength(1)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 52)
                        Text("%").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Tax Information")
                } footer: {
                    Text("Used in Reports to estimate your quarterly tax liability. These are estimates — consult a tax professional for advice.")
                }

                // MARK: Quarterly Tax Dates
                Section {
                    ForEach(quarterlyDueDates, id: \.date) { payment in
                        HStack(spacing: 10) {
                            SettingsIcon(
                                symbol: payment.isNext ? "calendar.badge.exclamationmark" : "calendar",
                                color: payment.isNext ? .orange : .gray
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.label)
                                    .font(.subheadline)
                                Text(payment.period)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(payment.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.subheadline.weight(.medium))
                                if payment.isNext {
                                    Text(daysUntil(payment.date))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Quarterly Tax Due Dates")
                } footer: {
                    Text("IRS estimated tax payment deadlines. If a date falls on a weekend or holiday the IRS typically extends to the next business day.")
                }

                // MARK: Data Export
                Section {
                    Button {
                        exportItem = ExportItem(csv: buildCSV())
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "square.and.arrow.up", color: .blue)
                            Text("Export All Data (CSV)")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Data Export")
                } footer: {
                    Text("Exports time entries, mileage trips, and expenses as a single CSV file.")
                }

                // MARK: App
                Section("App") {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "dollarsign", color: .gray)
                        Text("Currency")
                        Spacer()
                        Text("USD").foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "info.circle.fill", color: .gray)
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
            .sheet(isPresented: $showClients) {
                ClientListView()
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Quarterly due dates

    private struct TaxPayment {
        let label: String
        let period: String
        let date: Date
        let isNext: Bool
    }

    private var quarterlyDueDates: [TaxPayment] {
        let year = Calendar.current.component(.year, from: .now)
        let payments: [(label: String, period: String, month: Int, day: Int)] = [
            ("Q1 Payment", "Jan 1 – Mar 31", 4, 15),
            ("Q2 Payment", "Apr 1 – May 31", 6, 15),
            ("Q3 Payment", "Jun 1 – Aug 31", 9, 15),
            ("Q4 Payment", "Sep 1 – Dec 31", 1, 15),
        ]
        var dates: [Date] = []
        for (i, p) in payments.enumerated() {
            let y = i == 3 ? year + 1 : year
            var comps = DateComponents()
            comps.year = y; comps.month = p.month; comps.day = p.day
            dates.append(Calendar.current.date(from: comps) ?? .now)
        }
        let nextIndex = dates.firstIndex(where: { $0 >= Calendar.current.startOfDay(for: .now) }) ?? 0
        return payments.enumerated().map { i, p in
            TaxPayment(label: p.label, period: p.period, date: dates[i], isNext: i == nextIndex)
        }
    }

    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "In \(days) days"
    }

    // MARK: - CSV export

    private func buildCSV() -> URL {
        var rows: [String] = []

        // Time entries
        rows.append("=== TIME ENTRIES ===")
        rows.append("Date,Client,Project,Hours,Rate,Earnings,Notes")
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        for e in timeEntries {
            let cols = [
                dateFmt.string(from: e.date),
                e.client?.name ?? "",
                e.project?.name ?? "",
                String(format: "%.2f", e.hours),
                "\(e.hourlyRate)",
                "\(e.earnings)",
                e.notes.replacingOccurrences(of: ",", with: ";")
            ]
            rows.append(cols.joined(separator: ","))
        }

        // Mileage trips
        rows.append("")
        rows.append("=== MILEAGE TRIPS ===")
        rows.append("Date,From,To,Miles,Rate,Reimbursement,Purpose,Notes")
        for t in trips {
            let cols = [
                dateFmt.string(from: t.date),
                t.startLocation.replacingOccurrences(of: ",", with: ";"),
                t.endLocation.replacingOccurrences(of: ",", with: ";"),
                String(format: "%.2f", t.miles),
                String(format: "%.3f", MileageTrip.ratePerMile),
                String(format: "%.2f", t.reimbursementAmount),
                t.purpose.replacingOccurrences(of: ",", with: ";"),
                t.notes.replacingOccurrences(of: ",", with: ";")
            ]
            rows.append(cols.joined(separator: ","))
        }

        // Expenses
        rows.append("")
        rows.append("=== EXPENSES ===")
        rows.append("Date,Category,Amount,Client,Notes")
        for ex in expenses {
            let cols = [
                dateFmt.string(from: ex.date),
                ex.category,
                "\(ex.amount)",
                ex.client?.name ?? "",
                ex.notes.replacingOccurrences(of: ",", with: ";")
            ]
            rows.append(cols.joined(separator: ","))
        }

        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BusinessTracker_Export_\(dateFmt.string(from: .now)).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Export helpers

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
    init(csv url: URL) { self.url = url }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Settings icon helper

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Client.self, Project.self], inMemory: true)
}
