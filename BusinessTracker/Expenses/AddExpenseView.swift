import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var date: Date = .now
    @State private var amount: Decimal = 0
    @State private var amountText: String = ""
    @State private var category: String = Expense.categories[0]
    @State private var selectedClient: Client?
    @State private var notes: String = ""

    // Receipt photo
    @State private var receiptItem: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var showCamera = false
    @State private var showReceiptPreview = false

    private var canSave: Bool {
        (Decimal(string: amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    // Amount
                    LabeledContent("Amount") {
                        TextField("$0.00", text: $amountText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    // Category
                    Picker("Category", selection: $category) {
                        ForEach(Expense.categories, id: \.self) { cat in
                            Label(cat, systemImage: Expense.categoryIcon(cat)).tag(cat)
                        }
                    }
                }

                Section("Client (Optional)") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Receipt") {
                    if let image = receiptImage {
                        // Preview thumbnail + remove
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { showReceiptPreview = true }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Receipt attached")
                                    .font(.subheadline)
                                Button("Remove", role: .destructive) {
                                    receiptImage = nil
                                    receiptItem = nil
                                }
                                .font(.caption)
                            }
                            .padding(.leading, 4)
                        }
                    } else {
                        // Attach options
                        PhotosPicker(selection: $receiptItem, matching: .images) {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                        .onChange(of: receiptItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    receiptImage = image
                                }
                            }
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    receiptImage = image
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceiptPreview) {
                if let image = receiptImage {
                    ReceiptPreviewSheet(image: image)
                }
            }
        }
    }

    private func save() {
        let parsedAmount = Decimal(string: amountText) ?? 0
        let expense = Expense(
            date: date,
            amount: parsedAmount,
            category: category,
            notes: notes,
            client: selectedClient
        )
        if let image = receiptImage {
            expense.receiptImageData = image.jpegData(compressionQuality: 0.8)
        }
        modelContext.insert(expense)
        dismiss()
    }
}
