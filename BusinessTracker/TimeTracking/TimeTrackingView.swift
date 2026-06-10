import SwiftUI
import SwiftData

struct TimeTrackingView: View {
    @Environment(TimerState.self) private var timerState
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]

    @State private var showLogTime = false
    @State private var showTimer = false
    @State private var showClients = false
    @State private var showPresets = false
    @State private var showSettings = false
    @State private var entryToEdit: TimeEntry?

    // Week summary
    private var weekEntries: [TimeEntry] {
        let start = Calendar.current.startOfWeek(for: .now)
        return entries.filter { $0.date >= start }
    }

    private var weekHours: Double { weekEntries.reduce(0) { $0 + $1.hours } }
    private var weekEarnings: Decimal { weekEntries.reduce(0) { $0 + $1.earnings } }

    var body: some View {
        NavigationStack {
            List {
                // Week summary card
                Section {
                    WeekSummaryCard(hours: weekHours, earnings: weekEarnings)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Active timer card (only when running)
                if timerState.isRunning {
                    Section {
                        ActiveTimerCard()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .onTapGesture { showTimer = true }
                    }
                }

                // Entries grouped by date
                if !entries.isEmpty {
                    let grouped = Dictionary(grouping: entries) {
                        Calendar.current.startOfDay(for: $0.date)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)

                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(day, style: .date)) {
                            ForEach(grouped[day] ?? []) { entry in
                                TimeEntryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture { entryToEdit = entry }
                            }
                            .onDelete { indexSet in
                                deleteEntries(from: grouped[day] ?? [], at: indexSet)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Time Logged",
                        systemImage: "clock",
                        description: Text("Tap + to log hours or start a timer.")
                    )
                }
            }
            .navigationTitle("Time Tracking")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarSpacer(placement: .topBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Clients") { showClients = true }
                        Button("Presets") { showPresets = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTimer = true } label: {
                        Image(systemName: "timer")
                            .symbolEffect(.variableColor, isActive: timerState.isRunning)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showLogTime = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showLogTime) {
                LogTimeView()
            }
            .sheet(isPresented: $showTimer) {
                TimerSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showClients) {
                ClientListView()
            }
            .sheet(isPresented: $showPresets) {
                PresetsView()
            }
            .sheet(item: $entryToEdit) { entry in
                TimeEntryEditView(entry: entry)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteEntries(from entries: [TimeEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Week Summary Card

private struct WeekSummaryCard: View {
    let hours: Double
    let earnings: Decimal

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: String(format: "%.1f", hours),
                unit: "hrs",
                label: "This Week"
            )
            Divider().frame(height: 40)
            summaryItem(
                value: earnings.formatted(.currency(code: "USD")),
                unit: nil,
                label: "Earned"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func summaryItem(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Timer Card

struct ActiveTimerCard: View {
    @Environment(TimerState.self) private var timerState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Timer Running", systemImage: "record.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(.vertical, 4)
                    if let client = timerState.client {
                        Text(client.name)
                            .font(.subheadline.bold())
                    }
                    if let project = timerState.project {
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(timerState.elapsed.timerFormatted)
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.red)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Time Entry Row

private struct TimeEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Client + hours badge
            HStack(alignment: .center) {
                Text(entry.client?.name ?? "Uncategorized")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f hrs", entry.hours))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.indigo.opacity(0.12), in: Capsule())
            }

            // Project + earnings
            HStack(spacing: 10) {
                VStack(spacing: 0) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.indigo.opacity(0.7))
                }
                .frame(width: 12)

                if let project = entry.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No project")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(entry.earnings.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    TimeTrackingView()
        .environment(TimerState())
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self], inMemory: true)
}
