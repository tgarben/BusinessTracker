import SwiftUI
import SwiftData

struct PresetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimePreset.sortOrder) private var presets: [TimePreset]
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    @State private var showAddPreset = false
    @State private var presetToEdit: TimePreset?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "tray")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uncategorized")
                                .font(.body)
                            Text("Built-in · always available")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Built-in")
                }

                Section {
                    if presets.isEmpty {
                        Text("No presets yet. Tap + to create one.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(presets) { preset in
                            PresetListRow(preset: preset)
                                .contentShape(Rectangle())
                                .onTapGesture { presetToEdit = preset }
                        }
                        .onDelete(perform: deletePresets)
                        .onMove(perform: movePresets)
                    }
                } header: {
                    Text("Your Presets")
                } footer: {
                    Text("Tap a preset to edit it. Drag to reorder.")
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPreset = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(clients.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddPreset) {
                AddEditPresetView()
            }
            .sheet(item: $presetToEdit) { preset in
                AddEditPresetView(preset: preset)
            }
            .overlay {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients Yet",
                        systemImage: "person.2",
                        description: Text("Add a client and project first, then create presets.")
                    )
                }
            }
        }
    }

    private func deletePresets(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(presets[i]) }
    }

    private func movePresets(from source: IndexSet, to destination: Int) {
        var reordered = presets
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, preset) in reordered.enumerated() {
            preset.sortOrder = index
        }
    }
}

// MARK: - Preset list row

private struct PresetListRow: View {
    let preset: TimePreset

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(preset.name).font(.body)

            HStack(spacing: 4) {
                if let client = preset.client {
                    Text(client.name).foregroundStyle(.secondary)
                }
                if let project = preset.project {
                    Text("·").foregroundStyle(.tertiary)
                    Text(project.name).foregroundStyle(.secondary)
                }
                if preset.effectiveRate > 0 {
                    Text("·").foregroundStyle(.tertiary)
                    Text(preset.effectiveRate.formatted(.currency(code: "USD")) + "/hr")
                        .foregroundStyle(preset.hourlyRateOverride != nil ? .orange : .secondary)
                }
            }
            .font(.caption)

            if !preset.notesTemplate.isEmpty {
                Text("\"\(preset.notesTemplate)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add / Edit preset

struct AddEditPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]
    @Query(sort: \TimePreset.sortOrder) private var existingPresets: [TimePreset]

    var preset: TimePreset? // nil = add, non-nil = edit

    @State private var name: String = ""
    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var useRateOverride = false
    @State private var rateOverride: Double = 0
    @State private var rateOverrideText: String = ""
    @State private var notesTemplate: String = ""

    private var isEditing: Bool { preset != nil }

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? []).sorted { $0.name < $1.name }
    }

    private var projectRate: Double { selectedProject?.hourlyRate ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. Acme – Development", text: $name)
                }

                Section("Client & Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        if selectedProject?.client?.persistentModelID != newClient?.persistentModelID {
                            selectedProject = nil
                        }
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

                Section {
                    Toggle("Override Hourly Rate", isOn: $useRateOverride)

                    if useRateOverride {
                        LabeledContent("Rate") {
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0.00", text: $rateOverrideText)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: rateOverrideText) { _, new in
                                        var s = new.filter { $0.isNumber || $0 == "." }
                                        if let dot = s.firstIndex(of: ".") {
                                            let frac = String(s[s.index(after: dot)...].filter(\.isNumber).prefix(2))
                                            s = String(s[..<dot]) + "." + frac
                                        }
                                        if s != new { rateOverrideText = s }
                                        rateOverride = Double(s) ?? 0
                                    }
                            }
                        }
                    } else if projectRate > 0 {
                        LabeledContent("Rate from project") {
                            Text(projectRate.formatted(.currency(code: "USD")) + "/hr")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Hourly Rate")
                } footer: {
                    Text(useRateOverride
                         ? "This rate will override the project's default when using this preset."
                         : "Uses the project's default rate. Enable override for a custom rate (e.g. rush billing).")
                }

                Section {
                    TextField("e.g. Weekly standup, Code review…", text: $notesTemplate, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes Template")
                } footer: {
                    Text("Pre-fills the notes field when this preset is used. Still editable before saving.")
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { loadFromPreset() }
        }
    }

    private func loadFromPreset() {
        guard let preset else { return }
        name             = preset.name
        selectedClient   = preset.client
        selectedProject  = preset.project
        notesTemplate    = preset.notesTemplate
        if let override = preset.hourlyRateOverride {
            useRateOverride    = true
            rateOverride       = override
            rateOverrideText   = override > 0 ? String(format: "%.2f", override) : ""
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let override: Double? = useRateOverride ? rateOverride : nil

        if let preset {
            preset.name                = trimmed
            preset.client              = selectedClient
            preset.project             = selectedProject
            preset.hourlyRateOverride  = override
            preset.notesTemplate       = notesTemplate
        } else {
            let newPreset = TimePreset(
                name: trimmed,
                client: selectedClient,
                project: selectedProject,
                sortOrder: existingPresets.count,
                hourlyRateOverride: override,
                notesTemplate: notesTemplate
            )
            modelContext.insert(newPreset)
        }
        dismiss()
    }
}
