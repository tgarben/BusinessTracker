import SwiftUI
import SwiftData

// MARK: - Section model

enum HomeSection: String, CaseIterable {
    case quickActions
    case todayGlance
    case thisWeek

    static let defaultOrderString = "quickActions,todayGlance,thisWeek"

    static func orderString(forUse use: String) -> String {
        switch use {
        case "Time Tracking", "Time & Billing": return "thisWeek,quickActions,todayGlance"
        case "Mileage":        return "todayGlance,thisWeek,quickActions"
        case "Expenses":       return "todayGlance,quickActions,thisWeek"
        default:               return defaultOrderString
        }
    }

    /// App Focus is multi-select (comma-separated). When exactly one focus is chosen we
    /// tailor the Home section order to it; otherwise we use the balanced default.
    static func orderString(forFocuses focuses: String) -> String {
        let set = focuses.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard set.count == 1, let only = set.first else { return defaultOrderString }
        return orderString(forUse: only)
    }

    var title: String {
        switch self {
        case .quickActions: return "Quick Actions"
        case .todayGlance:  return "Today"
        case .thisWeek:     return "This Week"
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

    var label: String {
        switch self {
        case .startTimer:    return "Start Timer"
        case .logTime:       return "Log Time"
        case .logTrip:       return "Log Trip"
        case .addExpense:    return "Add Expense"
        case .createInvoice: return "Create Invoice"
        }
    }

    var icon: String {
        switch self {
        case .startTimer:    return "play.fill"
        case .logTime:       return "clock.fill"
        case .logTrip:       return "car.fill"
        case .addExpense:    return "creditcard.fill"
        case .createInvoice: return "doc.text.fill"
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
        }
    }

    static let defaultOrderString = "startTimer,logTime,logTrip,addExpense,createInvoice"
    static let defaultEnabledString = "startTimer,logTime,logTrip,addExpense,createInvoice"
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(TimerState.self) private var timerState
    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }) private var timeEntries: [TimeEntry]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }) private var trips: [MileageTrip]
    @Query(filter: #Predicate<Expense> { $0.deletedDate == nil }) private var expenses: [Expense]

    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("home_sectionOrder") private var sectionOrderString: String = HomeSection.defaultOrderString
    @AppStorage("home_quickActionOrder") private var quickActionOrderString: String = QuickAction.defaultOrderString
    @AppStorage("home_quickActionEnabled") private var quickActionEnabledString: String = QuickAction.defaultEnabledString

    @State private var showLogTime = false
    @State private var showTimer = false
    @State private var showLogTrip = false
    @State private var showAddExpense = false
    @State private var showCreateInvoice = false
    @State private var showSettings = false
    @State private var showEditLayout = false
    @State private var showReports = false

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

    private var hoursSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        return String(format: "~%.1f hrs/day", weekHours / Double(days))
    }

    private var earningsSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        let avg = weekEarnings / Double(days)
        return "\(avg.formatted(.currency(code: "USD")))/day avg"
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
                // Active timer — pinned, not reorderable
                if timerState.isRunning {
                    ActiveTimerCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture { showTimer = true }
                }

                ForEach(sectionOrder, id: \.self) { section in
                    if section == .quickActions && enabledQuickActions.isEmpty { EmptyView() } else {
                    HomeSectionCard(section: section,
                                    timerRunning: timerState.isRunning,
                                    enabledQuickActions: enabledQuickActions,
                                    todayHours: todayHours,
                                    todayMiles: todayMiles,
                                    todaySpend: todaySpend,
                                    weekHours: weekHours,
                                    weekEarnings: weekEarnings,
                                    hoursSubtitle: hoursSubtitle,
                                    earningsSubtitle: earningsSubtitle,
                                    showTimer: $showTimer,
                                    showLogTime: $showLogTime,
                                    showLogTrip: $showLogTrip,
                                    showAddExpense: $showAddExpense,
                                    showCreateInvoice: $showCreateInvoice)
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
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showReports = true } label: {
                        Image(systemName: "chart.bar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditLayout = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showLogTime)       { LogTimeView() }
            .sheet(isPresented: $showTimer)         { TimerSheet().presentationDetents([.medium,.large]) }
            .sheet(isPresented: $showLogTrip)       { LogTripView() }
            .sheet(isPresented: $showAddExpense)    { AddExpenseView() }
            .sheet(isPresented: $showCreateInvoice) { InvoiceQuickActionSheet() }
            .sheet(isPresented: $showReports)    { ReportsView().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showSettings)   { SettingsView() }
            .sheet(isPresented: $showEditLayout) {
                HomeLayoutEditor(
                    sectionOrderString: $sectionOrderString,
                    quickActionOrderString: $quickActionOrderString,
                    quickActionEnabledString: $quickActionEnabledString
                )
            }
        }
    }
}

