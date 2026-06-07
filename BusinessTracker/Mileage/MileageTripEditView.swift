import SwiftUI
import SwiftData

struct MileageTripEditView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: MileageTrip

    @State private var date: Date
    @State private var purpose: String
    @State private var startLocation: String
    @State private var endLocation: String
    @State private var miles: Double
    @State private var notes: String
    @State private var ratePerMile: Double

    private var reimbursement: Double { miles * ratePerMile }

    init(trip: MileageTrip) {
        self.trip = trip
        _date = State(initialValue: trip.date)
        _purpose = State(initialValue: trip.purpose)
        _startLocation = State(initialValue: trip.startLocation)
        _endLocation = State(initialValue: trip.endLocation)
        _miles = State(initialValue: trip.miles)
        _notes = State(initialValue: trip.notes)
        _ratePerMile = State(initialValue: MileageTrip.ratePerMile)
    }

    private var canSave: Bool {
        miles > 0 && !startLocation.isEmpty && !endLocation.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Purpose", text: $purpose)
                }

                Section("Route") {
                    TextField("Start location", text: $startLocation)
                    TextField("End location", text: $endLocation)
                    LabeledContent("Miles") {
                        TextField("0.0", value: $miles, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        trip.date = date
        trip.purpose = purpose.isEmpty ? "Business trip" : purpose
        trip.startLocation = startLocation
        trip.endLocation = endLocation
        trip.miles = miles
        trip.notes = notes
        dismiss()
    }
}
