import SwiftUI
import SwiftData

struct MileagePresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MileagePreset.sortOrder) private var presets: [MileagePreset]

    @State private var showAdd = false
    @State private var presetToEdit: MileagePreset?

    var body: some View {
        List {
            if presets.isEmpty {
                Text("No mileage presets yet. Tap + to save a route you drive often.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(presets) { preset in
                    Button {
                        presetToEdit = preset
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name).font(.body).foregroundStyle(.primary)
                            Text("\(preset.startLocation) → \(preset.endLocation)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if !preset.purpose.isEmpty {
                                Text(preset.purpose).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(presets[i]) }
                }
                .onMove { source, dest in
                    var reordered = presets
                    reordered.move(fromOffsets: source, toOffset: dest)
                    for (i, p) in reordered.enumerated() { p.sortOrder = i }
                }
            }
        }
        .navigationTitle("Mileage Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showAdd) { AddEditMileagePresetView() }
        .sheet(item: $presetToEdit) { AddEditMileagePresetView(preset: $0) }
    }
}

struct AddEditMileagePresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MileagePreset.sortOrder) private var existing: [MileagePreset]

    var preset: MileagePreset?

    @State private var name = ""
    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var purpose = ""
    @State private var notes = ""

    private var isEditing: Bool { preset != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. Home → Main Office", text: $name)
                }
                Section("Route") {
                    SearchableAddressRow(placeholder: "Start Location", text: $startLocation)
                    SearchableAddressRow(placeholder: "End Location", text: $endLocation)
                }
                Section("Defaults") {
                    TextField("Category", text: $purpose)
                    PurposeChipsRow(purpose: $purpose)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let preset else { return }
        name = preset.name
        startLocation = preset.startLocation
        endLocation = preset.endLocation
        purpose = preset.purpose
        notes = preset.notes
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let preset {
            preset.name = trimmed
            preset.startLocation = startLocation
            preset.endLocation = endLocation
            preset.purpose = purpose
            preset.notes = notes
        } else {
            modelContext.insert(MileagePreset(
                name: trimmed, startLocation: startLocation, endLocation: endLocation,
                purpose: purpose, notes: notes, sortOrder: existing.count
            ))
        }
        dismiss()
    }
}

// MARK: - Single-line searchable address field

/// An editable text field with a 🔍 button that opens the shared MapKit
/// autocomplete (`AddressSearchView`) and fills the field with the chosen
/// address. Used for mileage-preset endpoints, which are later geocoded when the
/// preset is applied in `LogTripView`.
struct SearchableAddressRow: View {
    let placeholder: String
    @Binding var text: String
    @State private var showSearch = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...2)
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showSearch) {
            AddressSearchView(title: placeholder) { result in
                switch result {
                case .completion(let completion): text = fullAddress(completion)
                case .coordinate(_, let label):   text = label
                }
            }
        }
    }
}
