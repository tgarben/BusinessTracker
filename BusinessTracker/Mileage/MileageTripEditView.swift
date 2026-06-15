import SwiftUI
import SwiftData

private enum MileageEditMode: String, CaseIterable {
    case manual  = "Manual"
    case address = "Address"
}

struct MileageTripEditView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: MileageTrip

    @State private var editMode: MileageEditMode = .manual
    @State private var date: Date
    @State private var purpose: String
    @State private var notes: String
    @State private var ratePerMile: Double

    // Manual mode
    @State private var manualStart: String
    @State private var manualEnd: String
    @State private var manualMiles: Double

    // Address mode
    @State private var fromResult: LocationResult?
    @State private var toResult: LocationResult?
    @State private var fromLabel: String = ""
    @State private var toLabel: String = ""
    @State private var fromAddress: String = ""
    @State private var toAddress: String = ""
    @State private var calculatedMiles: Double?
    @State private var isCalculating = false
    @State private var calculationError: String?
    @State private var isRoundTrip = false
    @State private var showFromSearch = false
    @State private var showToSearch = false

    init(trip: MileageTrip) {
        self.trip = trip
        _date = State(initialValue: trip.date)
        _purpose = State(initialValue: trip.purpose)
        _notes = State(initialValue: trip.notes)
        _ratePerMile = State(initialValue: MileageTrip.ratePerMile)
        _manualStart = State(initialValue: trip.startLocation)
        _manualEnd = State(initialValue: trip.endLocation)
        _manualMiles = State(initialValue: trip.miles)
    }

    private var oneWayMiles: Double {
        switch editMode {
        case .manual:  return manualMiles
        case .address: return calculatedMiles ?? 0
        }
    }

    private var totalMiles: Double { oneWayMiles * (isRoundTrip ? 2 : 1) }

    private var resolvedStart: String {
        editMode == .address ? fromLabel : manualStart
    }

    private var resolvedEnd: String {
        editMode == .address ? toLabel : manualEnd
    }

    private var reimbursement: Double { totalMiles * ratePerMile }

    private var canCalculate: Bool {
        fromResult != nil && toResult != nil && !isCalculating
    }

    private var canSave: Bool {
        totalMiles > 0 && !resolvedStart.isEmpty && !resolvedEnd.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Purpose", text: $purpose)
                    PurposeChipsRow(purpose: $purpose)
                }

                Section("Route") {
                    Picker("Entry Mode", selection: $editMode) {
                        ForEach(MileageEditMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: editMode) { _, _ in
                        calculatedMiles = nil
                        calculationError = nil
                    }

                    switch editMode {
                    case .manual:  manualFields
                    case .address: addressFields
                    }

                    if oneWayMiles > 0 && editMode == .address {
                        Toggle(isOn: $isRoundTrip) {
                            Label("Round Trip", systemImage: "arrow.triangle.2.circlepath")
                        }
                        if isRoundTrip {
                            LabeledContent("Each Way") {
                                Text("\(oneWayMiles.formatted(.number.precision(.fractionLength(2)))) mi")
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Total") {
                                Text("\(totalMiles.formatted(.number.precision(.fractionLength(2)))) mi")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Reimbursement") {
                    LabeledContent("Rate per Mile") {
                        TextField("0.000", value: $ratePerMile, format: .number.precision(.fractionLength(3)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    LabeledContent("Reimbursement") {
                        Text(reimbursement, format: .currency(code: "USD"))
                            .font(.headline)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
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
                AddressSearchView(title: "From") { result in
                    fromResult = result
                    fromLabel = labelFor(result)
                    fromAddress = fullAddressFor(result)
                    calculatedMiles = nil
                }
            }
            .sheet(isPresented: $showToSearch) {
                AddressSearchView(title: "To") { result in
                    toResult = result
                    toLabel = labelFor(result)
                    toAddress = fullAddressFor(result)
                    calculatedMiles = nil
                }
            }
        }
    }

    // MARK: - Manual fields

    @ViewBuilder
    private var manualFields: some View {
        TextField("Start location", text: $manualStart)
        TextField("End location", text: $manualEnd)
        LabeledContent("Miles") {
            TextField("0.0", value: $manualMiles, format: .number.precision(.fractionLength(2)))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }

    // MARK: - Address fields

    @ViewBuilder
    private var addressFields: some View {
        Button { showFromSearch = true } label: {
            LabeledContent("From") {
                Text(fromLabel.isEmpty ? "Search address…" : fromLabel)
                    .foregroundStyle(fromLabel.isEmpty ? .tertiary : .primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.primary)

        Button { showToSearch = true } label: {
            LabeledContent("To") {
                Text(toLabel.isEmpty ? "Search address…" : toLabel)
                    .foregroundStyle(toLabel.isEmpty ? .tertiary : .primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.primary)

        if let miles = calculatedMiles {
            LabeledContent("Distance") {
                Text("\(miles.formatted(.number.precision(.fractionLength(2)))) mi")
                    .foregroundStyle(.secondary)
            }
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

    // MARK: - Helpers

    private func labelFor(_ result: LocationResult) -> String {
        switch result {
        case .completion(let c): return shortAddress(c)
        case .coordinate(_, let label): return label
        }
    }

    private func fullAddressFor(_ result: LocationResult) -> String {
        switch result {
        case .completion(let c): return fullAddress(c)
        case .coordinate(_, let label): return label
        }
    }

    private func calculateMiles() async {
        guard let from = fromResult, let to = toResult else { return }
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
        trip.date = date
        trip.purpose = purpose.isEmpty ? "Business trip" : purpose
        trip.startLocation = resolvedStart
        trip.endLocation = resolvedEnd
        // Only refresh export addresses when re-picked in address mode (preserves
        // a previously-captured full address when just editing other fields).
        if editMode == .address {
            trip.startAddress = fromAddress
            trip.endAddress = toAddress
        }
        trip.miles = editMode == .address ? totalMiles : manualMiles
        trip.notes = notes
        dismiss()
    }
}
