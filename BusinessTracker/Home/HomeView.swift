import SwiftUI
import SwiftData

// MARK: - Section model

enum HomeSection: String, CaseIterable {
    case quickActions
    case todayGlance
    case thisWeek
    // Focus "hero" sections — surfaced by App Focus (off by default otherwise).
    case readyToInvoice      // Time Tracking (primary)
    case topClients          // Time Tracking (secondary)
    case mileageDeduction    // Mileage (primary)
    case recentTrips         // Mileage (secondary)
    case spendingByCategory  // Expenses (primary)
    case thisMonthVsLast     // Expenses (secondary)
    case outstanding         // Invoicing (primary)
    case quotePipeline       // Invoicing (secondary)
    // General sections (not tied to a focus; available via Customize Home).
    case thisMonth
    case moneySnapshot
    case recentActivity

    /// Full ordering of every section (used for the layout editor list).
    static let defaultOrderString = "quickActions,todayGlance,thisWeek,readyToInvoice,topClients,mileageDeduction,recentTrips,spendingByCategory,thisMonthVsLast,outstanding,quotePipeline,thisMonth,moneySnapshot,recentActivity"
    /// Sections shown by default for a non-curated / existing user (the original three).
    static let defaultEnabledString = "quickActions,todayGlance,thisWeek"

    /// The "hero" sections an App Focus surfaces (a primary + a secondary), in order.
    static func heroes(forUse use: String) -> [HomeSection] {
        switch use {
        case "Time Tracking", "Time & Billing": return [.readyToInvoice, .topClients]
        case "Mileage":   return [.mileageDeduction, .recentTrips]
        case "Expenses":  return [.spendingByCategory, .thisMonthVsLast]
        case "Invoicing": return [.outstanding, .quotePipeline]
        default:          return []
        }
    }

    /// App Focus is multi-select (comma-separated). Returns the curated section
    /// order + enabled set: each selected focus's hero sections lead (in selection
    /// order), followed by the always-useful Quick Actions / Today / This Week.
    /// Remaining sections are appended to `order` (disabled) so they stay
    /// reorderable/toggleable in Customize Home. No focuses → balanced default.
    static func curation(forFocuses focuses: String) -> (order: String, enabled: String) {
        let selected = focuses.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let heroSections = dedupe(selected.flatMap { Self.heroes(forUse: $0) })
        let base: [HomeSection] = [.quickActions, .todayGlance, .thisWeek]
        let enabled = dedupe(heroSections + base)
        let order = enabled + allCases.filter { !enabled.contains($0) }
        return (order.map(\.rawValue).joined(separator: ","),
                enabled.map(\.rawValue).joined(separator: ","))
    }

    private static func dedupe(_ items: [HomeSection]) -> [HomeSection] {
        var seen = Set<HomeSection>()
        return items.filter { seen.insert($0).inserted }
    }

    var title: String {
        switch self {
        case .quickActions:       return "Quick Actions"
        case .todayGlance:        return "Today"
        case .thisWeek:           return "This Week"
        case .readyToInvoice:     return "Ready to Invoice"
        case .topClients:         return "Top Clients"
        case .mileageDeduction:   return "Mileage Deduction"
        case .recentTrips:        return "Recent Trips"
        case .spendingByCategory: return "Spending by Category"
        case .thisMonthVsLast:    return "Spending vs Last Month"
        case .outstanding:        return "Outstanding"
        case .quotePipeline:      return "Quote Pipeline"
        case .thisMonth:          return "This Month"
        case .moneySnapshot:      return "Money Snapshot"
        case .recentActivity:     return "Recent Activity"
        }
    }
}

// MARK: - Quick action model

enum QuickAction: String, CaseIterable {
    case startTimer
    case logTime
    case logTrip
    case addExpense
    case createInvoice
    case createQuote

    var label: String {
        switch self {
        case .startTimer:    return "Start Timer"
        case .logTime:       return "Log Time"
        case .logTrip:       return "Log Trip"
        case .addExpense:    return "Add Expense"
        case .createInvoice: return "Create Invoice"
        case .createQuote:   return "Generate Quote"
        }
    }

    var icon: String {
        switch self {
        case .startTimer:    return "play.fill"
        case .logTime:       return "clock.fill"
        case .logTrip:       return "car.fill"
        case .addExpense:    return "creditcard.fill"
        case .createInvoice: return "doc.text.fill"
        case .createQuote:   return "list.clipboard.fill"
        }
    }

