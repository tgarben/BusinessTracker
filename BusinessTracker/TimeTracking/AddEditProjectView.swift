import SwiftUI
import SwiftData

struct AddEditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var project: Project? // nil = add
    var client: Client?

    @State private var name: String = ""
    @State private var hourlyRate: Decimal = 0

    private var isEditing: Bool { project != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    TextField("Project name", text: $name)
                    LabeledContent("Hourly Rate") {
                        TextField("0.00", value: $hourlyRate, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                if let client {
                    Section {
                        LabeledContent("Client", value: client.name)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
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
