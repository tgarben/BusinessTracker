import SwiftUI
import SwiftData

struct TimeEntryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: TimeEntry
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    // Local state mirrors the entry so we can cancel cleanly
    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var date: Date = .now
    @State private var hours: Double = 0
    @State private var hourlyRate: Double = 0
    @State private var rateText: String = ""
    @State private var notes: String = ""

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? []).sorted { $0.name < $1.name }
    }

    private var earnings: Double { hours * hourlyRate }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client & Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("Uncategorized").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        if newClient?.persistentModelID != selectedProject?.client?.persistentModelID {
                            selectedProject = nil
                        }
                        if let newClient, selectedProject == nil {
                            hourlyRate = 0
                            rateText = ""
                        }
                    }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { project in
                                Text(project.name).tag(Optional(project))
                            }
                        }
                        .onChange(of: selectedProject) { _, newProject in
                            if let rate = newProject?.hourlyRate {
                                hourlyRate = rate
                                rateText = rate > 0 ? String(format: "%.2f", rate) : ""
                            }
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    LabeledContent("Hours") {
                        TextField("0.0", value: $hours, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Rate") {
                    LabeledContent("Hourly Rate") {
                        HStack(spacing: 2) {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $rateText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .onChange(of: rateText) { _, new in
                                    var s = new.filter { $0.isNumber || $0 == "." }
                                    if let dot = s.firstIndex(of: ".") {
                                        let frac = String(s[s.index(after: dot)...].filter(\.isNumber).prefix(2))
                                        s = String(s[..<dot]) + "." + frac
                                    }
                                    if s != new { rateText = s }
                                    hourlyRate = Double(s) ?? 0
                                }
                        }
                    }
                    if hours > 0 && hourlyRate > 0 {
                        LabeledContent("Total") {
                            Text(earnings.formatted(.currency(code: "USD")))
                                .font(.headline)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Add notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { loadFromEntry() }
        }
    }

    private func loadFromEntry() {
        selectedClient  = entry.client
        selectedProject = entry.project
        date            = entry.date
        hours           = entry.hours
        hourlyRate      = entry.hourlyRate
        rateText        = hourlyRate > 0 ? String(format: "%.2f", hourlyRate) : ""
        notes           = entry.notes
    }

    private func save() {
        entry.client      = selectedClient
        entry.project     = selectedProject
        entry.date        = date
        entry.hours       = hours
        entry.hourlyRate  = hourlyRate
        entry.notes       = notes
        dismiss()
    }
}
