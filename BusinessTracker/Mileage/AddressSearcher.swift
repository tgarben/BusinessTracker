import Foundation
import MapKit
import Observation

/// Observable wrapper around MKLocalSearchCompleter for address autocomplete.
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

/// Resolves two MKLocalSearchCompletion results to a driving distance in miles.
func calculateDrivingMiles(
    from: MKLocalSearchCompletion,
    to: MKLocalSearchCompletion
) async throws -> Double {
    async let fromSearch = MKLocalSearch(request: MKLocalSearch.Request(completion: from)).start()
    async let toSearch   = MKLocalSearch(request: MKLocalSearch.Request(completion: to)).start()

    let (fromResponse, toResponse) = try await (fromSearch, toSearch)

    guard let fromItem = fromResponse.mapItems.first,
          let toItem   = toResponse.mapItems.first else {
        throw MileageCalculationError.locationNotFound
    }

    let request = MKDirections.Request()
    request.source = fromItem
    request.destination = toItem
    request.transportType = .automobile

    let directions = try await MKDirections(request: request).calculate()

    guard let route = directions.routes.first else {
        throw MileageCalculationError.noRouteFound
    }

    return route.distance / 1609.344 // metres → miles
}
