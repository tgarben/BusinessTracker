import Foundation
import CoreLocation
import SwiftData
import ActivityKit
import Observation

/// Manually-tracked mileage trip — a live GPS session the user explicitly starts
/// and stops (the reliable, battery-friendly counterpart to the auto-detector).
///
/// Uses **When-In-Use** authorization (no "Always" needed): background tracking is
/// allowed because the session is started from the foreground and shows the blue
/// status-bar indicator. Captures the full route from the real start, sums true
/// distance, mirrors live distance + elapsed time into a Live Activity, and on
/// stop inserts a normal (non-auto, non-review) `MileageTrip` with the route.
@MainActor
@Observable
final class TripTracker: NSObject {
    static let shared = TripTracker()

    /// Set once at launch (`BusinessTrackerApp`) so the tracker can insert trips.
    var modelContainer: ModelContainer?

    private(set) var isTracking = false
    private(set) var isPaused = false
    /// Live accumulated distance, in meters (observed by the in-progress card).
    private(set) var distanceMeters: Double = 0

    private let manager = CLLocationManager()
    private var fixes: [Fix] = []
    private var lastLocation: CLLocation?

    // Elapsed-time bookkeeping (mirrors TimerState: banked + current running segment).
    private var runningSince: Date?
    private var accumulated: TimeInterval = 0
    private var pendingStart = false               // waiting on a When-In-Use grant
    private var lastLiveUpdate = Date.distantPast

    private let maxStoredPoints = 500

    private struct Fix: Sendable {
        let lat: Double, lon: Double, accuracy: Double
        var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .automotiveNavigation
    }

    // MARK: - Derived state (for UI)

    var miles: Double { distanceMeters / 1609.344 }
    var elapsed: TimeInterval {
        accumulated + (runningSince.map { Date.now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Controls

    func startTrip() {
        guard !isTracking else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            begin()
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        default:
            break   // denied/restricted — UI keeps the user on manual entry
        }
    }

    private func begin() {
        isTracking = true
        isPaused = false
        distanceMeters = 0
        fixes = []
        lastLocation = nil
        accumulated = 0
        runningSince = .now
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        startLiveActivity()
    }

    func pause() {
        guard isTracking, !isPaused else { return }
        isPaused = true
        accumulated += runningSince.map { Date.now.timeIntervalSince($0) } ?? 0
        runningSince = nil
        lastLocation = nil                          // don't count the parked gap on resume
        manager.stopUpdatingLocation()
        refreshLiveActivity()
    }

    func resume() {
        guard isTracking, isPaused else { return }
        isPaused = false
        runningSince = .now
        lastLocation = nil
        manager.startUpdatingLocation()
        refreshLiveActivity()
    }

    /// Stops tracking and saves the trip (returns it so the caller can open its editor).
    @discardableResult
    func stopTrip() -> MileageTrip? {
        guard isTracking else { return nil }
        let captured = fixes
        let started = Date.now.addingTimeInterval(-elapsed)
        let meters = distanceMeters
        teardown()

        guard let container = modelContainer else { return nil }
        let trip = MileageTrip(date: started,
                               startLocation: "", endLocation: "",
                               miles: meters / 1609.344, purpose: "")
        trip.routePoints = downsampledRoute(captured)
        container.mainContext.insert(trip)
        try? container.mainContext.save()
        Task { await reverseGeocodeEndpoints(trip: trip, fixes: captured) }
        return trip
    }

    /// Discards the current trip without saving.
    func cancelTrip() {
        guard isTracking else { return }
        teardown()
    }

    private func teardown() {
        isTracking = false
        isPaused = false
        runningSince = nil
        accumulated = 0
        distanceMeters = 0
        fixes = []
        lastLocation = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        endLiveActivity()
    }

    // MARK: - Location handling

    private func handle(_ newFixes: [Fix]) {
        guard isTracking, !isPaused else { return }
        for f in newFixes where f.accuracy >= 0 && f.accuracy < 100 {
            let loc = CLLocation(latitude: f.lat, longitude: f.lon)
            if let last = lastLocation {
                let step = loc.distance(from: last)
                if step >= 1 { distanceMeters += step }   // ignore sub-meter jitter
            }
            lastLocation = loc
            fixes.append(f)
        }
        if Date.now.timeIntervalSince(lastLiveUpdate) > 5 {
            lastLiveUpdate = .now
            refreshLiveActivity()
        }
    }

    // MARK: - Trip building

    private func downsampledRoute(_ fixes: [Fix]) -> [Double] {
        guard !fixes.isEmpty else { return [] }
        let step = max(1, fixes.count / maxStoredPoints)
        var pts: [Double] = []
        for i in stride(from: 0, to: fixes.count, by: step) {
            pts.append(fixes[i].lat); pts.append(fixes[i].lon)
        }
        if step > 1, let last = fixes.last { pts.append(last.lat); pts.append(last.lon) }
        return pts
    }

    private func reverseGeocodeEndpoints(trip: MileageTrip, fixes: [Fix]) async {
        guard let first = fixes.first, let last = fixes.last else { return }
        let s = await label(for: first.coordinate)
        let e = await label(for: last.coordinate)
        trip.startLocation = s.short; trip.startAddress = s.full
        trip.endLocation = e.short; trip.endAddress = e.full
        try? trip.modelContext?.save()
    }

    private func label(for coord: CLLocationCoordinate2D) async -> (short: String, full: String) {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let p = placemarks.first {
            let street = [p.subThoroughfare, p.thoroughfare].compactMap { $0 }.joined(separator: " ")
            let name = p.name ?? ""
            let line1 = (!name.isEmpty && name != street) ? name : street
            let cityState = [p.locality, p.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            let short = [line1, cityState].filter { !$0.isEmpty }.joined(separator: ", ")
            return (short.isEmpty ? "Dropped pin" : short, short)
        }
        return ("Dropped pin", "")
    }

    // MARK: - Live Activity

    private func contentState() -> TripActivityAttributes.ContentState {
        let now = Date.now
        if isPaused {
            return .init(startDate: now.addingTimeInterval(-elapsed), miles: miles, pauseTime: now)
        }
        return .init(startDate: now.addingTimeInterval(-elapsed), miles: miles, pauseTime: nil)
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        try? Activity<TripActivityAttributes>.request(
            attributes: TripActivityAttributes(),
            content: .init(state: contentState(), staleDate: nil),
            pushType: nil
        )
    }

    private func refreshLiveActivity() {
        let state = contentState()
        Task {
            for activity in Activity<TripActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }

    private func endLiveActivity() {
        Task {
            for activity in Activity<TripActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

extension TripTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.pendingStart, (status == .authorizedWhenInUse || status == .authorizedAlways) {
                self.pendingStart = false
                self.begin()
            } else if status == .denied || status == .restricted {
                self.pendingStart = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newFixes = locations.map {
            Fix(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy)
        }
        Task { @MainActor in self.handle(newFixes) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
