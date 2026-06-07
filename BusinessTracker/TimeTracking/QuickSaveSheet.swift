import SwiftUI
import SwiftData

/// The low-friction sheet shown after stopping the timer.
/// One tap on a preset saves immediately. "Log with details" opens the full form.
struct QuickSaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimePreset.sortOrder) private var presets: [TimePreset]

    let hours: Double
    let onOpenFullForm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Elapsed time header
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f hrs", hours))
                                .font(.title.bold())
                            Text("logged")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                // Uncategorized — always first
                Section {
                    Button {
                        saveEntry(client: nil, project: nil, hourlyRate: 0)
                    } label: {
                        PresetRow(
                            name: "Uncategorized",
                            subtitle: "Save without a client or project",
                            systemImage: "tray"
                        )
                    }
                }

                // User presets
                if !presets.isEmpty {
                    Section("Presets") {
                        ForEach(presets) { preset in
                            Button {
                                saveEntry(
                                    client: preset.client,
                                    project: preset.project,
                                    hourlyRate: preset.project?.hourlyRate ?? 0
                                )
                            } label: {
                                PresetRow(
                                    name: preset.name,
                                    subtitle: subtitle(for: preset),
                                    systemImage: "bolt"
                                )
                            }
                        }
                    }
                }

                // Escape hatch
                Section {
                    Button {
                        dismiss()
                        onOpenFullForm()
                    } label: {
                        Label("Log with details…", systemImage: "pencil")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Save Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

    private func saveEntry(client: Client?, project: Project?, hourlyRate: Decimal) {
        let entry = TimeEntry(
            date: .now,
            client: client,
            project: project,
            hours: hours,
            hourlyRate: hourlyRate
        )
        modelContext.insert(entry)
        dismiss()
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let name: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
//                .foregroundStyle(.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(.primary)
                    .font(.body)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
