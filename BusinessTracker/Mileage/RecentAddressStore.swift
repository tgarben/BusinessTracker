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
    private(set) var favorites: [RecentAddress] = []

    private let userDefaultsKey = "mileage_recent_addresses"
    private let favoritesKey = "mileage_favoriteAddresses"
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

    // MARK: - Favorites

    func isFavorite(label: String) -> Bool {
        favorites.contains { $0.label == label }
    }

    /// Promotes a recent (or any address) to favorites, or removes it if already favorited.
    func toggleFavorite(_ address: RecentAddress) {
        if isFavorite(label: address.label) {
            favorites.removeAll { $0.label == address.label }
        } else {
            favorites.insert(address, at: 0)
        }
        save()
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([RecentAddress].self, from: data) {
            recents = decoded
        }
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([RecentAddress].self, from: data) {
            favorites = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}
