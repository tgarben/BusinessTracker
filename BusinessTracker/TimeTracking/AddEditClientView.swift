import SwiftUI
import SwiftData

struct AddEditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var client: Client? // nil = add, non-nil = edit

    @State private var name: String = ""
    @State private var hourlyRate: Decimal = 0
    @State private var projectToEdit: Project?
    @State private var showAddProject = false

    private var isEditing: Bool { client != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Info") {
                    TextField("Client name", text: $name)
                    LabeledContent("Default Rate") {
                        TextField("0.00", value: $hourlyRate, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }

                if let client {
                    Section {
                        ForEach(client.projects.sorted { $0.name < $1.name }) { project in
                            HStack {
                                Text(project.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { projectToEdit = project }
                        }
                        .onDelete { offsets in
                            let sorted = client.projects.sorted { $0.name < $1.name }
                            for i in offsets { modelContext.delete(sorted[i]) }
                        }

                        Button {
                            showAddProject = true
                        } label: {
                            Label("Add Project", systemImage: "plus")
                        }
                    } header: {
                        Text("Projects")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Client" : "New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Done" : "Add") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let client {
                    name = client.name
                    hourlyRate = client.defaultHourlyRate
                }
            }
            .sheet(isPresented: $showAddProject) {
                if let client {
                    AddEditProjectView(client: client)
                }
            }
            .sheet(item: $projectToEdit) { project in
                AddEditProjectView(project: project, client: project.client)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let client {
            client.name = trimmed
            client.defaultHourlyRate = hourlyRate
        } else {
            let newClient = Client(name: trimmed, defaultHourlyRate: hourlyRate)
            modelContext.insert(newClient)
        }
        dismiss()
    }
}
