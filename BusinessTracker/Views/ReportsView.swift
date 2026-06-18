import SwiftUI
import SwiftData

// MARK: - Report range

enum ReportRange: String, CaseIterable {
    case week    = "Week"
    case month   = "Month"
    case quarter = "Quarter"
    case year    = "Year"

    func start(using cal: Calendar = .current) -> Date {
        let now = Date.now
        switch self {
        case .week:    return cal.startOfWeek(for: now)
        case .month:   return cal.startOfMonth(for: now)
        case .quarter: return cal.startOfQuarter(for: now)
        case .year:    return cal.startOfYear(for: now)
        }
    }

    func label(using cal: Calendar = .current) -> String {
        let now = Date.now
        switch self {
        case .week:
            let start = cal.startOfWeek(for: now)
            let end   = cal.date(byAdding: .day, value: 6, to: start) ?? start
            let fmt   = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: start))–\(fmt.string(from: end))"
        case .month:
            return now.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let month  = cal.component(.month, from: now)
            let year   = cal.component(.year, from: now)
            let q      = (month - 1) / 3 + 1
            return "Q\(q) \(year)"
        case .year:
            return now.formatted(.dateTime.year())
        }
    }
}


extension Calendar {
    func startOfQuarter(for date: Date) -> Date {
        let month = component(.month, from: date)
        let qMonth = ((month - 1) / 3) * 3 + 1
        var comps = DateComponents()
        comps.year  = component(.year, from: date)
        comps.month = qMonth
        comps.day   = 1
        return self.date(from: comps) ?? date
    }
    func startOfYear(for date: Date) -> Date {
        var comps = DateComponents()
        comps.year  = component(.year, from: date)
        comps.month = 1
        comps.day   = 1
        return self.date(from: comps) ?? date
    }
}

