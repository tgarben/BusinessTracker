import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showAddClient = false
    @State private var clientToEdit: Client?

    var body: some View {
        NavigationStack {
            List {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add your first client.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(clients) { client in
                        ClientRow(client: client)
                            .contentShape(Rectangle())
                            .onTapGesture { clientToEdit = client }
                    }
                    .onDelete(perform: deleteClients)
                }
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddClient = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClient) {
                AddEditClientView()
            }
            .sheet(item: $clientToEdit) { client in
                AddEditClientView(client: client)
            }
        }
    }

    private func deleteClients(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(clients[index])
        }
    }
}

// MARK: - Client Row

private struct ClientRow: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(client.name)
                    .font(.headline)
                Spacer()
                Text(client.defaultHourlyRate.formatted(.currency(code: "USD")) + "/hr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            let count = client.projects.count
            if count > 0 {
                Text("\(count) project\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
