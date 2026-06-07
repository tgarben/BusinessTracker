import SwiftUI
import MapKit

/// A search sheet that lets the user pick an address via MKLocalSearchCompleter.
struct AddressSearchView: View {
    let title: String
    let onSelect: (MKLocalSearchCompletion) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searcher = AddressSearcher()

    var body: some View {
        NavigationStack {
            List {
                if searcher.query.isEmpty {
                    ContentUnavailableView(
                        "Search for an Address",
                        systemImage: "magnifyingglass",
                        description: Text("Start typing to find a location.")
                    )
                    .listRowBackground(Color.clear)
                } else if searcher.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if searcher.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "location.slash",
                        description: Text("Try a different address or place name.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(searcher.results, id: \.self) { completion in
                        Button {
                            onSelect(completion)
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searcher.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search address or place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
