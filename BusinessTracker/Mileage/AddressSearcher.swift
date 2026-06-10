import Foundation
import MapKit
import CoreLocation
import Observation

// MARK: - Location result

enum LocationResult {
    case completion(MKLocalSearchCompletion)
    case coordinate(CLLocationCoordinate2D, label: String)
}

// MARK: - Address shortening

/// Builds a short "Name/Street, City, State" label from a MapKit completion.
/// Drops the country (last subtitle component) and for POIs strips the street
/// so only city + state remain after the place name.
func shortAddress(_ completion: MKLocalSearchCompletion) -> String {
    var parts = completion.subtitle.components(separatedBy: ", ")
    if parts.count >= 3 { parts.removeLast() }          // drop country
    let cityState = parts.count > 2 ? Array(parts.suffix(2)) : parts
    let location = cityState.joined(separator: ", ")
    return [completion.title, location].filter { !$0.isEmpty }.joined(separator: ", ")
}

// MARK: - Address autocomplete

@Observable
final class AddressSearcher: NSObject, MKLocalSearchCompleterDelegate {
    var query: String = "" {
        didSet {
            isSearching = !query.isEmpty
            completer.queryFragment = query
        }
    }
    var results: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
    }
}

// MARK: - Location manager

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    var isLocating = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestCurrentLocation() {
        isLocating = true
        location = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            isLocating = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        isLocating = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // Only act if the user explicitly tapped "Use Current Location" —
        // this delegate fires immediately on init (before any user action),
        // so guard on isLocating to avoid auto-requesting on sheet open.
        guard isLocating else { return }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus != .notDetermined {
            isLocating = false
        }
    }
}

// MARK: - Distance calculation

enum MileageCalculationError: LocalizedError {
    case locationNotFound
    case noRouteFound

    var errorDescription: String? {
        switch self {
        case .locationNotFound: return "Could not find one of the addresses."
        case .noRouteFound:     return "Could not calculate a driving route between those addresses."
        }
    }
}

func calculateDrivingMiles(from: LocationResult, to: LocationResult) async throws -> Double {
    async let fromItem = mapItem(for: from)
    async let toItem   = mapItem(for: to)
    let (f, t) = try await (fromItem, toItem)

    let request = MKDirections.Request()
    request.source = f
    request.destination = t
    request.transportType = .automobile

    let directions = try await MKDirections(request: request).calculate()

    guard let route = directions.routes.first else {
        throw MileageCalculationError.noRouteFound
    }

    return route.distance / 1609.344  // metres → miles
}

private func mapItem(for result: LocationResult) async throws -> MKMapItem {
    switch result {
    case .completion(let completion):
        let response = try await MKLocalSearch(request: .init(completion: completion)).start()
        guard let item = response.mapItems.first else { throw MileageCalculationError.locationNotFound }
        return item
    case .coordinate(let coord, let label):
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = label
        return item
    }
}
