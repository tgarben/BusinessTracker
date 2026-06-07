import SwiftUI
import MapKit
import SwiftData

private enum MileageEntryMode: String, CaseIterable {
    case address = "Address"
    case manual  = "Manual"
}

struct LogTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var entryMode: MileageEntryMode = .address
    @State private var date: Date = .now
    @State private var purpose: String = ""
    @State private var notes: String = ""
    @State private var ratePerMile: Double = MileageTrip.ratePerMile

    // Address mode
    @State private var fromCompletion: MKLocalSearchCompletion?
    @State private var toCompletion: MKLocalSearchCompletion?
    @State private var fromLabel: String = ""
    @State private var toLabel: String = ""
    @State private var calculatedMiles: Double?
    @State private var isCalculating = false
    @State private var calculationError: String?
    @State private var showFromSearch = false
    @State private var showToSearch = false

    // Manual mode
    @State private var manualStartLocation: String = ""
    @State private var manualEndLocation: String = ""
    @State private var manualMiles: Double = 0

    private var resolvedMiles: Double {
        entryMode == .address ? (calculatedMiles ?? 0) : manualMiles
    }

    private var resolvedStart: String {
        entryMode == .address ? fromLabel : manualStartLocation
    }

    private var resolvedEnd: String {
        entryMode == .address ? toLabel : manualEndLocation
    }

    private var reimbursement: Double { resolvedMiles * ratePerMile }

    private var canCalculate: Bool {
        fromCompletion != nil && toCompletion != nil && !isCalculating
    }

    private var canSave: Bool {
        resolvedMiles > 0 && !resolvedStart.isEmpty && !resolvedEnd.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Purpose (e.g. Client visit)", text: $purpose)
                }

                // Distance entry section with mode toggle at top
                Section("Distance") {
                    Picker("Entry Mode", selection: $entryMode) {
                        ForEach(MileageEntryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: entryMode) { _, _ in
                        calculatedMiles = nil
                        calculationError = nil
                    }

                    switch entryMode {
                    case .address:
                        addressFields

                    case .manual:
                        manualFields
                    }
                }

                // Rate & reimbursement
                Section("Reimbursement") {
                    LabeledContent("Rate per Mile") {
                        TextField("0.000", value: $ratePerMile, format: .number.precision(.fractionLength(3)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    if resolvedMiles > 0 {
                        LabeledContent("Miles") {
                            Text(resolvedMiles, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Reimbursement") {
                            Text(reimbursement, format: .currency(code: "USD"))
                                .font(.headline)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Trip")
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
            .sheet(isPresented: $showFromSearch) {
                AddressSearchView(title: "From") { completion in
                    fromCompletion = completion
                    fromLabel = [completion.title, completion.subtitle]
                        .filter { !$0.isEmpty }.joined(separator: ", ")
                    calculatedMiles = nil
                }
            }
            .sheet(isPresented: $showToSearch) {
                AddressSearchView(title: "To") { completion in
                    toCompletion = completion
                    toLabel = [completion.title, completion.subtitle]
                        .filter { !$0.isEmpty }.joined(separator: ", ")
                    calculatedMiles = nil
                }
            }
        }
    }

    // MARK: - Address fields

    @ViewBuilder
    private var addressFields: some View {
        // From
        Button {
            showFromSearch = true
        } label: {
            LabeledContent("From") {
                Text(fromLabel.isEmpty ? "Search address…" : fromLabel)
                    .foregroundStyle(fromLabel.isEmpty ? .tertiary : .primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.primary)

        // To
        Button {
            showToSearch = true
        } label: {
            LabeledContent("To") {
                Text(toLabel.isEmpty ? "Search address…" : toLabel)
                    .foregroundStyle(toLabel.isEmpty ? .tertiary : .primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.primary)

        // Calculate button / result
        if let miles = calculatedMiles {
            LabeledContent("Distance") {
                Text(miles, format: .number.precision(.fractionLength(2)))
                + Text(" mi")
            }
            .foregroundStyle(.secondary)
        } else if let error = calculationError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        Button {
            Task { await calculateMiles() }
        } label: {
            if isCalculating {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Calculating…")
                }
            } else {
                Label(
                    calculatedMiles == nil ? "Calculate Distance" : "Recalculate",
                    systemImage: "arrow.triangle.swap"
                )
            }
        }
        .disabled(!canCalculate)
    }

    // MARK: - Manual fields

    @ViewBuilder
    private var manualFields: some View {
        TextField("Start location", text: $manualStartLocation)
        TextField("End location", text: $manualEndLocation)
        LabeledContent("Miles") {
            TextField("0.0", value: $manualMiles, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }

    // MARK: - Actions

    private func calculateMiles() async {
        guard let from = fromCompletion, let to = toCompletion else { return }
        isCalculating = true
        calculationError = nil
        do {
            calculatedMiles = try await calculateDrivingMiles(from: from, to: to)
        } catch {
            calculationError = error.localizedDescription
        }
        isCalculating = false
    }

    private func save() {
        let trip = MileageTrip(
            date: date,
            startLocation: resolvedStart,
            endLocation: resolvedEnd,
            miles: resolvedMiles,
            purpose: purpose.isEmpty ? "Business trip" : purpose,
            notes: notes
        )
        modelContext.insert(trip)
        dismiss()
    }
}

#Preview {
    LogTripView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
