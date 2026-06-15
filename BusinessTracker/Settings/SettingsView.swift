import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_primaryUse") private var primaryUse: String = "Mixed"
    @AppStorage("home_sectionOrder") private var sectionOrder: String = HomeSection.defaultOrderString

    @AppStorage("mileage_ratePerMile") private var mileageRate: Double = MileageTrip.defaultRatePerMile
    @AppStorage("default_hourlyRate") private var defaultHourlyRate: Double = 0
    @AppStorage("report_mpg") private var mpg: Double = 30.0
    @AppStorage("report_gasPrice") private var gasPrice: Double = 3.80
    @AppStorage("tax_selfEmploymentRate") private var selfEmploymentRate: Double = 15.3
    @AppStorage("tax_incomeBracketRate") private var incomeBracketRate: Double = 22.0
    @AppStorage("tax_businessStructure") private var businessStructure: String = "Sole Proprietor"
    @AppStorage("tax_remindersEnabled") private var taxRemindersEnabled: Bool = false

    // Business information (used on invoices)
    @AppStorage("business_name") private var businessName: String = ""
    @AppStorage("business_address") private var businessAddress: String = ""
    @AppStorage("business_phone") private var businessPhone: String = ""
    @AppStorage("business_email") private var businessEmail: String = ""
    @AppStorage("business_website") private var businessWebsite: String = ""
    @AppStorage("business_taxID") private var businessTaxID: String = ""
    @AppStorage("business_defaultTaxRate") private var defaultTaxRate: Double = 0
    @AppStorage("business_defaultPaymentTerms") private var defaultPaymentTerms: String = "Due Upon Receipt"
    @AppStorage("business_acceptedPayments") private var acceptedPayments: String = ""
    @AppStorage("business_paymentInstructions") private var paymentInstructions: String = ""

    private let paymentTermsOptions = ["Due Upon Receipt", "Net 15", "Net 30", "Net 45", "Net 60"]

    private let primaryUseOptions = ["Mixed", "Time & Billing", "Mileage", "Expenses"]

    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }, sort: \TimeEntry.date, order: .reverse) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }, sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }, sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var exportItem: ExportItem?
    @FocusState private var focusedField: Bool

    private let businessStructures = [
        "Sole Proprietor", "Single-Member LLC", "Multi-Member LLC",
        "S-Corp", "C-Corp", "Partnership"
    ]

    @ViewBuilder
    private func businessField(_ label: String, text: Binding<String>, icon: String, color: Color,
                               keyboard: UIKeyboardType = .default, axis: Axis = .horizontal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SettingsIcon(symbol: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                TextField(label, text: text, axis: axis)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .sentences)
                    .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
            }
        }
    }

    private var profileInitials: String {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: Profile header
                Section {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.indigo.gradient)
                                .frame(width: 76, height: 76)
                            Text(profileInitials)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(spacing: 2) {
                            Text(userName.trimmingCharacters(in: .whitespaces).isEmpty ? "Add your name" : userName)
                                .font(.title3.bold())
                                .foregroundStyle(userName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                            Text("\(primaryUse) · Freelanced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // MARK: Personalization
                Section {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "person.fill", color: .indigo)
                        Text("Your Name")
                        Spacer()
                        TextField("First name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .frame(width: 120)
                    }

                    LabeledContent {
                        Picker("", selection: $primaryUse) {
                            ForEach(primaryUseOptions, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .onChange(of: primaryUse) { _, newValue in
                            sectionOrder = HomeSection.orderString(forUse: newValue)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "square.grid.2x2.fill", color: .purple)
                            Text("Primary Use")
                        }
                    }
                } header: {
                    Text("Personalization")
                } footer: {
                    Text("Your name appears in the Home screen greeting. Changing your primary use resets the Home screen section order.")
                }

                // MARK: Business Information
                Section {
                    businessField("Business Name", text: $businessName, icon: "building.2.fill", color: .indigo)
                    businessField("Address", text: $businessAddress, icon: "mappin.and.ellipse", color: .indigo, axis: .vertical)
                    businessField("Phone", text: $businessPhone, icon: "phone.fill", color: .indigo, keyboard: .phonePad)
                    businessField("Email", text: $businessEmail, icon: "envelope.fill", color: .indigo, keyboard: .emailAddress)
                    businessField("Website", text: $businessWebsite, icon: "globe", color: .indigo, keyboard: .URL)
                    businessField("Tax ID / EIN", text: $businessTaxID, icon: "number", color: .indigo)
                } header: {
                    Text("Business Information")
                } footer: {
                    Text("Appears as the \"from\" details on invoices you generate.")
                }

                // MARK: Invoicing Defaults
                Section {
                    LabeledContent {
                        Picker("", selection: $defaultPaymentTerms) {
                            ForEach(paymentTermsOptions, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "calendar.badge.clock", color: .purple)
                            Text("Payment Terms")
                        }
                    }
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "percent", color: .purple)
                        Text("Default Sales Tax")
                        Spacer()
                        TextField("0.0", value: $defaultTaxRate, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 56)
                        Text("%").foregroundStyle(.secondary)
                    }
                    businessField("Accepted Payments", text: $acceptedPayments, icon: "creditcard.fill", color: .purple, axis: .vertical)
                    businessField("Payment Instructions", text: $paymentInstructions, icon: "text.bubble.fill", color: .purple, axis: .vertical)
                } header: {
                    Text("Invoicing Defaults")
                } footer: {
                    Text("Pre-filled into each new invoice. You can override them per invoice. Accepted payments e.g. \"Bank transfer, Check, Zelle\".")
                }

                // MARK: Rates & Defaults
                Section {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "car.fill", color: .blue)
                        Text("IRS Mileage Rate")
                        Spacer()
                        Text("$\(String(format: "%.2f", mileageRate))/mi")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "clock.fill", color: .indigo)
                        Text("Default Hourly Rate")
                        Spacer()
                        TextField("0.00", value: $defaultHourlyRate, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                            .focused($focusedField)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { focusedField = false }
                                }
                            }
                    }
                } header: {
                    Text("Rates & Defaults")
                } footer: {
                    Text("IRS standard mileage rate for \(Calendar.current.component(.year, from: .now)). Updated in code each January.")
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
                        Text("Tax Rate")
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
                    Toggle(isOn: $taxRemindersEnabled) {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "bell.badge.fill", color: .orange)
                            Text("Deadline Reminders")
                        }
                    }
                    .onChange(of: taxRemindersEnabled) { _, enabled in
                        Task { await TaxReminders.handleToggle(enabled: enabled) }
                    }

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
                    Text("IRS estimated tax payment deadlines. Reminders notify you a week before and the day before each deadline. If a date falls on a weekend or holiday the IRS typically extends to the next business day.")
                }

                // MARK: Presets & Quick-Fill
                Section {
                    NavigationLink {
                        PurposePresetsEditor()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "car.fill", color: .blue)
                            Text("Trip Purposes")
                        }
                    }
                    NavigationLink {
                        MileagePresetsView()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "map.fill", color: .blue)
                            Text("Mileage Presets")
                        }
                    }
                    NavigationLink {
                        ExpensePresetsView()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "creditcard.fill", color: .red)
                            Text("Expense Presets")
                        }
                    }
                } header: {
                    Text("Presets & Quick-Fill")
                } footer: {
                    Text("Quick-fill chips and saved templates for logging trips and expenses faster.")
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

                // MARK: Data Management
                Section {
                    NavigationLink {
                        RecentlyDeletedView()
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "trash", color: .gray)
                            Text("Recently Deleted")
                        }
                    }
                } footer: {
                    Text("Restore deleted items within 30 days. After that they're removed permanently.")
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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

    /// Escapes a value per RFC 4180 — wraps in quotes when it contains a comma, quote, or newline
    /// so addresses and notes with commas survive intact for the accountant's spreadsheet.
    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func buildCSV() -> URL {
        var rows: [String] = []

        // Time entries
        rows.append("=== TIME ENTRIES ===")
        rows.append("Date,Client,Project,Hours,Rate,Earnings,Notes")
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        for e in timeEntries {
            let cols = [
                csvField(dateFmt.string(from: e.date)),
                csvField(e.client?.name ?? ""),
                csvField(e.project?.name ?? ""),
                csvField(String(format: "%.2f", e.hours)),
                csvField("\(e.hourlyRate)"),
                csvField("\(e.earnings)"),
                csvField(e.notes)
            ]
            rows.append(cols.joined(separator: ","))
        }

        // Mileage trips
        rows.append("")
        rows.append("=== MILEAGE TRIPS ===")
        rows.append("Date,From Address,To Address,Stops,Miles,Rate,Reimbursement,Purpose,Notes")
        for t in trips {
            let cols = [
                csvField(dateFmt.string(from: t.date)),
                csvField(t.startAddressForExport),
                csvField(t.endAddressForExport),
                csvField(t.waypoints.joined(separator: "; ")),
                csvField(String(format: "%.2f", t.miles)),
                csvField(String(format: "%.3f", MileageTrip.ratePerMile)),
                csvField(String(format: "%.2f", t.reimbursementAmount)),
                csvField(t.purpose),
                csvField(t.notes)
            ]
            rows.append(cols.joined(separator: ","))
        }

        // Expenses
        rows.append("")
        rows.append("=== EXPENSES ===")
        rows.append("Date,Category,Amount,Client,Notes")
        for ex in expenses {
            let cols = [
                csvField(dateFmt.string(from: ex.date)),
                csvField(ex.category),
                csvField("\(ex.amount)"),
                csvField(ex.client?.name ?? ""),
                csvField(ex.notes)
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
