import SwiftUI
import MapKit
import CoreLocation

struct AddressSearchView: View {
    let title: String
    let onSelect: (LocationResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searcher = AddressSearcher()
    @State private var locationManager = LocationManager()
    @State private var store = RecentAddressStore()

    var body: some View {
        NavigationStack {
            List {
                // MARK: Current location
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

                // MARK: Body — recents or search results
                if searcher.query.isEmpty {
                    if !store.recents.isEmpty {
                        Section {
                            ForEach(store.recents) { recent in
                                Button {
                                    select(recent.locationResult, label: recent.label, coordinate: recent.coordinate)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        Text(recent.label)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                store.remove(at: offsets)
                            }
                        } header: {
                            Text("Recent")
                        }
                    }
                } else if searcher.isSearching {
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
                                let label = shortAddress(completion)
                                // Select immediately; resolve coordinate for recents in background
                                onSelect(.completion(completion))
                                Task {
                                    if let response = try? await MKLocalSearch(
                                        request: .init(completion: completion)
                                    ).start(),
                                       let coord = response.mapItems.first?.placemark.coordinate {
                                        store.add(label: label, coordinate: coord)
                                    }
                                }
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
                        store.add(label: label, coordinate: loc.coordinate)
                        select(.coordinate(loc.coordinate, label: label), label: label, coordinate: loc.coordinate)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func select(_ result: LocationResult, label: String, coordinate: CLLocationCoordinate2D) {
        store.add(label: label, coordinate: coordinate)
        onSelect(result)
        dismiss()
    }
}
