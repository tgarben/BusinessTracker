import SwiftUI
import MapKit
import CoreLocation
import SwiftData

private enum MileageEntryMode: String, CaseIterable {
    case address = "Address"
    case manual  = "Manual"
}

/// An intermediate stop on a multi-stop route.
struct TripStop: Identifiable {
    let id = UUID()
    var result: LocationResult?
    var label: String = ""
}

/// Identifies which intermediate stop's address search sheet is open.
private struct StopSearch: Identifiable {
    let id: UUID
}

struct LogTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MileagePreset.sortOrder) private var mileagePresets: [MileagePreset]

    @State private var entryMode: MileageEntryMode = .address
    @State private var date: Date = .now
    @State private var purpose: String = ""
    @State private var notes: String = ""
    @AppStorage("mileage_ratePerMile") private var savedRate: Double = MileageTrip.defaultRatePerMile
    @State private var ratePerMile: Double = MileageTrip.defaultRatePerMile
    @State private var isRoundTrip = false

    // Address mode
    @State private var fromResult: LocationResult?
    @State private var toResult: LocationResult?
    @State private var fromLabel: String = ""
    @State private var toLabel: String = ""
    @State private var fromAddress: String = ""          // full address for export
    @State private var toAddress: String = ""
    @State private var stops: [TripStop] = []            // intermediate stops, in order
    @State private var calculatedMiles: Double?
    @State private var isCalculating = false
    @State private var calculationError: String?
    @State private var showFromSearch = false
    @State private var showToSearch = false
    @State private var stopSearch: StopSearch?           // which intermediate stop's search is open

    // Manual mode
    @State private var manualStartLocation: String = ""
    @State private var manualEndLocation: String = ""
    @State private var manualMiles: Double = 0

    private var oneWayMiles: Double {
        entryMode == .address ? (calculatedMiles ?? 0) : manualMiles
    }

    private var totalMiles: Double {
        oneWayMiles * (isRoundTrip ? 2 : 1)
    }

    private var resolvedStart: String {
        entryMode == .address ? fromLabel : manualStartLocation
    }

    private var resolvedEnd: String {
        entryMode == .address ? toLabel : manualEndLocation
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
                    TextField("Purpose (e.g. Client visit)", text: $purpose)
                    PurposeChipsRow(purpose: $purpose)
                }

                Section("Distance") {
                    if !mileagePresets.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(mileagePresets) { preset in
                                    Button { applyPreset(preset) } label: {
                                        Label(preset.name, systemImage: "map.fill")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    Picker("Entry Mode", selection: $entryMode) {
                        ForEach(MileageEntryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: entryMode) { _, _ in
                        calculatedMiles = nil
                        calculationError = nil
                    }

                    switch entryMode {
                    case .address: addressFields
                    case .manual:  manualFields
                    }

                    if oneWayMiles > 0 {
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
                    if totalMiles > 0 {
                        LabeledContent("Miles") {
                            Text("\(totalMiles.formatted(.number.precision(.fractionLength(2)))) mi")
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Reimbursement") {
                            Text(reimbursement, format: AppCurrency.style)
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
            .onAppear { ratePerMile = savedRate }
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
            .sheet(item: $stopSearch) { target in
                AddressSearchView(title: "Stop") { result in
                    if let idx = stops.firstIndex(where: { $0.id == target.id }) {
                        stops[idx].result = result
                        stops[idx].label = labelFor(result)
                        calculatedMiles = nil
                    }
                }
            }
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

        // Intermediate stops
        ForEach($stops) { $stop in
            Button { stopSearch = StopSearch(id: stop.id) } label: {
                LabeledContent("Stop") {
                    Text(stop.label.isEmpty ? "Search address…" : stop.label)
                        .foregroundStyle(stop.label.isEmpty ? .tertiary : .primary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
            .foregroundStyle(.primary)
        }
        .onDelete { offsets in
            stops.remove(atOffsets: offsets)
            calculatedMiles = nil
        }

        Button {
            stops.append(TripStop())
            calculatedMiles = nil
        } label: {
            Label("Add Stop", systemImage: "plus.circle")
                .font(.subheadline)
        }

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

    // MARK: - Manual fields

    @ViewBuilder
    private var manualFields: some View {
        TextField("Start location", text: $manualStartLocation)
        TextField("End location", text: $manualEndLocation)
        LabeledContent("Miles (one way)") {
            TextField("0.0", value: $manualMiles, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
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
        // Build ordered route, skipping any unfilled intermediate stops
        let route = [from] + stops.compactMap { $0.result } + [to]
        do {
            calculatedMiles = try await calculateDrivingMiles(stops: route)
        } catch {
            calculationError = error.localizedDescription
        }
        isCalculating = false
    }

    // MARK: - Mileage preset

    private func applyPreset(_ preset: MileagePreset) {
        if !preset.purpose.isEmpty { purpose = preset.purpose }
        if !preset.notes.isEmpty { notes = preset.notes }
        // Fill manual fields as a reliable fallback
        manualStartLocation = preset.startLocation
        manualEndLocation = preset.endLocation
        fromLabel = preset.startLocation
        toLabel = preset.endLocation
        fromAddress = preset.startLocation
        toAddress = preset.endLocation
        calculatedMiles = nil
        calculationError = nil

        // Try to geocode both endpoints and auto-calculate driving distance
        Task {
            isCalculating = true
            if let fromCoord = await geocode(preset.startLocation),
               let toCoord = await geocode(preset.endLocation) {
                fromResult = .coordinate(fromCoord, label: preset.startLocation)
                toResult = .coordinate(toCoord, label: preset.endLocation)
                entryMode = .address
                await calculateMiles()
            } else {
                // Geocoding failed — leave the user in manual mode with locations pre-filled
                entryMode = .manual
                isCalculating = false
            }
        }
    }

    private func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let placemarks = try? await CLGeocoder().geocodeAddressString(address)
        return placemarks?.first?.location?.coordinate
    }

    private func save() {
        let trip = MileageTrip(
            date: date,
            startLocation: resolvedStart,
            endLocation: resolvedEnd,
            miles: totalMiles,
            purpose: purpose.isEmpty ? "Business trip" : purpose,
            notes: notes
        )
        // Capture full addresses for export
        if entryMode == .address {
            trip.startAddress = fromAddress
            trip.endAddress = toAddress
            trip.waypoints = stops.compactMap { $0.label.isEmpty ? nil : $0.label }
        } else {
            trip.startAddress = manualStartLocation
            trip.endAddress = manualEndLocation
        }
        modelContext.insert(trip)
        dismiss()
    }
}

#Preview {
    LogTripView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
