import SwiftUI
import SwiftData

struct TimeTrackingView: View {
    @Environment(TimerState.self) private var timerState
    @Query(filter: #Predicate<TimeEntry> { $0.deletedDate == nil }, sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]

    @State private var showLogTime = false
    @State private var showTimer = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var entryToEdit: TimeEntry?
    @State private var pendingDelete: ([TimeEntry], IndexSet)?

    // Week summary
    private var weekEntries: [TimeEntry] {
        let start = Calendar.current.startOfWeek(for: .now)
        return entries.filter { $0.date >= start }
    }

    private var weekHours: Double { weekEntries.reduce(0) { $0 + $1.hours } }
    private var weekEarnings: Double  { weekEntries.reduce(0) { $0 + $1.earnings } }

    var body: some View {
        NavigationStack {
            List {
                // Week summary card
                if !entries.isEmpty {
                    Section {
                        WeekSummaryCard(hours: weekHours, earnings: weekEarnings)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                // Active timer card (running or paused)
                if timerState.isActive {
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
                                pendingDelete = (grouped[day] ?? [], indexSet)
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
                        Image(systemName: "person.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("History") { showHistory = true }
                        .disabled(entries.isEmpty)
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
            }
            .sheet(item: $entryToEdit) { entry in
                TimeEntryEditView(entry: entry)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                TimeHistoryView()
            }
            .overlay(alignment: .bottomTrailing) {
                if !timerState.isActive {
                    Button { showTimer = true } label: {
                        Image(systemName: "play.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(.indigo, in: Circle())
                            .shadow(color: .indigo.opacity(0.35), radius: 10, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: timerState.isActive)
            .confirmationDialog("Delete Time Entry?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let (items, offsets) = pendingDelete {
                        for index in offsets { items[index].deletedDate = .now }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("You can restore this from Recently Deleted for 30 days.")
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteEntries(from entries: [TimeEntry], at offsets: IndexSet) {
        for index in offsets { entries[index].deletedDate = .now }
    }
}

// MARK: - Week Summary Card

private struct WeekSummaryCard: View {
    let hours: Double
    let earnings: Double

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: String(format: "%.1f", hours),
                unit: "hrs",
                label: "This Week"
            )
            Divider().frame(height: 40)
            summaryItem(
                value: earnings.asCurrency,
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

    private var accent: Color { timerState.isPaused ? .orange : .red }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(timerState.isPaused ? "Paused" : "Timer Running",
                          systemImage: timerState.isPaused ? "pause.circle" : "record.circle")
                        .font(.caption.bold())
                        .foregroundStyle(accent)
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
                    .foregroundStyle(accent)
                // Inline pause / resume (the card itself stays tappable to open the sheet)
                Button {
                    if timerState.isRunning { timerState.pause() } else { timerState.resume() }
                } label: {
                    Image(systemName: timerState.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(timerState.isRunning ? .orange : .green)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Time Entry Row (shared with TimeMonthDetailView)

struct TimeEntryRow: View {
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

                Text(entry.earnings.asCurrency)
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
