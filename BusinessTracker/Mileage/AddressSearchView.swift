import SwiftUI
import MapKit
import CoreLocation

struct AddressSearchView: View {
    let title: String
    let onSelect: (LocationResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searcher = AddressSearcher()
    @State private var locationManager = LocationManager()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        locationManager.requestCurrentLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("Use Current Location")
                                .foregroundStyle(.primary)
                            Spacer()
                            if locationManager.isLocating {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(locationManager.isLocating)
                }

                if !searcher.query.isEmpty {
                    if searcher.isSearching {
                        Section {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .listRowBackground(Color.clear)
                        }
                    } else if searcher.results.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "location.slash",
                                description: Text("Try a different address or place name.")
                            )
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        Section {
                            ForEach(searcher.results, id: \.self) { completion in
                                Button {
                                    onSelect(.completion(completion))
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .foregroundStyle(.primary)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searcher.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search address or place"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: locationManager.location) { _, loc in
                guard let loc else { return }
                Task {
                    let geocoder = CLGeocoder()
                    if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
                       let placemark = placemarks.first {
                        let label = [placemark.name, placemark.locality, placemark.administrativeArea]
                            .compactMap { $0 }
                            .joined(separator: ", ")
                        onSelect(.coordinate(loc.coordinate, label: label))
                        dismiss()
                    }
                }
            }
        }
    }
}
