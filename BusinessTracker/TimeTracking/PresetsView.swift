import SwiftUI
import SwiftData

struct PresetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimePreset.sortOrder) private var presets: [TimePreset]
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showAddPreset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Uncategorized is always built-in, shown for reference
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).font(.body)
                                let sub = subtitle(for: preset)
                                if !sub.isEmpty {
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deletePresets)
                        .onMove(perform: movePresets)
                    }
                } header: {
                    Text("Your Presets")
                } footer: {
                    Text("Presets let you save a time entry instantly after stopping the timer.")
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
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
                AddPresetView()
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

    private func subtitle(for preset: TimePreset) -> String {
        var parts: [String] = []
        if let client = preset.client { parts.append(client.name) }
        if let project = preset.project {
            parts.append(project.name)
            if project.hourlyRate > 0 {
                parts.append(project.hourlyRate.formatted(.currency(code: "USD")) + "/hr")
            }
        }
        return parts.joined(separator: " · ")
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

// MARK: - Add Preset

private struct AddPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \TimePreset.sortOrder) private var existingPresets: [TimePreset]

    @State private var name: String = ""
    @State private var selectedClient: Client?
    @State private var selectedProject: Project?

    private var availableProjects: [Project] {
        selectedClient?.projects.sorted { $0.name < $1.name } ?? []
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. Acme – Development", text: $name)
                }

                Section("Link to Client & Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                    .onChange(of: selectedClient) { _, _ in selectedProject = nil }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { project in
                                Text(project.name).tag(Optional(project))
                            }
                        }
                    }
                }

                if let project = selectedProject, project.hourlyRate > 0 {
                    Section {
                        LabeledContent("Rate", value: project.hourlyRate.formatted(.currency(code: "USD")) + "/hr")
                    }
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let preset = TimePreset(
            name: name.trimmingCharacters(in: .whitespaces),
            client: selectedClient,
            project: selectedProject,
            sortOrder: existingPresets.count
        )
        modelContext.insert(preset)
        dismiss()
    }
}
