import Foundation
import CoreLocation
import Observation
import SwiftUI

// MARK: - Model

struct RecentAddress: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let label: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationResult: LocationResult {
        .coordinate(coordinate, label: label)
    }
}

// MARK: - Store

@Observable
final class RecentAddressStore {
    private(set) var recents: [RecentAddress] = []

    private let userDefaultsKey = "mileage_recent_addresses"
    private let maxCount = 8

    init() { load() }

    /// Inserts or moves an address to the top, then trims to maxCount.
    func add(label: String, coordinate: CLLocationCoordinate2D) {
        let address = RecentAddress(
            label: label,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        recents.removeAll { $0.label == label }
        recents.insert(address, at: 0)
        if recents.count > maxCount { recents = Array(recents.prefix(maxCount)) }
        save()
    }

    func remove(at offsets: IndexSet) {
        recents.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([RecentAddress].self, from: data)
        else { return }
        recents = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recents) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
