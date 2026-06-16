import SwiftUI

/// Reusable address entry for forms: an editable street line with a search button that opens
/// the same MapKit autocomplete used elsewhere in the app, plus a second line for Apt/Suite/Unit.
/// Pass `icon` to render a leading `SettingsIcon` (Settings style); leave nil for plain forms.
struct AddressEntryField: View {
    let label: String
    @Binding var line1: String
    @Binding var line2: String
    var icon: String? = nil
    var iconColor: Color = .indigo

    @State private var showSearch = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                SettingsIcon(symbol: icon, color: iconColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                if !label.isEmpty {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    TextField("Street address", text: $line1, axis: .vertical)
                        .lineLimit(1...2)
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                TextField("Apt, Suite, Unit (optional)", text: $line2)
            }
        }
        .sheet(isPresented: $showSearch) {
            AddressSearchView(title: label.isEmpty ? "Address" : label) { result in
                switch result {
                case .completion(let completion): line1 = fullAddress(completion)
                case .coordinate(_, let lbl):      line1 = lbl
                }
            }
        }
    }
}
