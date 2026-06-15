import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]
    @Query(sort: \ExpensePreset.sortOrder) private var presets: [ExpensePreset]

    @State private var date: Date = .now
    @State private var amountText: String = ""
    @State private var category: String = Expense.categories[0]
    @State private var selectedClient: Client?
    @State private var notes: String = ""

    @State private var receiptImages: [UIImage] = []
    @State private var newReceiptItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var previewImage: UIImage?

    private var canSave: Bool {
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if !presets.isEmpty {
                    Section("Presets") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets) { preset in
                                    Button { applyPreset(preset) } label: {
                                        Label(preset.name, systemImage: Expense.categoryIcon(preset.category))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

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

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
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

    private func applyPreset(_ preset: ExpensePreset) {
        category = preset.category.isEmpty ? category : preset.category
        notes = preset.notes
        if let amount = preset.amount {
            amountText = String(format: "%.2f", amount)
        }
    }

    private func save() {
        let parsedAmount = Double(amountText) ?? 0
        let expense = Expense(
            date: date,
            amount: parsedAmount,
            category: category,
            notes: notes,
            client: selectedClient
        )
        expense.receiptImagesData = receiptImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        modelContext.insert(expense)
        dismiss()
    }
}

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}