// MARK: - Section card

private struct HomeSectionCard: View {
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

    @Binding var showTimer: Bool
    @Binding var showLogTime: Bool
    @Binding var showLogTrip: Bool
    @Binding var showAddExpense: Bool
    @Binding var showCreateInvoice: Bool

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
                case .quickActions: quickActionsContent
                case .todayGlance:  todayContent
                case .thisWeek:     weekContent
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
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(enabledQuickActions.enumerated()), id: \.offset) { _, action in
                let isActive = action == .startTimer && timerRunning
                Button {
                    switch action {
                    case .startTimer:    showTimer = true
                    case .logTime:       showLogTime = true
                    case .logTrip:       showLogTrip = true
                    case .addExpense:    showAddExpense = true
                    case .createInvoice: showCreateInvoice = true
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
            TodayStatCell(value: todaySpend == 0 ? "$0" : todaySpend.formatted(.currency(code: "USD")),
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
                         value: weekEarnings.formatted(.currency(code: "USD")),
                         subtitle: weekEarnings == 0 ? "Nothing logged yet" : earningsSubtitle,
                         color: .indigo)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Home Layout Editor sheet

struct HomeLayoutEditor: View {
    @Binding var sectionOrderString: String
    @Binding var quickActionOrderString: String
    @Binding var quickActionEnabledString: String

    @Environment(\.dismiss) private var dismiss

    // Local working copies
    @State private var sections: [HomeSection] = []
    @State private var actionOrder: [QuickAction] = []
    @State private var actionEnabled: Set<QuickAction> = []

    var body: some View {
        NavigationStack {
            List {
                // MARK: Section order
                Section {
                    ForEach(sections, id: \.self) { section in
                        let disabled = section == .quickActions && actionEnabled.isEmpty
                        HStack(spacing: 12) {
                            Image(systemName: sectionIcon(section))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(
                                    (disabled ? Color.secondary : sectionColor(section)),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            Text(section.title)
                                .foregroundStyle(disabled ? .secondary : .primary)
                            if disabled {
                                Spacer()
                                Text("No actions enabled")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .deleteDisabled(true)
                        .moveDisabled(disabled)
                    }
                    .onMove { from, to in
                        sections.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("Section Order")
                } footer: {
                    Text("Drag to reorder sections on your Home screen.")
                }

                // MARK: Quick Actions
                Section {
                    ForEach(actionOrder, id: \.self) { action in
                        HStack(spacing: 12) {
                            Image(systemName: action.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(action.color, in: RoundedRectangle(cornerRadius: 7))
                            Text(action.label)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { actionEnabled.contains(action) },
                                set: { on in
                                    if on { actionEnabled.insert(action) }
                                    else  { actionEnabled.remove(action) }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove { from, to in
                        actionOrder.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("Toggle actions on or off and drag to reorder.")
                }
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

    private func loadCurrent() {
        sections = sectionOrderString
            .split(separator: ",")
            .compactMap { HomeSection(rawValue: String($0)) }
        let missing = HomeSection.allCases.filter { !sections.contains($0) }
        sections += missing

        actionOrder = quickActionOrderString
            .split(separator: ",")
            .compactMap { QuickAction(rawValue: String($0)) }
        let missingActions = QuickAction.allCases.filter { !actionOrder.contains($0) }
        actionOrder += missingActions

        actionEnabled = Set(
            quickActionEnabledString
                .split(separator: ",")
                .compactMap { QuickAction(rawValue: String($0)) }
        )
    }

    private func save() {
        sectionOrderString = sections.map(\.rawValue).joined(separator: ",")
        quickActionOrderString = actionOrder.map(\.rawValue).joined(separator: ",")
        quickActionEnabledString = actionOrder
            .filter { actionEnabled.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        dismiss()
    }

    private func sectionIcon(_ section: HomeSection) -> String {
        switch section {
        case .quickActions: return "bolt.fill"
        case .todayGlance:  return "sun.max.fill"
        case .thisWeek:     return "calendar"
        }
    }

    private func sectionColor(_ section: HomeSection) -> Color {
        switch section {
        case .quickActions: return .purple
        case .todayGlance:  return .orange
        case .thisWeek:     return .indigo
        }
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
        .modelContainer(for: [TimeEntry.self, MileageTrip.self, Expense.self, Client.self, Project.self], inMemory: true)
}
