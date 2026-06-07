import SwiftUI
import SwiftData
import PhotosUI

struct ExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Client.name) private var clients: [Client]

    let expense: Expense

    @State private var date: Date
    @State private var amountText: String
    @State private var category: String
    @State private var selectedClient: Client?
    @State private var notes: String
    @State private var receiptImage: UIImage?

    @State private var receiptItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showReceiptPreview = false

    init(expense: Expense) {
        self.expense = expense
        _date = State(initialValue: expense.date)
        _amountText = State(initialValue: "\(expense.amount)")
        _category = State(initialValue: expense.category)
        _selectedClient = State(initialValue: expense.client)
        _notes = State(initialValue: expense.notes)
        if let data = expense.receiptImageData {
            _receiptImage = State(initialValue: UIImage(data: data))
        }
    }

    private var canSave: Bool {
        (Decimal(string: amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    LabeledContent("Amount") {
                        TextField("$0.00", text: $amountText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

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

                        Button { showCamera = true } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle("Edit Expense")
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
        expense.date = date
        expense.amount = Decimal(string: amountText) ?? expense.amount
        expense.category = category
        expense.client = selectedClient
        expense.notes = notes
        expense.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.8)
        dismiss()
    }
}
