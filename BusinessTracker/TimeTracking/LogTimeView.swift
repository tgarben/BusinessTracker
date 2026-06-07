import SwiftUI
import SwiftData

private enum EntryMode: String, CaseIterable {
    case duration = "Duration"
    case startEnd = "Start & End"
}

struct LogTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var hourlyRate: Decimal = 0
    @State private var notes: String = ""

    // Duration mode
    @State private var date: Date = .now
    @State private var hours: Double = 1.0

    // Start & End mode
    @State private var startTime: Date = Calendar.current.date(byAdding: .hour, value: -1, to: .now) ?? .now
    @State private var endTime: Date = .now

    @State private var entryMode: EntryMode = .duration

    // Prefill from a stopped timer
    var prefillHours: Double? = nil
    var prefillClient: Client? = nil
    var prefillProject: Project? = nil

    private var availableProjects: [Project] {
        selectedClient?.projects.sorted { $0.name < $1.name } ?? []
    }

    /// The resolved hours value regardless of mode
    private var resolvedHours: Double {
        switch entryMode {
        case .duration:
            return hours
        case .startEnd:
            let interval = endTime.timeIntervalSince(startTime)
            return max(0, interval / 3600)
        }
    }

    /// The resolved date (start of entry)
    private var resolvedDate: Date {
        entryMode == .startEnd ? startTime : date
    }

    private var earnings: Decimal { Decimal(resolvedHours) * hourlyRate }

    private var canSave: Bool {
        guard selectedClient != nil && resolvedHours > 0 else { return false }
        if entryMode == .startEnd { return endTime > startTime }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Client & Project
                Section("Client & Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("Select a client").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        selectedProject = nil
                        hourlyRate = newClient?.defaultHourlyRate ?? 0
                    }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { project in
                                Text(project.name).tag(Optional(project))
                            }
                        }
                    }
                }

                // Time entry — switches based on mode
                switch entryMode {
                case .duration:
                    Section("Time") {
                        Picker("Entry Mode", selection: $entryMode) {
                            ForEach(EntryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        LabeledContent("Hours Worked") {
                            TextField("0.0", value: $hours, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                    }

                case .startEnd:
                    Section("Time") {
                        Picker("Entry Mode", selection: $entryMode) {
                            ForEach(EntryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])

                        if endTime <= startTime {
                            Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            LabeledContent("Duration") {
                                Text(resolvedHours, format: .number.precision(.fractionLength(2)))
                                    .foregroundStyle(.secondary)
                                + Text(" hrs")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Rate & total
                Section("Rate") {
                    LabeledContent("Hourly Rate") {
                        TextField("0.00", value: $hourlyRate, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    if selectedClient != nil && resolvedHours > 0 {
                        LabeledContent("Total") {
                            Text(earnings.formatted(.currency(code: "USD")))
                                .font(.headline)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let c = prefillClient { selectedClient = c }
                if let p = prefillProject { selectedProject = p }
                if let h = prefillHours {
                    hours = h
                    // Also set startTime/endTime to match the prefilled hours
                    // so switching modes feels consistent
                    startTime = Calendar.current.date(byAdding: .second, value: -Int(h * 3600), to: .now) ?? .now
                    endTime = .now
                }
            }
        }
    }

    private func save() {
        let entry = TimeEntry(
            date: resolvedDate,
            client: selectedClient,
            project: selectedProject,
            hours: resolvedHours,
            hourlyRate: hourlyRate,
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    LogTimeView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self], inMemory: true)
}