struct ReportsView: View {
    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }) private var expenses: [Expense]
    @Query(filter: #Predicate<IncomeEntry> { $0.deletedDate == nil }) private var incomeEntries: [IncomeEntry]

    @AppStorage("report_mpg") private var mpg: Double = 30.0
    @AppStorage("report_gasPrice") private var gasPrice: Double = 3.80
    @AppStorage("tax_selfEmploymentRate") private var seRate: Double = 15.3
    @AppStorage("tax_incomeBracketRate") private var bracketRate: Double = 22.0
    @AppStorage("user_name") private var userName: String = ""

    @State private var showFuelSettings = false
    @State private var selectedRange: ReportRange = .month
    @State private var reportPDFURL: URL? = nil

    // MARK: - Range window

    private var rangeStart: Date { selectedRange.start() }
    private var rangeLabel: String { selectedRange.label() }

    // MARK: - Range aggregates

    private var monthEntries: [TimeEntry]     { timeEntries.filter { $0.date >= rangeStart } }
    private var monthTrips: [MileageTrip]     { trips.filter { $0.date >= rangeStart } }
    private var monthExpenses: [Expense]      { expenses.filter { $0.date >= rangeStart } }
    private var monthIncome: [IncomeEntry]    { incomeEntries.filter { $0.date >= rangeStart } }

    private var totalHours: Double            { monthEntries.reduce(0) { $0 + $1.hours } }
    private var totalEarnings: Double         { monthEntries.reduce(0) { $0 + $1.earnings } }
    private var totalMiles: Double            { monthTrips.reduce(0) { $0 + $1.miles } }
    private var totalReimbursement: Double    { monthTrips.reduce(0) { $0 + $1.reimbursementAmount } }
    private var totalExpenses: Double         { monthExpenses.reduce(0) { $0 + $1.amount } }
    private var totalIncome: Double           { monthIncome.reduce(0) { $0 + $1.amount } }

    private var estimatedGallons: Double      { mpg > 0 ? totalMiles / mpg : 0 }
    private var estimatedFuelCost: Double     { estimatedGallons * gasPrice }
    private var netMileage: Double            { totalReimbursement - estimatedFuelCost }

    // MARK: - Tax estimates

    private var grossIncome: Double          { totalEarnings + totalIncome }
    private var mileageDeduction: Double     { totalMiles * MileageTrip.ratePerMile }
    private var taxableIncome: Double        { max(0, grossIncome - mileageDeduction - totalExpenses) }
    private var seAmount: Double             { taxableIncome * (seRate / 100) }
    private var incomeTaxAmount: Double      { taxableIncome * (bracketRate / 100) }
    private var totalSetAside: Double        { seAmount + incomeTaxAmount }

    // MARK: - Top clients (by hours)

    private var topClients: [(name: String, hours: Double, earnings: Double)] {
        var map: [String: (hours: Double, earnings: Double)] = [:]
        for entry in monthEntries {
            let name = entry.client?.name ?? "Uncategorized"
            let current = map[name] ?? (0, 0)
            map[name] = (current.hours + entry.hours, current.earnings + entry.earnings)
        }
        return map
            .map { (name: $0.key, hours: $0.value.hours, earnings: $0.value.earnings) }
            .sorted { $0.hours > $1.hours }
    }

    // MARK: - Client P&L

    private var clientPL: [ClientPLData] {
        var map: [String: (time: Double, income: Double, exp: Double)] = [:]

        for entry in monthEntries {
            let name = entry.client?.name ?? "Uncategorized"
            var c = map[name] ?? (0, 0, 0)
            c.time += entry.earnings
            map[name] = c
        }
        for entry in monthIncome {
            let name = entry.client?.name ?? "Uncategorized"
            var c = map[name] ?? (0, 0, 0)
            c.income += entry.amount
            map[name] = c
        }
        for expense in monthExpenses {
            guard let client = expense.client else { continue }
            var c = map[client.name] ?? (0, 0, 0)
            c.exp += expense.amount
            map[client.name] = c
        }

        return map
            .map { ClientPLData(name: $0.key, timeEarnings: $0.value.time, incomeReceived: $0.value.income, expenses: $0.value.exp) }
            .sorted { $0.net > $1.net }
    }

    private var hasData: Bool {
        !monthEntries.isEmpty || !monthTrips.isEmpty || !monthExpenses.isEmpty || !monthIncome.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ReportRange.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                if hasData {
                    // MARK: Glance at a glance
                    Section(rangeLabel) {
                        glanceCard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    // MARK: Mileage IRS deduction
                    if totalMiles > 0 {
                        Section("Mileage IRS Deduction") {
                            mileageDeductionCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

                    // MARK: Mileage fuel analysis
                    if totalMiles > 0 {
                        Section {
                            fuelCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        } header: {
                            HStack {
                                Text("Mileage Fuel Analysis")
                                Spacer()
                                Button("Edit") { showFuelSettings = true }
                                    .font(.caption)
                            }
                        }
                    }

                    // MARK: Tax set-aside
                    if grossIncome > 0 {
                        Section("Tax Set-Aside Estimate") {
                            taxCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

                    // MARK: Top clients
                    if !topClients.isEmpty {
                        Section("Top Clients — \(rangeLabel)") {
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

                    // MARK: Client P&L
                    if !clientPL.isEmpty {
                        Section("Client P&L — \(rangeLabel)") {
                            ForEach(clientPL, id: \.name) { client in
                                ClientPLReportRow(data: client)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if !hasData {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "chart.bar",
                        description: Text("Log time, trips, expenses, or income to see your monthly report.")
                    )
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Group {
                        if let url = reportPDFURL {
                            ShareLink(item: url, subject: Text("Business Report — \(rangeLabel)")) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                reportPDFURL = makeReportPDF(data: buildReportPDFData())
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .disabled(!hasData)
                        }
                    }
                }
            }
            .onChange(of: selectedRange) { _, _ in reportPDFURL = nil }
            .sheet(isPresented: $showFuelSettings) {
                FuelSettingsSheet(mpg: $mpg, gasPrice: $gasPrice)
            }
        }
    }

    // MARK: - Glance card (3×2 grid)

    private var glanceCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                glanceItem(value: String(format: "%.1f", totalHours), unit: "hrs",
                           label: "Hours", color: .indigo)
                Divider().frame(height: 44)
                glanceItem(value: totalEarnings.asCurrency, unit: nil,
                           label: "Earned", color: .indigo)
            }
            Divider()
            HStack(spacing: 0) {
                glanceItem(value: String(format: "%.1f", totalMiles), unit: "mi",
                           label: "Miles", color: .blue)
                Divider().frame(height: 44)
                glanceItem(value: totalReimbursement.asCurrency, unit: nil,
                           label: "Reimbursement", color: .blue)
            }
            Divider()
            HStack(spacing: 0) {
                glanceItem(value: totalIncome.asCurrency, unit: nil,
                           label: "Income", color: .green)
                Divider().frame(height: 44)
                glanceItem(value: totalExpenses.asCurrency, unit: nil,
                           label: "Expenses", color: .red)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    // MARK: - Tax card

    private var taxCard: some View {
        VStack(spacing: 0) {
            // Gross income
            taxSectionHeader("Gross Income")
            if totalEarnings > 0 {
                taxRow(label: "Time Earnings", value: totalEarnings.asCurrency, color: .indigo)
            }
            if totalIncome > 0 {
                taxRow(label: "Income Received", value: totalIncome.asCurrency, color: .green)
            }

            // Deductions
            if mileageDeduction > 0 || totalExpenses > 0 {
                Divider().padding(.horizontal, 16)
                taxSectionHeader("Deductions")
                if mileageDeduction > 0 {
                    let milesLabel = String(format: "%.0f mi × $%.2f/mi", totalMiles, MileageTrip.ratePerMile)
                    taxRow(label: "Mileage (\(milesLabel))", value: "−\(mileageDeduction.asCurrency)", color: .green)
                }
                if totalExpenses > 0 {
                    taxRow(label: "Business Expenses", value: "−\(totalExpenses.asCurrency)", color: .green)
                }
            }

            // Taxable income
            Divider().padding(.horizontal, 16)
            HStack {
                Text("Taxable Income")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(taxableIncome.asCurrency)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Tax estimates
            Divider().padding(.horizontal, 16)
            taxRow(
                label: "Tax Rate (\(seRate.formatted(.number.precision(.fractionLength(1))))%)",
                value: seAmount.asCurrency, color: .primary
            )
            taxRow(
                label: "Income Tax (\(bracketRate.formatted(.number.precision(.fractionLength(1))))%)",
                value: incomeTaxAmount.asCurrency, color: .primary
            )

            // Set-aside total
            Divider().padding(.horizontal, 16)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended Set-Aside")
                        .font(.subheadline.weight(.semibold))
                    Text("Rates editable in Settings")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(totalSetAside.asCurrency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func taxSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private func taxRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Mileage deduction card

    private var mileageDeductionCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: "%.1f mi × $%.3f/mi", totalMiles, MileageTrip.ratePerMile))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("IRS standard mileage rate")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(mileageDeduction.asCurrency)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Deductible business expense — Schedule C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Write-Off")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - PDF data builder

    private func buildReportPDFData() -> ReportPDFData {
        ReportPDFData(
            rangeLabel: rangeLabel,
            userName: userFullName(),
            totalHours: totalHours,
            totalEarnings: totalEarnings,
            totalMiles: totalMiles,
            totalReimbursement: totalReimbursement,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            ratePerMile: MileageTrip.ratePerMile,
            mpg: mpg,
            gasPrice: gasPrice,
            estimatedFuelCost: estimatedFuelCost,
            mileageDeduction: mileageDeduction,
            grossIncome: grossIncome,
            taxableIncome: taxableIncome,
            seRate: seRate,
            bracketRate: bracketRate,
            seAmount: seAmount,
            incomeTaxAmount: incomeTaxAmount,
            totalSetAside: totalSetAside,
            topClients: Array(topClients.prefix(5)),
            totalClientHours: totalHours
        )
    }

    // MARK: - Fuel card

    private var fuelCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                fuelInputChip(value: String(format: "%.0f", mpg), label: "MPG", icon: "fuelpump.fill")
                fuelDivider()
                fuelInputChip(value: gasPrice.asCurrency, label: "Per Gallon", icon: "dollarsign.circle.fill")
                fuelDivider()
                fuelInputChip(value: String(format: "%.1f gal", estimatedGallons), label: "Est. Used", icon: "drop.fill")
            }
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            VStack(spacing: 0) {
                fuelBreakdownRow(label: "IRS Reimbursement", value: totalReimbursement.asCurrency, color: .primary)
                fuelBreakdownRow(label: "Estimated Fuel Cost", value: "−\(estimatedFuelCost.asCurrency)", color: .red)
            }
            .padding(.vertical, 4)

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Net Profit")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(netMileage.asCurrency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(netMileage >= 0 ? .green : .red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((netMileage >= 0 ? Color.green : Color.red).opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func fuelInputChip(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func fuelDivider() -> some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    private func fuelBreakdownRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - Client report row

private struct ClientReportRow: View {
    let name: String
    let hours: Double
    let earnings: Double
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
                Text(earnings.asCurrency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client P&L data

private struct ClientPLData {
    let name: String
    let timeEarnings: Double
    let incomeReceived: Double
    let expenses: Double
    var net: Double { timeEarnings + incomeReceived - expenses }
}

// MARK: - Client P&L report row

private struct ClientPLReportRow: View {
    let data: ClientPLData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(data.name).font(.subheadline.weight(.semibold))
                Spacer()
                Text(data.net.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(data.net >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((data.net >= 0 ? Color.green : Color.red).opacity(0.1), in: Capsule())
            }

            HStack(spacing: 10) {
                if data.timeEarnings > 0 {
                    Label(data.timeEarnings.asCurrency, systemImage: "clock.fill")
                        .foregroundStyle(.indigo)
                }
                if data.incomeReceived > 0 {
                    Label(data.incomeReceived.asCurrency, systemImage: "dollarsign.circle.fill")
                        .foregroundStyle(.green)
                }
                if data.expenses > 0 {
                    Label(data.expenses.asCurrency, systemImage: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption2)
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
        .modelContainer(for: [
            TimeEntry.self, MileageTrip.self, Client.self, Project.self,
            Expense.self, IncomeEntry.self
        ], inMemory: true)
}

// MARK: - Report PDF data

struct ReportPDFData {
    let rangeLabel: String
    let userName: String
    let totalHours: Double
    let totalEarnings: Double
    let totalMiles: Double
    let totalReimbursement: Double
    let totalIncome: Double
    let totalExpenses: Double
    let ratePerMile: Double
    let mpg: Double
    let gasPrice: Double
    let estimatedFuelCost: Double
    let mileageDeduction: Double
    let grossIncome: Double
    let taxableIncome: Double
    let seRate: Double
    let bracketRate: Double
    let seAmount: Double
    let incomeTaxAmount: Double
    let totalSetAside: Double
    let topClients: [(name: String, hours: Double, earnings: Double)]
    let totalClientHours: Double
}

// MARK: - Report PDF layout (letter size, 612×792pt)

struct ReportPDFLayout: View {
    let data: ReportPDFData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.userName.isEmpty ? "Business Report" : data.userName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                    Text("BUSINESS REPORT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                        .tracking(1.5)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(data.rangeLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Generated \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 48)
            .padding(.bottom, 20)

            fullDivider

            // MARK: At a Glance
            pdfSectionLabel("AT A GLANCE")

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    glanceRow("Hours Worked", String(format: "%.1f hrs", data.totalHours), color: Color(red: 0.4, green: 0.3, blue: 0.9))
                    glanceRow("Time Earned", data.totalEarnings.asCurrency, color: Color(red: 0.4, green: 0.3, blue: 0.9))
                    glanceRow("Miles Driven", String(format: "%.1f mi", data.totalMiles), color: Color(red: 0.2, green: 0.5, blue: 0.9))
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color(white: 0.88)).frame(width: 1, height: 72)

                VStack(alignment: .leading, spacing: 0) {
                    glanceRow("IRS Reimbursement", data.totalReimbursement.asCurrency, color: Color(red: 0.2, green: 0.5, blue: 0.9))
                    glanceRow("Income Received", data.totalIncome.asCurrency, color: Color(red: 0.2, green: 0.65, blue: 0.3))
                    glanceRow("Business Expenses", data.totalExpenses.asCurrency, color: Color(red: 0.85, green: 0.25, blue: 0.25))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 4)

            // MARK: Mileage
            if data.totalMiles > 0 {
                fullDivider
                pdfSectionLabel("MILEAGE")

                pdfRow(
                    label: String(format: "IRS Deduction  (%.1f mi × $%.3f/mi)", data.totalMiles, data.ratePerMile),
                    value: data.mileageDeduction.asCurrency,
                    valueColor: Color(red: 0.2, green: 0.5, blue: 0.9)
                )
                if data.mpg > 0 {
                    let gallons = data.totalMiles / data.mpg
                    pdfRow(
                        label: String(format: "Est. Fuel Cost  (%.1f gal × $%.2f/gal)", gallons, data.gasPrice),
                        value: "−\(data.estimatedFuelCost.asCurrency)",
                        valueColor: Color(red: 0.7, green: 0.2, blue: 0.2)
                    )
                    pdfRow(
                        label: "Net Mileage Profit",
                        value: (data.totalReimbursement - data.estimatedFuelCost).asCurrency,
                        valueColor: .black
                    )
                }
            }

            // MARK: Tax estimate
            if data.grossIncome > 0 {
                fullDivider
                pdfSectionLabel("TAX ESTIMATE")

                pdfRow(label: "Gross Income (time + income)", value: data.grossIncome.asCurrency)
                if data.mileageDeduction > 0 {
                    pdfRow(label: "Mileage Deduction", value: "−\(data.mileageDeduction.asCurrency)", valueColor: Color(red: 0.2, green: 0.55, blue: 0.3))
                }
                if data.totalExpenses > 0 {
                    pdfRow(label: "Business Expenses", value: "−\(data.totalExpenses.asCurrency)", valueColor: Color(red: 0.2, green: 0.55, blue: 0.3))
                }

                // Taxable income divider row
                HStack {
                    Text("Taxable Income")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(data.taxableIncome.asCurrency)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 48)
                .frame(height: 28)
                .background(Color(white: 0.96))

                pdfRow(
                    label: String(format: "Tax Rate (%.1f%%)", data.seRate),
                    value: data.seAmount.asCurrency
                )
                pdfRow(
                    label: String(format: "Income Tax (%.1f%%)", data.bracketRate),
                    value: data.incomeTaxAmount.asCurrency
                )

                HStack {
                    Text("Recommended Set-Aside")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(data.totalSetAside.asCurrency)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.5, blue: 0.1))
                }
                .padding(.horizontal, 48)
                .frame(height: 28)
            }

            // MARK: Top clients
            if !data.topClients.isEmpty {
                fullDivider
                pdfSectionLabel("TOP CLIENTS")

                ForEach(Array(data.topClients.enumerated()), id: \.offset) { _, client in
                    HStack(spacing: 12) {
                        Text(client.name)
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                            .frame(width: 140, alignment: .leading)
                            .lineLimit(1)

                        let fraction = data.totalClientHours > 0 ? client.hours / data.totalClientHours : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.9)).frame(width: 130, height: 5)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.4, green: 0.3, blue: 0.9, opacity: 0.6))
                                .frame(width: max(4, 130 * fraction), height: 5)
                        }

                        Spacer()
                        Text(String(format: "%.1f hrs", client.hours))
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.5))
                            .frame(width: 56, alignment: .trailing)
                        Text(client.earnings.asCurrency)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.horizontal, 48)
                    .frame(height: 26)
                }
            }

            Spacer(minLength: 0)

            // MARK: Footer
            fullDivider
            HStack {
                Text("Generated by Freelanced")
                    .font(.system(size: 8))
                    .foregroundColor(Color(white: 0.65))
                Spacer()
                Text(Date.now.formatted(date: .long, time: .omitted))
                    .font(.system(size: 8))
                    .foregroundColor(Color(white: 0.65))
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }

    private var fullDivider: some View {
        Rectangle().fill(Color(white: 0.88)).frame(height: 1).padding(.horizontal, 48)
    }

    private func pdfSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(Color(white: 0.6))
            .tracking(1.5)
            .padding(.horizontal, 48)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func glanceRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Color(white: 0.5))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 48)
        .frame(height: 24)
    }

    private func pdfRow(label: String, value: String, valueColor: Color = Color(white: 0.3)) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 48)
        .frame(height: 24)
    }
}

// MARK: - Report PDF generation

@MainActor
func makeReportPDF(data: ReportPDFData) -> URL? {
    let layout = ReportPDFLayout(data: data)
    let renderer = ImageRenderer(content: layout)
    renderer.proposedSize = ProposedViewSize(width: 612, height: 792)

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BusinessReport-\(data.rangeLabel.replacingOccurrences(of: " ", with: "-")).pdf")

    renderer.render { _, draw in
        var box = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return }
        ctx.beginPDFPage(nil)
        draw(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        try? pdfData.write(to: url)
    }

    return url
}
