import SwiftUI
import SwiftData

struct MileageView: View {
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil }, sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]
    @Query(filter: #Predicate<MileageTrip> { $0.deletedDate == nil && $0.isAutoDetected && $0.needsReview },
           sort: \MileageTrip.date, order: .reverse) private var reviewTrips: [MileageTrip]
    @Environment(\.modelContext) private var modelContext

    @State private var showLogTrip = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var editingTrip: MileageTrip?
    @State private var pendingDelete: ([MileageTrip], IndexSet)?

    /// Trips shown in the normal day-grouped list — auto-detected drives awaiting
    /// review live in their own section until confirmed.
    private var listedTrips: [MileageTrip] { trips.filter { !$0.needsReview } }

    private var monthTrips: [MileageTrip] {
        let start = Calendar.current.startOfMonth(for: .now)
        return trips.filter { $0.date >= start }
    }

    private var monthMiles: Double        { monthTrips.reduce(0) { $0 + $1.miles } }
    private var monthReimbursement: Double { monthTrips.reduce(0) { $0 + $1.reimbursementAmount } }

    var body: some View {
        NavigationStack {
            List {
                // Live tracked trip — pinned at top while recording
                if TripTracker.shared.isTracking {
                    Section {
                        TripInProgressCard(onStop: { trip in if let trip { editingTrip = trip } })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if !trips.isEmpty {
                    Section {
                        MileageSummaryCard(
                            miles: monthMiles,
                            reimbursement: monthReimbursement,
                            label: "\(Date.now.formatted(.dateTime.month(.wide))) Miles"
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                // Auto-detected drives awaiting review (Auto-Mileage)
                if !reviewTrips.isEmpty {
                    Section {
                        ForEach(reviewTrips) { trip in
                            VStack(alignment: .leading, spacing: 10) {
                                TripRow(trip: trip)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTrip = trip }
                                HStack(spacing: 10) {
                                    Button { markReviewed(trip) } label: {
                                        Label("Confirm", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .background(.green.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.borderless)

                                    Button { editingTrip = trip } label: {
                                        Label("Categorize", systemImage: "tag.fill")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .background(.blue.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.borderless)

                                    Button(role: .destructive) { trip.deletedDate = .now } label: {
                                        Image(systemName: "trash")
                                            .font(.caption.weight(.semibold))
                                            .padding(.vertical, 7)
                                            .padding(.horizontal, 14)
                                            .background(.red.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Label("Drives to Review", systemImage: "car.circle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Auto-detected drives. Confirm to keep, Categorize to set a purpose, or delete.")
                    }
                }

                if !listedTrips.isEmpty {
                    let grouped = Dictionary(grouping: listedTrips) {
                        Calendar.current.startOfDay(for: $0.date)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)

                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(day, style: .date)) {
                            ForEach(grouped[day] ?? []) { trip in
                                TripRow(trip: trip)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTrip = trip }
                            }
                            .onDelete { offsets in
                                pendingDelete = (grouped[day] ?? [], offsets)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if trips.isEmpty && !TripTracker.shared.isTracking {
                    ContentUnavailableView(
                        "No Trips Logged",
                        systemImage: "car",
                        description: Text("Tap the play button to track a drive live, or + to log one manually.")
                    )
                }
            }
            .navigationTitle("Mileage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        ProfileToolbarLabel()
                    }
                    .accessibilityLabel("Profile & Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("History") { showHistory = true }
                        .disabled(trips.isEmpty)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !TripTracker.shared.isTracking {
                    VStack(spacing: 14) {
                        // Start a live-tracked trip
                        Button { TripTracker.shared.startTrip() } label: {
                            Image(systemName: "location.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 55, height: 55)
                                .background(.green, in: Circle())
                                .shadow(color: .green.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .accessibilityLabel("Start Tracked Trip")
                        // Manual entry
                        Button { showLogTrip = true } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 55, height: 55)
                                .background(.blue, in: Circle())
                                .shadow(color: .blue.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .accessibilityLabel("Log Trip Manually")
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showLogTrip) {
                LogTripView()
            }
            .sheet(isPresented: $showHistory) {
                MileageHistoryView()
            }
            .sheet(item: $editingTrip) { trip in
                MileageTripEditView(trip: trip)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .confirmationDialog("Delete Trip?", isPresented: Binding(
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

    private func deleteTrips(from trips: [MileageTrip], at offsets: IndexSet) {
        for index in offsets { trips[index].deletedDate = .now }
    }

    /// Clears the needs-review flag so an auto-detected drive joins the normal list.
    private func markReviewed(_ trip: MileageTrip) {
        trip.needsReview = false
    }
}

// MARK: - Shared summary card (used by MileageView + MileageHistoryView)

struct MileageSummaryCard: View {
    let miles: Double
    let reimbursement: Double
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(value: String(format: "%.1f", miles), unit: "mi", label: label)
            Divider().frame(height: 40)
            summaryItem(value: reimbursement.asCurrency, unit: nil, label: "Reimbursement")
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
                Text(value).font(.title2.bold())
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared trip row (used by MileageView + MileageMonthDetailView)

// MARK: - Live tracked-trip card

struct TripInProgressCard: View {
    /// Called when the user stops — receives the saved trip so the parent can open its editor.
    var onStop: (MileageTrip?) -> Void

    private var tracker: TripTracker { TripTracker.shared }
    private var accent: Color { tracker.isPaused ? .orange : .green }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(tracker.isPaused ? "Trip Paused" : "Tracking Trip",
                          systemImage: tracker.isPaused ? "pause.circle" : "location.fill")
                        .font(.caption.bold())
                        .foregroundStyle(accent)
                    Text(String(format: "%.1f mi", tracker.miles))
                        .font(.title2.monospacedDigit().bold())
                    Text(tracker.elapsed.timerFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if tracker.isPaused { tracker.resume() } else { tracker.pause() }
                } label: {
                    Image(systemName: tracker.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title)
                        .foregroundStyle(tracker.isPaused ? .green : .orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tracker.isPaused ? "Resume Trip" : "Pause Trip")

                Button { onStop(tracker.stopTrip()) } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop & Save Trip")
            }
            .padding()
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct TripRow: View {
    let trip: MileageTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Purpose + miles badge
            HStack(alignment: .center) {
                Text(trip.purpose.isEmpty ? "Uncategorized" : trip.purpose)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trip.purpose.isEmpty ? .secondary : .primary)
                if trip.isAutoDetected {
                    Text("AUTO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.12), in: Capsule())
                }
                Spacer()
                Text(String(format: "%.1f mi", trip.miles))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.12), in: Capsule())
            }

            // Route visualization
            HStack(spacing: 10) {
                // Icon column
                VStack(spacing: 0) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 1.5, height: 14)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                // Labels column
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.startLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !trip.waypoints.isEmpty {
                        Text("via \(trip.waypoints.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(trip.endLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(trip.reimbursementAmount.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    MileageView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
