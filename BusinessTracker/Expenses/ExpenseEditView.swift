import SwiftUI
import SwiftData
import PhotosUI

struct ExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]

    let expense: Expense

    @State private var date: Date
    @State private var amountText: String
    @State private var category: String
    @State private var selectedClient: Client?
    @State private var notes: String
    @State private var receiptImages: [UIImage]

    @State private var newReceiptItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var previewImage: UIImage?

    init(expense: Expense) {
        self.expense = expense
        _date = State(initialValue: expense.date)
        _amountText = State(initialValue: String(format: "%.2f", expense.amount))
        _category = State(initialValue: expense.category)
        _selectedClient = State(initialValue: expense.client)
        _notes = State(initialValue: expense.notes)

        // Migrate legacy single-image field on first edit
        var images: [UIImage] = expense.receiptImagesData.compactMap { UIImage(data: $0) }
        if images.isEmpty, let legacyData = expense.receiptImageData,
           let legacyImage = UIImage(data: legacyData) {
            images = [legacyImage]
        }
        _receiptImages = State(initialValue: images)
    }

    private var canSave: Bool {
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .onChange(of: amountText) { _, new in
                                var s = new.filter { $0.isNumber || $0 == "." }
                                if let dot = s.firstIndex(of: ".") {
                                    let frac = String(s[s.index(after: dot)...].filter(\.isNumber).prefix(2))
                                    s = String(s[..<dot]) + "." + frac
                                }
                                if s != new { amountText = s }
                            }
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

                Section("Receipts") {
                    if !receiptImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(receiptImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: receiptImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture { previewImage = receiptImages[index] }

                                        Button {
                                            receiptImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.55))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 10)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    PhotosPicker(selection: $newReceiptItem, matching: .images) {
                        Label("Add from Library", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: newReceiptItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                receiptImages.append(image)
                                newReceiptItem = nil
                            }
                        }
                    }

                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
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
                    receiptImages.append(image)
                    showCamera = false
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(item: $previewImage) { image in
                ReceiptPreviewSheet(image: image)
            }
        }
    }

    private func save() {
        expense.date = date
        expense.amount = Double(amountText) ?? expense.amount
        expense.category = category
        expense.client = selectedClient
        expense.notes = notes
        expense.receiptImagesData = receiptImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        // Clear legacy field after migration
        if expense.receiptImageData != nil {
            expense.receiptImageData = nil
        }
        dismiss()
    }
}
