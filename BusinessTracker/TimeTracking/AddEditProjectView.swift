import SwiftUI
import SwiftData

struct AddEditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var project: Project? // nil = add
    var client: Client?

    @State private var name: String = ""
    @State private var hourlyRate: Double = 0
    @State private var rateText: String = ""

    private var isEditing: Bool { project != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    TextField("Project name", text: $name)
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
                }
//                if let client {
//                    Section {
//                        LabeledContent("Client", value: client.name)
//                    }
//                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
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
            .onAppear {
                if let project {
                    name = project.name
                    hourlyRate = project.hourlyRate
                    rateText = hourlyRate > 0 ? String(format: "%.2f", hourlyRate) : ""
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let project {
            project.name = trimmed
            project.hourlyRate = hourlyRate
        } else {
            modelContext.insert(Project(name: trimmed, hourlyRate: hourlyRate, client: client))
        }
        dismiss()
    }
}
