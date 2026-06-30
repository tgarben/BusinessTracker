import SwiftUI
import SwiftData
import PhotosUI

struct AddEditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingClient: Client?

    @State private var workingClient: Client?
    @State private var isNewClient = false
    @State private var name: String = ""
    @State private var companyName: String = ""
    @State private var billingAddress: String = ""
    @State private var billingAddress2: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var projectToEdit: Project?
    @State private var showAddProject = false
    @State private var didSave = false

    private var isEditing: Bool { existingClient != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Photo
                Section {
                    VStack(spacing: 12) {
                        ClientAvatar(photoData: photoData, name: name.isEmpty ? "?" : name, size: 80)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(photoData == nil ? "Add Photo" : "Change Photo")
                                .font(.subheadline)
                                .foregroundStyle(.teal)
                        }
                        .onChange(of: photoItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }

                        if photoData != nil {
                            Button("Remove Photo", role: .destructive) {
                                photoData = nil
                                photoItem = nil
                            }
                            .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // MARK: Client info
                Section("Client Info") {
                    TextField("Client name", text: $name)
                }

                // MARK: Billing details (for invoices)
                Section {
                    TextField("Company name (optional)", text: $companyName)
                    AddressEntryField(label: "", line1: $billingAddress, line2: $billingAddress2)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .onChange(of: phone) { _, newValue in
                            let formatted = formatPhoneNumber(newValue)
                            if formatted != newValue { phone = formatted }
                        }
                } header: {
                    Text("Billing Details")
                } footer: {
                    Text("Shown as the \"bill to\" details on this client's invoices.")
                }

                // MARK: Projects
                if let client = workingClient {
                    Section {
                        ForEach((client.projects ?? []).sorted { $0.name < $1.name }) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                    Text(project.hourlyRate.formatted(AppCurrency.style) + "/hr")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { projectToEdit = project }
                        }
                        .onDelete { offsets in
                            let sorted = (client.projects ?? []).sorted { $0.name < $1.name }
                            for i in offsets { modelContext.delete(sorted[i]) }
                        }

                        Button { showAddProject = true } label: {
                            Label("Add Project", systemImage: "plus")
                        }
                    } header: {
                        Text("Projects")
                    } footer: {
                        Text("Each project carries its own hourly rate.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Client" : "New Client")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Done" : "Add") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { setup() }
            // Covers ALL dismissal paths (Cancel button AND swipe-to-dismiss) — discards
            // the eager-inserted client if it was never saved, so no empty client lingers.
            .onDisappear { discardIfUnsaved() }
            .sheet(isPresented: $showAddProject) {
                if let client = workingClient {
                    AddEditProjectView(client: client)
                        .presentationDetents([.medium])
                }
            }
            .sheet(item: $projectToEdit) { project in
                AddEditProjectView(project: project, client: project.client)
                    .presentationDetents([.medium])
            }
        }
    }

    private func setup() {
        if let existing = existingClient {
            workingClient = existing
            name = existing.name
            photoData = existing.photoData
            companyName = existing.companyName
            billingAddress = existing.billingAddress
            billingAddress2 = existing.billingAddress2
            email = existing.email
            phone = existing.phone
        } else {
            let newClient = Client(name: "")
            modelContext.insert(newClient)
            workingClient = newClient
            isNewClient = true
        }
    }

    private func cancel() {
        dismiss()   // cleanup handled in discardIfUnsaved() via onDisappear
    }

    /// Discards the eager-inserted client if the user left without saving (Cancel or
    /// swipe-to-dismiss). `workingClient = nil` guards against running twice.
    private func discardIfUnsaved() {
        if isNewClient, !didSave, let client = workingClient {
            modelContext.delete(client)
            workingClient = nil
        }
    }

    private func save() {
        guard let client = workingClient else { return }
        client.name = name.trimmingCharacters(in: .whitespaces)
        client.photoData = photoData
        client.companyName = companyName.trimmingCharacters(in: .whitespaces)
        client.billingAddress = billingAddress.trimmingCharacters(in: .whitespaces)
        client.billingAddress2 = billingAddress2.trimmingCharacters(in: .whitespaces)
        client.email = email.trimmingCharacters(in: .whitespaces)
        client.phone = phone.trimmingCharacters(in: .whitespaces)
        didSave = true
        dismiss()
    }
}
