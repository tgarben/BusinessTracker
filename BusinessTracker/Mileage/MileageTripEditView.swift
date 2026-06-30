import SwiftUI
import SwiftData
import MapKit

private enum MileageEditMode: String, CaseIterable {
    case manual  = "Manual"
    case address = "Address"
}

struct MileageTripEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]
    let trip: MileageTrip

    @State private var editMode: MileageEditMode = .manual
    @State private var date: Date
    @State private var purpose: String
    @State private var notes: String
    @State private var ratePerMile: Double
    @State private var selectedClient: Client?

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
    @State private var showFullMap = false

    init(trip: MileageTrip) {
        self.trip = trip
        _date = State(initialValue: trip.date)
        _purpose = State(initialValue: trip.purpose)
        _notes = State(initialValue: trip.notes)
        _ratePerMile = State(initialValue: MileageTrip.ratePerMile)
        _selectedClient = State(initialValue: trip.client)
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

    /// A GPS-tracked trip (manual live-track or auto-detect) — start/end + miles
    /// are already captured, so we show them read-only instead of asking for them.
    private var isTracked: Bool { !trip.routeCoordinates.isEmpty }
    private var effectiveMiles: Double { isTracked ? trip.miles : totalMiles }

    private var reimbursement: Double { effectiveMiles * ratePerMile }

    private var canCalculate: Bool {
        fromResult != nil && toResult != nil && !isCalculating
    }

    private var canSave: Bool {
        isTracked || (totalMiles > 0 && !resolvedStart.isEmpty && !resolvedEnd.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Captured GPS route (auto-detected drives, Phase 2)
                if !trip.routeCoordinates.isEmpty {
                    Section {
                        TrackedRouteMap(coordinates: trip.routeCoordinates) { showFullMap = true }
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        Label("Tracked Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    } footer: {
                        Text("Tap the map to view it full screen.")
                    }
                }

                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Category", text: $purpose)
                    PurposeChipsRow(purpose: $purpose)
                    if !clients.isEmpty {
                        Picker("Client", selection: $selectedClient) {
                            Text("None").tag(Optional<Client>.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(Optional(client))
                            }
                        }
                    }
                }

                if isTracked {
                    // Tracked trip — endpoints + distance captured from GPS (read-only).
                    Section("Route") {
                        LabeledContent("From", value: trip.startLocation.isEmpty ? "Locating…" : trip.startLocation)
                        LabeledContent("To", value: trip.endLocation.isEmpty ? "Locating…" : trip.endLocation)
                        LabeledContent("Distance") {
                            Text("\(trip.miles.formatted(.number.precision(.fractionLength(2)))) mi")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
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
                }

                Section("Reimbursement") {
                    LabeledContent("Rate per Mile") {
                        TextField("0.000", value: $ratePerMile, format: .number.precision(.fractionLength(3)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    LabeledContent("Reimbursement") {
                        Text(reimbursement, format: AppCurrency.style)
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
            .fullScreenCover(isPresented: $showFullMap) {
                FullRouteMapView(coordinates: trip.routeCoordinates)
            }
        }
    }

    // MARK: - Manual fields

    @ViewBuilder
    private var manualFields: some View {
        TextField("Start Location", text: $manualStart)
        TextField("End Location", text: $manualEnd)
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
        trip.notes = notes
        trip.client = selectedClient
        // For a GPS-tracked trip, leave the captured start/end/miles/route alone.
        if !isTracked {
            trip.startLocation = resolvedStart
            trip.endLocation = resolvedEnd
            // Only refresh export addresses when re-picked in address mode (preserves
            // a previously-captured full address when just editing other fields).
            if editMode == .address {
                trip.startAddress = fromAddress
                trip.endAddress = toAddress
            }
            trip.miles = editMode == .address ? totalMiles : manualMiles
        }
        dismiss()
    }
}

// MARK: - Tracked route map

/// Region that fits the whole route with a little padding.
private func routeRegion(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    let lats = coordinates.map(\.latitude)
    let lons = coordinates.map(\.longitude)
    guard let minLat = lats.min(), let maxLat = lats.max(),
          let minLon = lons.min(), let maxLon = lons.max() else {
        return MKCoordinateRegion()
    }
    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                        longitude: (minLon + maxLon) / 2)
    let span = MKCoordinateSpan(latitudeDelta: max(0.005, (maxLat - minLat) * 1.4),
                                longitudeDelta: max(0.005, (maxLon - minLon) * 1.4))
    return MKCoordinateRegion(center: center, span: span)
}

@MapContentBuilder
private func routeContent(_ coordinates: [CLLocationCoordinate2D]) -> some MapContent {
    MapPolyline(coordinates: coordinates).stroke(.blue, lineWidth: 4)
    if let start = coordinates.first {
        Marker("Start", systemImage: "flag.fill", coordinate: start).tint(.green)
    }
    if let end = coordinates.last {
        Marker("End", systemImage: "flag.checkered", coordinate: end).tint(.red)
    }
}

/// A non-interactive map thumbnail inside the form. Tapping calls `onExpand`
/// (the map itself doesn't take gestures, so it doesn't steal the form's scroll).
private struct TrackedRouteMap: View {
    let coordinates: [CLLocationCoordinate2D]
    var onExpand: () -> Void = {}

    var body: some View {
        Map(initialPosition: .region(routeRegion(coordinates))) {
            routeContent(coordinates)
        }
        .allowsHitTesting(false)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(7)
                .background(.regularMaterial, in: Circle())
                .padding(8)
        }
        .overlay {
            // Transparent tap target — opens the full-screen, zoomable map.
            Color.clear.contentShape(Rectangle()).onTapGesture { onExpand() }
        }
    }
}

/// Full-screen, interactive (pinch/zoom/pan) view of the captured route.
private struct FullRouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(routeRegion(coordinates))) {
                routeContent(coordinates)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Tracked Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
