import SwiftUI

/// User-managed quick-fill labels for a trip's purpose. Stored as a comma-separated
/// string in `@AppStorage("mileage_purposePresets")` (mirrors the income-source chip pattern).
enum MileagePurposePresets {
    static let key = "mileage_purposePresets"
    static let defaultValue = "Client Visit,Office,Airport,Errand,Medical"

    static func list(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func serialize(_ items: [String]) -> String {
        items.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
}

// MARK: - Chip row (used in LogTripView / MileageTripEditView)

struct PurposeChipsRow: View {
    @AppStorage(MileagePurposePresets.key) private var raw = MileagePurposePresets.defaultValue
    @Binding var purpose: String

    var body: some View {
        let items = MileagePurposePresets.list(from: raw)
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        let selected = purpose == item
                        Button { purpose = item } label: {
                            Text(item)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected ? Color.blue.opacity(0.18) : Color(.systemGray6), in: Capsule())
                                .foregroundStyle(selected ? .blue : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }
}

// MARK: - Settings editor

struct PurposePresetsEditor: View {
    @AppStorage(MileagePurposePresets.key) private var raw = MileagePurposePresets.defaultValue
    @State private var newPurpose = ""
    @FocusState private var addFocused: Bool

    // Tap-to-edit state
    @State private var editingIndex: Int?
    @State private var editingText = ""

    private var items: [String] { MileagePurposePresets.list(from: raw) }

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    Text("No categories yet. Add one below.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button {
                            editingIndex = index
                            editingText = item
                        } label: {
                            HStack {
                                Text(item).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var current = items
                        current.remove(atOffsets: offsets)
                        raw = MileagePurposePresets.serialize(current)
                    }
                    .onMove { source, dest in
                        var current = items
                        current.move(fromOffsets: source, toOffset: dest)
                        raw = MileagePurposePresets.serialize(current)
                    }
                }
            } header: {
                Text("Trip Categories")
            } footer: {
                Text("These appear as quick-fill chips when logging a trip. Tap a category to rename it, or swipe to delete.")
            }

            Section {
                HStack {
                    TextField("New category", text: $newPurpose)
                        .focused($addFocused)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newPurpose.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Trip Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .alert("Rename Category", isPresented: Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            TextField("Category", text: $editingText)
            Button("Save", action: commitEdit)
            Button("Cancel", role: .cancel) { editingIndex = nil }
        }
    }

    private func add() {
        let trimmed = newPurpose.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = items
        guard !current.contains(trimmed) else { newPurpose = ""; return }
        current.append(trimmed)
        raw = MileagePurposePresets.serialize(current)
        newPurpose = ""
        addFocused = false
    }

    private func commitEdit() {
        guard let index = editingIndex else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        var current = items
        guard index < current.count, !trimmed.isEmpty else { editingIndex = nil; return }
        // Ignore a rename that collides with a different existing category.
        if let dup = current.firstIndex(of: trimmed), dup != index {
            editingIndex = nil
            return
        }
        current[index] = trimmed
        raw = MileagePurposePresets.serialize(current)
        editingIndex = nil
    }
}
