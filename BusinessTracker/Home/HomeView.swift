import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(TimerState.self) private var timerState
    @Query private var timeEntries: [TimeEntry]
    @Query private var trips: [MileageTrip]
    @Query private var expenses: [Expense]

    @State private var showLogTime = false
    @State private var showTimer = false
    @State private var showLogTrip = false
    @State private var showAddExpense = false
    @State private var showSettings = false

    // MARK: - Date windows

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }
    private var weekStart: Date  { Calendar.current.startOfWeek(for: .now) }

    // MARK: - Today aggregates

    private var todayEntries: [TimeEntry] { timeEntries.filter { $0.date >= todayStart } }
    private var todayTrips: [MileageTrip]  { trips.filter { $0.date >= todayStart } }
    private var todayExpenses: [Expense]   { expenses.filter { $0.date >= todayStart } }

    private var todayHours: Double   { todayEntries.reduce(0) { $0 + $1.hours } }
    private var todayMiles: Double   { todayTrips.reduce(0) { $0 + $1.miles } }
    private var todaySpend: Decimal  { todayExpenses.reduce(0) { $0 + $1.amount } }

    // MARK: - Week aggregates

    private var weekEntries: [TimeEntry] { timeEntries.filter { $0.date >= weekStart } }
    private var weekHours: Double    { weekEntries.reduce(0) { $0 + $1.hours } }
    private var weekEarnings: Decimal { weekEntries.reduce(0) { $0 + $1.earnings } }

    private var hoursSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        return String(format: "~%.1f hrs/day", weekHours / Double(days))
    }

    private var earningsSubtitle: String {
        let days = max(Calendar.current.component(.weekday, from: .now), 1)
        let avg = weekEarnings / Decimal(days)
        return "\(avg.formatted(.currency(code: "USD")))/day avg"
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Active timer — only when running
                if timerState.isRunning {
                    Section {
                        ActiveTimerCard()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .onTapGesture { showTimer = true }
                    }
                }

                // Quick Actions
                Section("Quick Actions") {
                    QuickActionRow(
                        label: timerState.isRunning ? "View Timer" : "Start Timer",
                        icon: timerState.isRunning ? "timer" : "play.fill",
                        color: .indigo
                    ) { showTimer = true }

                    QuickActionRow(
                        label: "Log Time",
                        icon: "clock.fill",
                        color: .indigo
                    ) { showLogTime = true }

                    QuickActionRow(
                        label: "Log Trip",
                        icon: "car.fill",
                        color: .blue
                    ) { showLogTrip = true }

                    QuickActionRow(
                        label: "Add Expense",
                        icon: "creditcard.fill",
                        color: .red
                    ) { showAddExpense = true }
                }

                // Today at a glance
                Section("Today") {
                    HStack(spacing: 0) {
                        TodayStatCell(
                            value: String(format: "%.1f", todayHours),
                            unit: "hrs",
                            label: "Tracked",
                            color: .indigo,
                            isEmpty: todayHours == 0
                        )
                        Divider().frame(height: 36)
                        TodayStatCell(
                            value: String(format: "%.1f", todayMiles),
                            unit: "mi",
                            label: "Driven",
                            color: .blue,
                            isEmpty: todayMiles == 0
                        )
                        Divider().frame(height: 36)
                        TodayStatCell(
                            value: todaySpend == 0 ? "$0" : todaySpend.formatted(.currency(code: "USD")),
                            unit: nil,
                            label: "Spent",
                            color: .red,
                            isEmpty: todaySpend == 0
                        )
                    }
                    .padding(.vertical, 8)
                }

                // This week
                Section("This Week") {
                    HStack(spacing: 0) {
                        WeekStatCell(
                            title: "Hours",
                            value: String(format: "%.1f hrs", weekHours),
                            subtitle: weekHours == 0 ? "Nothing logged yet" : hoursSubtitle,
                            color: .indigo
                        )
                        Divider().frame(height: 48)
                        WeekStatCell(
                            title: "Earnings",
                            value: weekEarnings.formatted(.currency(code: "USD")),
                            subtitle: weekEarnings == 0 ? "Nothing logged yet" : earningsSubtitle,
                            color: .indigo
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showLogTime)    { LogTimeView() }
            .sheet(isPresented: $showTimer)      { TimerSheet().presentationDetents([.medium]) }
            .sheet(isPresented: $showLogTrip)    { LogTripView() }
            .sheet(isPresented: $showAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showSettings)   { SettingsView() }
        }
    }
}

// MARK: - Quick action row

private struct QuickActionRow: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Today stat cell

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
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week stat cell

private struct WeekStatCell: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

#Preview {
    HomeView()
        .environment(TimerState())
        .modelContainer(for: [TimeEntry.self, MileageTrip.self, Expense.self, Client.self, Project.self], inMemory: true)
}