    var activeIcon: String {
        switch self {
        case .startTimer: return "timer"
        default:          return icon
        }
    }

    var color: Color {
        switch self {
        case .startTimer, .logTime: return .indigo
        case .logTrip:              return .blue
        case .addExpense:           return .red
        case .createInvoice:        return .purple
        case .createQuote:          return .teal
        }
    }

    static let defaultOrderString = "startTimer,logTime,logTrip,addExpense,createInvoice,createQuote"
    static let defaultEnabledString = "startTimer,logTime,logTrip,addExpense,createInvoice,createQuote"
}

// MARK: - Focus-hero metrics

/// A single entry in the Recent Activity feed (merged across trackers).
struct HomeActivityItem: Identifiable {
    let id = UUID()
    let date: Date
    let icon: String
    let color: Color
    let title: String
    let trailing: String
}

/// Aggregated numbers for the focus "hero" + general sections, computed once in
/// `HomeView` and passed to the section card as a single value.
struct HomeMetrics {
    // Ready to Invoice
    var unbilledHours: Double = 0
    var unbilledValue: Double = 0
    // Mileage Deduction
    var ytdMiles: Double = 0
    var ytdDeduction: Double = 0
    // Spending by Category
    var topCategories: [(name: String, total: Double)] = []
    var monthSpend: Double = 0
    // Outstanding
    var outstandingTotal: Double = 0
    var outstandingCount: Int = 0
    var overdueCount: Int = 0
    // This Month
    var monthHours: Double = 0
    var monthEarnings: Double = 0
    // Money Snapshot
    var monthIncome: Double = 0
    var monthNet: Double = 0
    // Top Clients
    var topClients: [(name: String, hours: Double, earnings: Double)] = []
    // Quote Pipeline
    var openQuoteCount: Int = 0
    var openQuoteValue: Double = 0
    // Spending vs Last Month
    var lastMonthSpend: Double = 0
    // Recent Trips
    var recentTrips: [(title: String, miles: Double, date: Date)] = []
    // Recent Activity
    var recentActivity: [HomeActivityItem] = []
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(TimerState.self) private var timerState
    @Environment(Entitlements.self) private var pro
    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }) private var expenses: [Expense]
    @Query(filter: #Predicate<Invoice> { $0.deletedDate == nil && $0.isPaid == false }) private var unpaidInvoices: [Invoice]
    @Query(filter: #Predicate<IncomeEntry> { $0.deletedDate == nil }) private var incomeEntries: [IncomeEntry]
    @Query(filter: #Predicate<Quote> { $0.deletedDate == nil }) private var quotes: [Quote]

    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("home_sectionOrder") private var sectionOrderString: String = HomeSection.defaultOrderString
    @AppStorage("home_sectionEnabled") private var sectionEnabledString: String = HomeSection.defaultEnabledString
    @AppStorage("home_quickActionOrder") private var quickActionOrderString: String = QuickAction.defaultOrderString
    @AppStorage("home_quickActionEnabled") private var quickActionEnabledString: String = QuickAction.defaultEnabledString

    @State private var showLogTime = false
    @State private var showTimer = false
    @State private var showLogTrip = false
    @State private var showAddExpense = false
    @State private var showCreateInvoice = false
    @State private var showCreateQuote = false
    @State private var showSettings = false
    @State private var showEditLayout = false
    @State private var showReports = false
    @State private var showOverdue = false
    @State private var paywall: ProFeature?

    // MARK: Overdue invoices

    private var overdueInvoices: [Invoice] { unpaidInvoices.filter { $0.isOverdue } }
    private var overdueTotal: Double { overdueInvoices.reduce(0) { $0 + $1.total } }

    // MARK: Date windows

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }
    private var weekStart: Date  { Calendar.current.startOfWeek(for: .now) }

    // MARK: Today aggregates

    private var todayEntries: [TimeEntry] { timeEntries.filter { $0.date >= todayStart } }
    private var todayTrips: [MileageTrip]  { trips.filter { $0.date >= todayStart } }
    private var todayExpenses: [Expense]   { expenses.filter { $0.date >= todayStart } }

    private var todayHours: Double   { todayEntries.reduce(0) { $0 + $1.hours } }
    private var todayMiles: Double   { todayTrips.reduce(0) { $0 + $1.miles } }
    private var todaySpend: Double   { todayExpenses.reduce(0) { $0 + $1.amount } }

    // MARK: Week aggregates

    private var weekEntries: [TimeEntry] { timeEntries.filter { $0.date >= weekStart } }
    private var weekHours: Double     { weekEntries.reduce(0) { $0 + $1.hours } }
    private var weekEarnings: Double  { weekEntries.reduce(0) { $0 + $1.earnings } }

    // MARK: Focus-hero aggregates

    private var monthStart: Date { Calendar.current.startOfMonth(for: .now) }
    private var yearStart: Date  { Calendar.current.dateInterval(of: .year, for: .now)?.start ?? .now }

    private var lastMonthStart: Date { Calendar.current.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart }

    /// Bundles every focus-hero + general section metric so they pass to the
    /// section card as one value (avoids a giant parameter list).
    private var metrics: HomeMetrics {
        // Ready to Invoice — unbilled time
        let unbilled = timeEntries.filter { $0.invoice == nil }
        // Mileage deduction — year to date
        let ytdMiles = trips.filter { $0.date >= yearStart }.reduce(0.0) { $0 + $1.miles }
        // This-month windows
        let monthExpenses = expenses.filter { $0.date >= monthStart }
        let monthEntries = timeEntries.filter { $0.date >= monthStart }
        let lastMonthExpenses = expenses.filter { $0.date >= lastMonthStart && $0.date < monthStart }
        let monthSpend = monthExpenses.reduce(0.0) { $0 + $1.amount }
        let monthIncome = incomeEntries.filter { $0.date >= monthStart }.reduce(0.0) { $0 + $1.amount }
        // Spending by category — this month, top 3
        let byCategory = Dictionary(grouping: monthExpenses, by: { $0.category })
            .map { (name: $0.key, total: $0.value.reduce(0.0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
        // Top clients — this month, by hours
        let byClient = Dictionary(grouping: monthEntries, by: { $0.client?.name ?? "Uncategorized" })
            .map { (name: $0.key,
                    hours: $0.value.reduce(0.0) { $0 + $1.hours },
                    earnings: $0.value.reduce(0.0) { $0 + $1.earnings }) }
            .sorted { $0.hours > $1.hours }
        // Quote pipeline — open (Draft/Sent) quotes
        let openQuotes = quotes.filter { $0.displayStatus == .draft || $0.displayStatus == .sent }
        // Recent trips
        let recentTrips = trips.sorted { $0.date > $1.date }.prefix(3).map {
            (title: $0.routeDescription, miles: $0.miles, date: $0.date)
        }
        // Recent activity — merged feed across trackers, newest first
        var activity: [HomeActivityItem] = []
        activity += timeEntries.map {
            HomeActivityItem(date: $0.date, icon: "clock.fill", color: .indigo,
                             title: $0.project?.name ?? $0.client?.name ?? "Time",
                             trailing: String(format: "%.1f hrs", $0.hours))
        }
        activity += trips.map {
            HomeActivityItem(date: $0.date, icon: "car.fill", color: .blue,
                             title: $0.purpose.isEmpty ? $0.routeDescription : $0.purpose,
                             trailing: String(format: "%.0f mi", $0.miles))
        }
        activity += expenses.map {
            HomeActivityItem(date: $0.date, icon: "creditcard.fill", color: .red,
                             title: $0.category,
                             trailing: $0.amount.asCurrency)
        }
        let recentActivity = Array(activity.sorted { $0.date > $1.date }.prefix(4))

        return HomeMetrics(
            unbilledHours: unbilled.reduce(0) { $0 + $1.hours },
            unbilledValue: unbilled.reduce(0) { $0 + $1.earnings },
            ytdMiles: ytdMiles,
            ytdDeduction: ytdMiles * MileageTrip.ratePerMile,
            topCategories: Array(byCategory.prefix(3)),
            monthSpend: monthSpend,
            outstandingTotal: unpaidInvoices.reduce(0) { $0 + $1.total },
            outstandingCount: unpaidInvoices.count,
            overdueCount: overdueInvoices.count,
            monthHours: monthEntries.reduce(0) { $0 + $1.hours },
            monthEarnings: monthEntries.reduce(0) { $0 + $1.earnings },
            monthIncome: monthIncome,
            monthNet: monthIncome - monthSpend,
            topClients: Array(byClient.prefix(3)),
            openQuoteCount: openQuotes.count,
            openQuoteValue: openQuotes.reduce(0) { $0 + $1.total },
            lastMonthSpend: lastMonthExpenses.reduce(0) { $0 + $1.amount },
            recentTrips: Array(recentTrips),
            recentActivity: recentActivity
        )
    }

    private var hoursSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        return String(format: "~%.1f hrs/day", weekHours / Double(days))
    }

    private var earningsSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        let avg = weekEarnings / Double(days)
        return "\(avg.asCurrency)/day avg"
    }

    // MARK: Greeting

    private var greeting: String {
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Hey," : "Hey \(name),"
    }

    // MARK: Parsed order helpers

    private var sectionOrder: [HomeSection] {
        let parsed = sectionOrderString.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) }
        let missing = HomeSection.allCases.filter { !parsed.contains($0) }
        return parsed + missing
    }

    private var enabledSections: Set<HomeSection> {
        Set(sectionEnabledString.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) })
    }

    /// A section renders when it's enabled — except Quick Actions, which also
    /// needs at least one enabled quick action.
    private func isVisible(_ section: HomeSection) -> Bool {
        guard enabledSections.contains(section) else { return false }
        if section == .quickActions { return !enabledQuickActions.isEmpty }
        return true
    }

    private var enabledQuickActions: [QuickAction] {
        let enabled = Set(quickActionEnabledString.split(separator: ",").map { String($0) })
        return quickActionOrderString
            .split(separator: ",")
            .compactMap { QuickAction(rawValue: String($0)) }
            .filter { enabled.contains($0.rawValue) }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                // Active timer — pinned, not reorderable (shows while paused too)
                if timerState.isActive {
                    ActiveTimerCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture { showTimer = true }
                }

                // Overdue invoices — pinned alert card
                if !overdueInvoices.isEmpty {
                    OverdueInvoicesCard(count: overdueInvoices.count, total: overdueTotal)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture { showOverdue = true }
                }

                ForEach(sectionOrder, id: \.self) { section in
                    if isVisible(section) {
                    HomeSectionCard(section: section,
                                    timerRunning: timerState.isActive,
                                    enabledQuickActions: enabledQuickActions,
                                    todayHours: todayHours,
                                    todayMiles: todayMiles,
                                    todaySpend: todaySpend,
                                    weekHours: weekHours,
                                    weekEarnings: weekEarnings,
                                    hoursSubtitle: hoursSubtitle,
                                    earningsSubtitle: earningsSubtitle,
                                    metrics: metrics,
                                    showTimer: $showTimer,
                                    showLogTime: $showLogTime,
                                    showLogTrip: $showLogTrip,
                                    showAddExpense: $showAddExpense,
                                    showCreateInvoice: $showCreateInvoice,
                                    showCreateQuote: $showCreateQuote,
                                    paywall: $paywall)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        ProfileToolbarLabel()
                    }
                    .accessibilityLabel("Profile & Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if pro.isProEffective { showReports = true } else { paywall = .reports }
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Reports")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditLayout = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Customize Home")
                }
            }
            .sheet(isPresented: $showLogTime)       { LogTimeView() }
            .sheet(isPresented: $showTimer)         { TimerSheet() }
            .sheet(isPresented: $showLogTrip)       { LogTripView() }
            .sheet(isPresented: $showAddExpense)    { AddExpenseView() }
            .sheet(isPresented: $showCreateInvoice) { InvoiceQuickActionSheet() }
            .sheet(isPresented: $showCreateQuote)   { QuoteQuickActionSheet() }
            .sheet(isPresented: $showReports)    { ReportsView().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showOverdue)    { OverdueInvoicesView() }
            .sheet(isPresented: $showSettings)   { SettingsView() }
            .proPaywall($paywall)
            .sheet(isPresented: $showEditLayout) {
                HomeLayoutEditor(
                    sectionOrderString: $sectionOrderString,
                    sectionEnabledString: $sectionEnabledString,
                    quickActionOrderString: $quickActionOrderString,
                    quickActionEnabledString: $quickActionEnabledString
                )
            }
        }
    }
}

