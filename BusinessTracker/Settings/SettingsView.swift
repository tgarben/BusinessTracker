import SwiftUI
import SwiftData

/// First + last name for invoices and exports (read from UserDefaults so non-View code can use it).
/// The Home greeting deliberately uses only the first name (`user_name`).
func userFullName() -> String {
    let d = UserDefaults.standard
    let first = (d.string(forKey: "user_name") ?? "").trimmingCharacters(in: .whitespaces)
    let last = (d.string(forKey: "user_lastName") ?? "").trimmingCharacters(in: .whitespaces)
    return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
}

/// Formats a US phone number as the user types: (123) 456-7890, with an optional leading "1".
/// Non-US-length input (more than 10 digits without a leading 1) is left as the raw digits so
/// international numbers aren't mangled.
func formatPhoneNumber(_ raw: String) -> String {
    var digits = raw.filter(\.isNumber)
    var prefix = ""
    if digits.count == 11, digits.hasPrefix("1") {
        prefix = "1 "
        digits = String(digits.dropFirst())
    }
    guard digits.count <= 10 else { return raw.filter { $0.isNumber || $0 == "+" || $0 == " " } }

    let area = digits.prefix(3)
    let mid = digits.dropFirst(3).prefix(3)
    let last = digits.dropFirst(6)

    switch digits.count {
    case 0:     return ""
    case 1...3: return "\(prefix)(\(area)"
    case 4...6: return "\(prefix)(\(area)) \(mid)"
    default:    return "\(prefix)(\(area)) \(mid)-\(last)"
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_lastName") private var userLastName: String = ""
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
    @AppStorage("expense_presetInstantSave") private var expensePresetInstantSave: Bool = false

    // Business information (used on invoices)
    @AppStorage("business_name") private var businessName: String = ""
    @AppStorage("business_address") private var businessAddress: String = ""
    @AppStorage("business_address2") private var businessAddress2: String = ""
    @AppStorage("business_phone") private var businessPhone: String = ""
    @AppStorage("business_email") private var businessEmail: String = ""
    @AppStorage("business_website") private var businessWebsite: String = ""
    @AppStorage("business_taxID") private var businessTaxID: String = ""
    @AppStorage("business_defaultTaxRate") private var defaultTaxRate: Double = 0
    @AppStorage("business_defaultPaymentTerms") private var defaultPaymentTerms: String = "Due Upon Receipt"
    @AppStorage("business_acceptedPayments") private var acceptedPayments: String = ""
    @AppStorage("business_paymentInstructions") private var paymentInstructions: String = ""

    private let paymentTermsOptions = ["Due Upon Receipt", "Net 15", "Net 30", "Net 45", "Net 60"]

    private let appFocusOptions = ["Time Tracking", "Mileage", "Expenses", "Invoicing"]

    private var selectedFocuses: [String] {
        let set = Set(primaryUse.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return appFocusOptions.filter { set.contains($0) }   // stable display order
    }

    private func toggleFocus(_ focus: String) {
        var set = Set(selectedFocuses)
        if set.contains(focus) { set.remove(focus) } else { set.insert(focus) }
        primaryUse = appFocusOptions.filter { set.contains($0) }.joined(separator: ",")
        sectionOrder = HomeSection.orderString(forFocuses: primaryUse)
    }

    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }, sort: \TimeEntry.date, order: .reverse) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }, sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }, sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var exportItem: ExportItem?
    @State private var showTimePresets = false
    @FocusState private var fieldFocused: Bool

    // Export date range
    @State private var exportRange: ExportRange = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd: Date = .now

    private let businessStructures = [
        "Sole Proprietor", "Single-Member LLC", "Multi-Member LLC",
        "S-Corp", "C-Corp", "Partnership"
    ]

    @ViewBuilder
    private func businessField(_ label: String, text: Binding<String>, icon: String, color: Color,
                               keyboard: UIKeyboardType = .default, axis: Axis = .horizontal,
                               isPhone: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SettingsIcon(symbol: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                TextField(label, text: text, axis: axis)
                    .keyboardType(keyboard)
                    .focused($fieldFocused)
                    .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .sentences)
                    .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        guard isPhone else { return }
                        let formatted = formatPhoneNumber(newValue)
                        if formatted != newValue { text.wrappedValue = formatted }
                    }
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
                            Text(selectedFocuses.isEmpty ? "Freelanced" : selectedFocuses.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
                        Text("First Name")
                        Spacer()
                        TextField("First name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .frame(width: 120)
                            .focused($fieldFocused)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "person.text.rectangle.fill", color: .indigo)
                        Text("Last Name")
                        Spacer()
                        TextField("Last name", text: $userLastName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .frame(width: 120)
                            .focused($fieldFocused)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "square.grid.2x2.fill", color: .purple)
                            Text("App Focus")
                        }
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(appFocusOptions, id: \.self) { focus in
                                let selected = selectedFocuses.contains(focus)
                                Button { toggleFocus(focus) } label: {
                                    Text(focus)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selected ? Color.purple.opacity(0.18) : Color(.systemGray5), in: Capsule())
                                        .foregroundStyle(selected ? .purple : .primary)
                                        .overlay(Capsule().strokeBorder(selected ? Color.purple.opacity(0.45) : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Personalization")
                } footer: {
                    Text("Your first name appears in the Home screen greeting. Your last name is added on invoices and data exports only. Tap the ways you use the app — this tailors your Home screen layout.")
                }

                // MARK: Business Information
                Section {
                    businessField("Business Name", text: $businessName, icon: "building.2.fill", color: .indigo)
                    AddressEntryField(label: "Address", line1: $businessAddress, line2: $businessAddress2,
                                      icon: "mappin.and.ellipse", iconColor: .indigo)
                    businessField("Phone", text: $businessPhone, icon: "phone.fill", color: .indigo, keyboard: .phonePad, isPhone: true)
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
                            .focused($fieldFocused)
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
                            .focused($fieldFocused)
                    }
                } header: {
                    Text("Rates & Defaults")
                } footer: {
                    Text("IRS standard mileage rate for 2026. Updated in code each January.")
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
                            .focused($fieldFocused)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "dollarsign.circle.fill", color: .orange)
                        Text("Gas Price / Gallon")
                        Spacer()
                        TextField("3.80", value: $gasPrice, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 72)
                            .focused($fieldFocused)
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
                            .focused($fieldFocused)
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
                            .focused($fieldFocused)
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
                    Button { showTimePresets = true } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "clock.fill", color: .indigo)
                            Text("Time Presets").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
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
                    Toggle(isOn: $expensePresetInstantSave) {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "bolt.fill", color: .red)
                            Text("Instant-Log Expense Presets")
                        }
                    }
                } header: {
                    Text("Presets & Quick-Fill")
                } footer: {
                    Text("Quick-fill chips and saved templates for logging trips and expenses faster. With Instant-Log on, tapping an expense preset in the Expenses + menu saves it immediately (presets with a fixed amount); others still open the form.")
                }

                // MARK: Data Export
                Section {
                    Picker(selection: $exportRange) {
                        ForEach(ExportRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "calendar", color: .gray)
                            Text("Date Range")
                        }
                    }

                    if exportRange == .custom {
                        DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        DatePicker("To", selection: $customEnd, in: customStart...Date.now, displayedComponents: .date)
                    }

                    exportButton("Export All Data", icon: "square.and.arrow.up", color: .blue, scope: .all)
                    exportButton("Export Time Entries", icon: "clock.fill", color: .indigo, scope: .time)
                    exportButton("Export Mileage", icon: "car.fill", color: .blue, scope: .mileage)
                    exportButton("Export Expenses", icon: "creditcard.fill", color: .red, scope: .expenses)
                } header: {
                    Text("Data Export")
                } footer: {
                    Text("Export as CSV — all data or a single category, limited to the selected date range.")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showTimePresets) {
                PresetsView()
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

    private enum ExportScope: String {
        case all = "All Data"
        case time = "Time Entries"
        case mileage = "Mileage"
        case expenses = "Expenses"
    }

    enum ExportRange: String, CaseIterable {
        case all = "All Time"
        case month = "This Month"
        case quarter = "This Quarter"
        case year = "This Year"
        case custom = "Custom"
    }

    /// Inclusive lower/upper bounds for the selected range (nil = unbounded).
    private var exportBounds: (start: Date?, end: Date?) {
        let cal = Calendar.current
        let now = Date.now
        switch exportRange {
        case .all:     return (nil, nil)
        case .month:   return (cal.startOfMonth(for: now), now)
        case .quarter: return (cal.startOfQuarter(for: now), now)
        case .year:    return (cal.startOfYear(for: now), now)
        case .custom:
            let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
            return (cal.startOfDay(for: customStart), end)
        }
    }

    private func inExportRange(_ date: Date) -> Bool {
        let b = exportBounds
        if let s = b.start, date < s { return false }
        if let e = b.end, date > e { return false }
        return true
    }

    private var exportRangeLabel: String {
        let fmt = csvDateFormatter
        guard exportRange != .all else { return "All Time" }
        let b = exportBounds
        let start = b.start.map { fmt.string(from: $0) } ?? "—"
        let end = b.end.map { fmt.string(from: $0) } ?? "—"
        return "\(start) to \(end)"
    }

    private func exportButton(_ title: String, icon: String, color: Color, scope: ExportScope) -> some View {
        Button {
            exportItem = ExportItem(csv: buildCSV(scope))
        } label: {
            HStack(spacing: 10) {
                SettingsIcon(symbol: icon, color: color)
                Text(title).foregroundStyle(.primary)
            }
        }
    }

    private var csvDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private func csvHeaderRows() -> [String] {
        var rows: [String] = []
        let fullName = userFullName()
        if !fullName.isEmpty { rows.append("Name,\(csvField(fullName))") }
        rows.append("Exported,\(csvDateFormatter.string(from: .now))")
        rows.append("Range,\(csvField(exportRangeLabel))")
        rows.append("")
        return rows
    }

    private func timeRows() -> [String] {
        let fmt = csvDateFormatter
        var rows = ["=== TIME ENTRIES ===", "Date,Client,Project,Hours,Rate,Earnings,Notes"]
        for e in timeEntries where inExportRange(e.date) {
            rows.append([
                csvField(fmt.string(from: e.date)),
                csvField(e.client?.name ?? ""),
                csvField(e.project?.name ?? ""),
                csvField(String(format: "%.2f", e.hours)),
                csvField("\(e.hourlyRate)"),
                csvField("\(e.earnings)"),
                csvField(e.notes)
            ].joined(separator: ","))
        }
        return rows
    }

    private func mileageRows() -> [String] {
        let fmt = csvDateFormatter
        var rows = ["=== MILEAGE TRIPS ===", "Date,From Address,To Address,Stops,Miles,Rate,Reimbursement,Purpose,Notes"]
        for t in trips where inExportRange(t.date) {
            rows.append([
                csvField(fmt.string(from: t.date)),
                csvField(t.startAddressForExport),
                csvField(t.endAddressForExport),
                csvField(t.waypoints.joined(separator: "; ")),
                csvField(String(format: "%.2f", t.miles)),
                csvField(String(format: "%.3f", MileageTrip.ratePerMile)),
                csvField(String(format: "%.2f", t.reimbursementAmount)),
                csvField(t.purpose),
                csvField(t.notes)
            ].joined(separator: ","))
        }
        return rows
    }

    private func expenseRows() -> [String] {
        let fmt = csvDateFormatter
        var rows = ["=== EXPENSES ===", "Date,Category,Amount,Client,Notes"]
        for ex in expenses where inExportRange(ex.date) {
            rows.append([
                csvField(fmt.string(from: ex.date)),
                csvField(ex.category),
                csvField("\(ex.amount)"),
                csvField(ex.client?.name ?? ""),
                csvField(ex.notes)
            ].joined(separator: ","))
        }
        return rows
    }

    private func buildCSV(_ scope: ExportScope) -> URL {
        var rows = csvHeaderRows()
        switch scope {
        case .all:
            rows += timeRows() + [""] + mileageRows() + [""] + expenseRows()
        case .time:
            rows += timeRows()
        case .mileage:
            rows += mileageRows()
        case .expenses:
            rows += expenseRows()
        }

        let safeScope = scope.rawValue.replacingOccurrences(of: " ", with: "")
        let safeRange = exportRange.rawValue.replacingOccurrences(of: " ", with: "")
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Freelanced_\(safeScope)_\(safeRange)_\(csvDateFormatter.string(from: .now)).csv")
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