// MARK: - Section card

private struct HomeSectionCard: View {
    @Environment(Entitlements.self) private var pro
    let section: HomeSection
    let timerRunning: Bool
    let enabledQuickActions: [QuickAction]
    let todayHours: Double
    let todayMiles: Double
    let todaySpend: Double
    let weekHours: Double
    let weekEarnings: Double
    let hoursSubtitle: String
    let earningsSubtitle: String
    let metrics: HomeMetrics

    @Binding var showTimer: Bool
    @Binding var showLogTime: Bool
    @Binding var showLogTrip: Bool
    @Binding var showAddExpense: Bool
    @Binding var showCreateInvoice: Bool
    @Binding var showCreateQuote: Bool
    @Binding var paywall: ProFeature?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title.uppercased())
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 7)

            VStack(spacing: 0) {
                switch section {
                case .quickActions:       quickActionsContent
                case .todayGlance:        todayContent
                case .thisWeek:           weekContent
                case .readyToInvoice:     readyToInvoiceContent
                case .topClients:         topClientsContent
                case .mileageDeduction:   mileageDeductionContent
                case .recentTrips:        recentTripsContent
                case .spendingByCategory: spendingByCategoryContent
                case .thisMonthVsLast:    thisMonthVsLastContent
                case .outstanding:        outstandingContent
                case .quotePipeline:      quotePipelineContent
                case .thisMonth:          thisMonthContent
                case .moneySnapshot:      moneySnapshotContent
                case .recentActivity:     recentActivityContent
                }
            }
            .background(
                section == .quickActions
                    ? Color.clear
                    : Color(.secondarySystemGroupedBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // MARK: Quick Actions — 2-wide grid

    @ViewBuilder
    private var quickActionsContent: some View {
        // Adaptive so wide layouts (iPad) flow into 3+ columns instead of two
        // very wide cells, while iPhone stays at two per row.
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(enabledQuickActions.enumerated()), id: \.offset) { _, action in
                let isActive = action == .startTimer && timerRunning
                Button {
                    switch action {
                    case .startTimer:    showTimer = true
                    case .logTime:       showLogTime = true
                    case .logTrip:       showLogTrip = true
                    case .addExpense:    showAddExpense = true
                    case .createInvoice: if pro.isProEffective { showCreateInvoice = true } else { paywall = .invoicing }
                    case .createQuote:   if pro.isProEffective { showCreateQuote = true } else { paywall = .quotes }
                    }
                } label: {
                    QuickActionCell(action: action, isActive: isActive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: Today

    @ViewBuilder
    private var todayContent: some View {
        HStack(spacing: 0) {
            TodayStatCell(value: String(format: "%.1f", todayHours), unit: "hrs",
                          label: "Tracked", color: .indigo, isEmpty: todayHours == 0)
            Divider().frame(height: 36)
            TodayStatCell(value: String(format: "%.1f", todayMiles), unit: "mi",
                          label: "Driven", color: .blue, isEmpty: todayMiles == 0)
            Divider().frame(height: 36)
            TodayStatCell(value: todaySpend == 0 ? "$0" : todaySpend.asCurrency,
                          unit: nil, label: "Spent", color: .red, isEmpty: todaySpend == 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: This Week

    @ViewBuilder
    private var weekContent: some View {
        HStack(spacing: 0) {
            WeekStatCell(title: "Hours",
                         value: String(format: "%.1f hrs", weekHours),
                         subtitle: weekHours == 0 ? "Nothing logged yet" : hoursSubtitle,
                         color: .indigo)
            Divider().frame(height: 48)
            WeekStatCell(title: "Earnings",
                         value: weekEarnings.asCurrency,
                         subtitle: weekEarnings == 0 ? "Nothing logged yet" : earningsSubtitle,
                         color: .indigo)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: Ready to Invoice (Time Tracking focus)

    @ViewBuilder
    private var readyToInvoiceContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(metrics.unbilledValue == 0 ? "$0" : metrics.unbilledValue.asCurrency)
                    .font(.title2.bold())
                    .foregroundStyle(metrics.unbilledValue == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.green))
                Spacer()
                Text(metrics.unbilledValue == 0
                     ? "All caught up"
                     : String(format: "%.1f hrs unbilled", metrics.unbilledHours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if metrics.unbilledValue > 0 {
                Button {
                    if pro.isProEffective { showCreateInvoice = true } else { paywall = .invoicing }
                } label: {
                    Label("Create Invoice", systemImage: "doc.text.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    // MARK: Mileage Deduction (Mileage focus)

    @ViewBuilder
    private var mileageDeductionContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(metrics.ytdDeduction == 0 ? "$0" : metrics.ytdDeduction.asCurrency)
                    .font(.title2.bold())
                    .foregroundStyle(metrics.ytdDeduction == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.blue))
                Text(metrics.ytdMiles == 0
                     ? "No miles logged this year"
                     : String(format: "%.0f mi this year · est. deduction", metrics.ytdMiles))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "car.fill")
                .font(.title)
                .foregroundStyle(.blue.opacity(0.25))
        }
        .padding(14)
    }

    // MARK: Spending by Category (Expenses focus)

    @ViewBuilder
    private var spendingByCategoryContent: some View {
        if metrics.topCategories.isEmpty {
            HStack {
                Text("No expenses this month")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(14)
        } else {
            let maxTotal = metrics.topCategories.map(\.total).max() ?? 1
            VStack(spacing: 10) {
                ForEach(metrics.topCategories, id: \.name) { cat in
                    HStack(spacing: 10) {
                        Image(systemName: Expense.categoryIcon(cat.name))
                            .font(.caption)
                            .foregroundStyle(categoryColor(cat.name))
                            .frame(width: 18)
                        Text(cat.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.red.opacity(0.12))
                                Capsule().fill(Color.red.opacity(0.55))
                                    .frame(width: max(6, geo.size.width * (cat.total / maxTotal)))
                            }
                        }
                        .frame(height: 8)
                        Text(cat.total.asCurrency)
                            .font(.caption.weight(.semibold))
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: Outstanding (Invoicing focus)

    @ViewBuilder
    private var outstandingContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(metrics.outstandingTotal == 0 ? "$0" : metrics.outstandingTotal.asCurrency)
                    .font(.title2.bold())
                    .foregroundStyle(metrics.outstandingTotal == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                Text(outstandingSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "banknote.fill")
                .font(.title)
                .foregroundStyle(.orange.opacity(0.25))
        }
        .padding(14)
    }

    private var outstandingSubtitle: String {
        guard metrics.outstandingCount > 0 else { return "All invoices paid" }
        let unpaid = "\(metrics.outstandingCount) unpaid"
        return metrics.overdueCount > 0 ? "\(unpaid) · \(metrics.overdueCount) overdue" : unpaid
    }

    // MARK: This Month (general)

    @ViewBuilder
    private var thisMonthContent: some View {
        HStack(spacing: 0) {
            WeekStatCell(title: "Hours",
                         value: String(format: "%.1f hrs", metrics.monthHours),
                         subtitle: metrics.monthHours == 0 ? "Nothing logged yet" : "this month",
                         color: .indigo)
            Divider().frame(height: 48)
            WeekStatCell(title: "Earnings",
                         value: metrics.monthEarnings.asCurrency,
                         subtitle: metrics.monthEarnings == 0 ? "Nothing logged yet" : "this month",
                         color: .indigo)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: Money Snapshot (general)

    @ViewBuilder
    private var moneySnapshotContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metrics.monthNet.asCurrency)
                        .font(.title2.bold())
                        .foregroundStyle(metrics.monthNet >= 0 ? Color.green : Color.red)
                    Text("Net this month").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                miniMoneyCell("Income", metrics.monthIncome, .green)
                Divider().frame(height: 28)
                miniMoneyCell("Expenses", metrics.monthSpend, .red)
            }
        }
        .padding(14)
    }

    private func miniMoneyCell(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.asCurrency).font(.subheadline.weight(.semibold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Top Clients (Time Tracking)

    @ViewBuilder
    private var topClientsContent: some View {
        if metrics.topClients.isEmpty {
            mutedPlaceholder("No time logged this month").padding(14)
        } else {
            let maxHours = metrics.topClients.map(\.hours).max() ?? 1
            VStack(spacing: 10) {
                ForEach(metrics.topClients, id: \.name) { client in
                    HStack(spacing: 10) {
                        Text(client.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(width: 88, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.indigo.opacity(0.12))
                                Capsule().fill(Color.indigo.opacity(0.55))
                                    .frame(width: max(6, geo.size.width * (client.hours / maxHours)))
                            }
                        }
                        .frame(height: 8)
                        Text(client.earnings.asCurrency)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(width: 66, alignment: .trailing)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: Quote Pipeline (Invoicing)

    @ViewBuilder
    private var quotePipelineContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(metrics.openQuoteValue == 0 ? "$0" : metrics.openQuoteValue.asCurrency)
                    .font(.title2.bold())
                    .foregroundStyle(metrics.openQuoteCount == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.teal))
                Text(metrics.openQuoteCount == 0
                     ? "No open quotes"
                     : "\(metrics.openQuoteCount) open · awaiting reply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "list.clipboard.fill")
                .font(.title)
                .foregroundStyle(.teal.opacity(0.25))
        }
        .padding(14)
    }

    // MARK: Spending vs Last Month (Expenses)

    @ViewBuilder
    private var thisMonthVsLastContent: some View {
        let delta = metrics.monthSpend - metrics.lastMonthSpend
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(metrics.monthSpend == 0 ? "$0" : metrics.monthSpend.asCurrency)
                    .font(.title2.bold())
                    .foregroundStyle(metrics.monthSpend == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.red))
                Text(spendDeltaText(delta))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if metrics.lastMonthSpend > 0 || metrics.monthSpend > 0, delta != 0 {
                Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(delta > 0 ? .red : .green)
            }
        }
        .padding(14)
    }

    private func spendDeltaText(_ delta: Double) -> String {
        if metrics.monthSpend == 0 && metrics.lastMonthSpend == 0 { return "No expenses this month" }
        if delta == 0 { return "Same as last month" }
        let mag = abs(delta).asCurrency
        return delta > 0 ? "\(mag) more than last month" : "\(mag) less than last month"
    }

    // MARK: Recent Trips (Mileage)

    @ViewBuilder
    private var recentTripsContent: some View {
        VStack(spacing: 10) {
            if metrics.recentTrips.isEmpty {
                mutedPlaceholder("No trips logged yet")
            } else {
                ForEach(Array(metrics.recentTrips.enumerated()), id: \.offset) { _, trip in
                    HStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(trip.title).font(.caption).foregroundStyle(.primary).lineLimit(1)
                            Text(trip.date, format: .dateTime.month().day())
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(String(format: "%.0f mi", trip.miles))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            Button { showLogTrip = true } label: {
                Label("Log Trip", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: Recent Activity (general)

    @ViewBuilder
    private var recentActivityContent: some View {
        if metrics.recentActivity.isEmpty {
            mutedPlaceholder("Nothing logged yet").padding(14)
        } else {
            VStack(spacing: 10) {
                ForEach(metrics.recentActivity) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.caption)
                            .foregroundStyle(item.color)
                            .frame(width: 18)
                        Text(item.title).font(.caption).foregroundStyle(.primary).lineLimit(1)
                        Spacer()
                        Text(item.trailing).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(item.date, format: .dateTime.month().day())
                            .font(.caption2).foregroundStyle(.tertiary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            .padding(14)
        }
    }

    private func mutedPlaceholder(_ text: String) -> some View {
        HStack {
            Text(text).font(.subheadline).foregroundStyle(.tertiary)
            Spacer()
        }
    }

    /// Maps `Expense.categoryColor`'s string name to a SwiftUI `Color`.
    private func categoryColor(_ category: String) -> Color {
        switch Expense.categoryColor(category) {
        case "orange": return .orange
        case "gray":   return .gray
        case "blue":   return .blue
        case "teal":   return .teal
        case "green":  return .green
        case "pink":   return .pink
        case "yellow": return .yellow
        case "brown":  return .brown
        case "indigo": return .indigo
        default:       return .secondary
        }
    }
}

// MARK: - Home Layout Editor sheet

struct HomeLayoutEditor: View {
    @Binding var sectionOrderString: String
    @Binding var sectionEnabledString: String
    @Binding var quickActionOrderString: String
    @Binding var quickActionEnabledString: String

    @Environment(\.dismiss) private var dismiss

    // Full ordering of every item + the enabled set. One list per tab — items
    // never move between lists, so nothing is appended mid-session (which is what
    // dropped edit-mode decorations / forced a scroll-resetting rebuild). Reorder
    // mutates the *All array; the toggle flips membership in the *Enabled set.
    @State private var sectionsAll: [HomeSection] = []
    @State private var sectionEnabledSet: Set<HomeSection> = []
    @State private var actionsAll: [QuickAction] = []
    @State private var actionEnabledSet: Set<QuickAction> = []

    private enum EditorTab: String, CaseIterable { case sections = "Sections", quickActions = "Quick Actions" }
    @State private var tab: EditorTab = .sections

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $tab) {
                        ForEach(EditorTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if tab == .sections { sectionsEditor } else { actionsEditor }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { loadCurrent() }
    }

    // MARK: Sections tab

    @ViewBuilder
    private var sectionsEditor: some View {
        Section {
            ForEach(sectionsAll, id: \.self) { section in
                toggleRow(icon: sectionIcon(section), color: sectionColor(section), title: section.title,
                          caption: section == .quickActions && actionEnabledSet.isEmpty ? "No actions enabled" : nil,
                          isOn: Binding(
                            get: { sectionEnabledSet.contains(section) },
                            set: { on in
                                if on { sectionEnabledSet.insert(section) } else { sectionEnabledSet.remove(section) }
                            }
                          ))
            }
            .onMove { from, to in sectionsAll.move(fromOffsets: from, toOffset: to) }
        } header: {
            Text("Sections")
        } footer: {
            Text("Turn sections on or off. Drag the ☰ handle to reorder.")
        }
    }

    // MARK: Quick Actions tab

    @ViewBuilder
    private var actionsEditor: some View {
        Section {
            ForEach(actionsAll, id: \.self) { action in
                toggleRow(icon: action.icon, color: action.color, title: action.label, caption: nil,
                          isOn: Binding(
                            get: { actionEnabledSet.contains(action) },
                            set: { on in
                                if on { actionEnabledSet.insert(action) } else { actionEnabledSet.remove(action) }
                            }
                          ))
            }
            .onMove { from, to in actionsAll.move(fromOffsets: from, toOffset: to) }
        } header: {
            Text("Quick Actions")
        } footer: {
            Text("Turn actions on or off. Drag the ☰ handle to reorder.")
        }
    }

    private func toggleRow(icon: String, color: Color, title: String, caption: String?, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(.primary)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
    }

    private func loadCurrent() {
        sectionsAll = sectionOrderString
            .split(separator: ",")
            .compactMap { HomeSection(rawValue: String($0)) }
        sectionsAll += HomeSection.allCases.filter { !sectionsAll.contains($0) }
        sectionEnabledSet = Set(sectionEnabledString.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) })

        actionsAll = quickActionOrderString
            .split(separator: ",")
            .compactMap { QuickAction(rawValue: String($0)) }
        actionsAll += QuickAction.allCases.filter { !actionsAll.contains($0) }
        actionEnabledSet = Set(quickActionEnabledString.split(separator: ",").compactMap { QuickAction(rawValue: String($0)) })
    }

    private func save() {
        sectionOrderString = sectionsAll.map(\.rawValue).joined(separator: ",")
        sectionEnabledString = sectionsAll.filter { sectionEnabledSet.contains($0) }.map(\.rawValue).joined(separator: ",")
        quickActionOrderString = actionsAll.map(\.rawValue).joined(separator: ",")
        quickActionEnabledString = actionsAll.filter { actionEnabledSet.contains($0) }.map(\.rawValue).joined(separator: ",")
        dismiss()
    }

    private func sectionIcon(_ section: HomeSection) -> String {
        switch section {
        case .quickActions:       return "bolt.fill"
        case .todayGlance:        return "sun.max.fill"
        case .thisWeek:           return "calendar"
        case .readyToInvoice:     return "doc.text.fill"
        case .topClients:         return "person.2.fill"
        case .mileageDeduction:   return "car.fill"
        case .recentTrips:        return "map.fill"
        case .spendingByCategory: return "chart.pie.fill"
        case .thisMonthVsLast:    return "chart.line.uptrend.xyaxis"
        case .outstanding:        return "banknote.fill"
        case .quotePipeline:      return "list.clipboard.fill"
        case .thisMonth:          return "calendar.badge.clock"
        case .moneySnapshot:      return "dollarsign.circle.fill"
        case .recentActivity:     return "clock.arrow.circlepath"
        }
    }

    private func sectionColor(_ section: HomeSection) -> Color {
        switch section {
        case .quickActions:       return .purple
        case .todayGlance:        return .orange
        case .thisWeek:           return .indigo
        case .readyToInvoice:     return .green
        case .topClients:         return .indigo
        case .mileageDeduction:   return .blue
        case .recentTrips:        return .blue
        case .spendingByCategory: return .red
        case .thisMonthVsLast:    return .red
        case .outstanding:        return .orange
        case .quotePipeline:      return .teal
        case .thisMonth:          return .indigo
        case .moneySnapshot:      return .green
        case .recentActivity:     return .gray
        }
    }
}

// MARK: - Overdue invoices card

private struct OverdueInvoicesCard: View {
    let count: Int
    let total: Double

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.red.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Overdue Invoice\(count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                Text("\(total.asCurrency) outstanding")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Quick Action cell

private struct QuickActionCell: View {
    let action: QuickAction
    let isActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(action.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: isActive ? action.activeIcon : action.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(action.color)
            }
            Text(isActive ? "View Timer" : action.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(action.color.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(action.color.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Stat cells

private struct TodayStatCell: View {
    let value: String
    let unit: String?
    let label: String
    let color: Color
    let isEmpty: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                if let unit {
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WeekStatCell: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

#Preview {
    HomeView()
        .environment(TimerState())
        .environment(Entitlements())
        .modelContainer(for: [TimeEntry.self, MileageTrip.self, Expense.self, Client.self, Project.self, Invoice.self, IncomeEntry.self, Quote.self], inMemory: true)
}
