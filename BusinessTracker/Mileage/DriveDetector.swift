import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import UserNotifications
import Observation

/// Automatic Drive Detection service (Auto-Mileage).
///
/// **Phase 2 — active route tracking (BETA).** Passive `significant-location-change`
/// monitoring (near-zero battery) wakes the app; when motion/speed indicate the
/// user is driving, it starts a high-accuracy location stream and accumulates the
/// GPS route. iOS pauses updates when the user stops (or a stationary timeout
/// fires), which finalizes the drive: real distance from the polyline, endpoints
/// reverse-geocoded, a **needs-review** `MileageTrip` inserted (with the route in
/// `routePoints` for the map), and a local notification. High accuracy runs ONLY
/// during a confirmed drive; otherwise it's significant-change only. Phase 0 =
/// toggle + Always-auth plumbing. See the plan in CLAUDE.md.
@MainActor
@Observable
final class DriveDetector: NSObject {
    static let shared = DriveDetector()

    /// Opt-in toggle key. Device-specific → intentionally NOT in `CloudKeyValueSync`.
    static let enabledKey = "mileage_autoDetectEnabled"

    /// Set once at launch (`BusinessTrackerApp`) so the detector can insert trips.
    var modelContainer: ModelContainer?

    /// Mirrors the system authorization so Settings can show a "needs Always" hint.
    private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var isMonitoring = false

    // Active drive session
    private var isTrackingDrive = false
    private var routeFixes: [Fix] = []
    private var driveStartedAt: Date?
    private var lastMovementAt: Date?

    // Heuristics (tuned with real drives during beta)
    private let driveStartSpeed: Double = 6.0     // m/s ≈ 13 mph — clearly driving
    private let movingSpeed: Double = 2.0         // m/s ≈ 4.5 mph — still moving
    private let stationaryTimeout: TimeInterval = 240   // finalize after 4 min stopped (backup to the OS pause)
    private let minMiles: Double = 0.3            // drop GPS noise / a step outside
    private let maxStoredPoints = 500             // downsample the route for the CloudKit field

    /// A Sendable snapshot of a `CLLocation` so we can hop off the delegate thread.
    private struct Fix: Sendable {
        let lat: Double, lon: Double, speed: Double, accuracy: Double, time: Date
        var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    }

    private override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.activityType = .automotiveNavigation
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var hasAlwaysAuthorization: Bool { authorizationStatus == .authorizedAlways }
    var needsAlwaysPermission: Bool {
        isEnabled && authorizationStatus != .authorizedAlways && authorizationStatus != .notDetermined
    }

    /// Call on launch + foreground: start monitoring if enabled & authorized, else stop.
    func refreshFromSettings() {
        if isEnabled { start() } else { stop() }
    }

    /// Toggle entry point (from Settings). Persists the flag and requests Always
    /// authorization on first enable; monitoring begins once Always is granted.
    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        if on { start() } else { stop() }
    }

    private func start() {
        guard isEnabled else { return }
        switch authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            beginMonitoring()
        default:
            break
        }
    }

    func stop() {
        if isTrackingDrive { endActiveSession() }
        guard isMonitoring else { return }
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }

    private func beginMonitoring() {
        guard !isMonitoring else { return }
        manager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
    }

    // MARK: - Drive session

    private func handle(_ fixes: [Fix]) {
        if isTrackingDrive {
            for f in fixes where f.accuracy >= 0 && f.accuracy < 100 {
                routeFixes.append(f)
                if f.speed >= movingSpeed { lastMovementAt = .now }
            }
            // Backup stop (the OS pause is the primary signal — see didPause).
            if let last = lastMovementAt, Date().timeIntervalSince(last) > stationaryTimeout {
                finalizeDrive()
            }
        } else if let f = fixes.last {
            maybeStartDrive(f)
        }
    }

    private func maybeStartDrive(_ fix: Fix) {
        // Don't auto-log while the user is manually tracking a trip (avoid double trips).
        guard !TripTracker.shared.isTracking else { return }
        if fix.speed >= driveStartSpeed {
            startActiveSession(from: fix)
        } else {
            Task { if await wasDrivingRecently() { self.startActiveSession(from: fix) } }
        }
    }

    private func startActiveSession(from fix: Fix) {
        guard !isTrackingDrive, isEnabled else { return }
        isTrackingDrive = true
        routeFixes = [fix]
        driveStartedAt = fix.time
        lastMovementAt = .now
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.startUpdatingLocation()
    }

    /// Tears down the high-accuracy stream and returns to passive monitoring.
    private func endActiveSession() {
        isTrackingDrive = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    private func finalizeDrive() {
        guard isTrackingDrive else { return }
        let fixes = routeFixes
        let startedAt = driveStartedAt ?? fixes.first?.time ?? .now
        routeFixes = []
        driveStartedAt = nil
        endActiveSession()
        Task { await buildTrip(from: fixes, startedAt: startedAt) }
    }

    private func buildTrip(from fixes: [Fix], startedAt: Date) async {
        guard fixes.count >= 2, let container = modelContainer else { return }

        var meters = 0.0
        for i in 1..<fixes.count {
            let a = CLLocation(latitude: fixes[i - 1].lat, longitude: fixes[i - 1].lon)
            let b = CLLocation(latitude: fixes[i].lat, longitude: fixes[i].lon)
            meters += b.distance(from: a)
        }
        let miles = meters / 1609.344
        guard miles >= minMiles else { return }

        let start = await reverseGeocode(fixes.first!.coordinate)
        let end = await reverseGeocode(fixes.last!.coordinate)

        let trip = MileageTrip(date: startedAt,
                               startLocation: start.short, endLocation: end.short,
                               miles: miles, purpose: "")
        trip.startAddress = start.full
        trip.endAddress = end.full
        trip.isAutoDetected = true
        trip.needsReview = true
        trip.routePoints = downsampledRoute(fixes)
        container.mainContext.insert(trip)
        try? container.mainContext.save()

        notifyDriveLogged(miles: miles, start: start.short, end: end.short)
    }

    /// Flattens the route to `[lat, lon, …]`, capped at `maxStoredPoints`.
    private func downsampledRoute(_ fixes: [Fix]) -> [Double] {
        let step = max(1, fixes.count / maxStoredPoints)
        var pts: [Double] = []
        for i in stride(from: 0, to: fixes.count, by: step) {
            pts.append(fixes[i].lat); pts.append(fixes[i].lon)
        }
        if step > 1, let last = fixes.last {       // always keep the true endpoint
            pts.append(last.lat); pts.append(last.lon)
        }
        return pts
    }

    // MARK: - Motion / geocoding helpers

    /// True if motion history shows automotive activity in the last few minutes.
    private func wasDrivingRecently() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else { return false }
        let to = Date()
        let from = to.addingTimeInterval(-180)
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let queue = OperationQueue()
            motion.queryActivityStarting(from: from, to: to, to: queue) { activities, error in
                guard let activities, error == nil else { cont.resume(returning: false); return }
                let drove = activities.contains {
                    $0.automotive && ($0.confidence == .medium || $0.confidence == .high)
                }
                cont.resume(returning: drove)
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> (short: String, full: String) {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let p = placemarks.first {
            return Self.addressLabels(p)
        }
        return ("Dropped pin", "")
    }

    /// Formats a placemark into a short display label + a fuller export address.
    private static func addressLabels(_ p: CLPlacemark) -> (short: String, full: String) {
        let street = [p.subThoroughfare, p.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let name = p.name ?? ""
        let line1 = (!name.isEmpty && name != street) ? name : street
        let city = p.locality ?? ""
        let state = p.administrativeArea ?? ""
        let cityState = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        let zip = p.postalCode ?? ""

        let short = [line1, cityState].filter { !$0.isEmpty }.joined(separator: ", ")
        var fullParts = [line1]
        if !street.isEmpty && street != line1 { fullParts.append(street) }
        let cityStateZip = cityState + (zip.isEmpty ? "" : " \(zip)")
        if !cityStateZip.isEmpty { fullParts.append(cityStateZip) }
        let full = fullParts.filter { !$0.isEmpty }.joined(separator: ", ")

        return (short.isEmpty ? "Dropped pin" : short, full.isEmpty ? short : full)
    }

    private func notifyDriveLogged(miles: Double, start: String, end: String) {
        let content = UNMutableNotificationContent()
        content.title = "Drive logged"
        content.body = String(format: "%.1f mi · %@ → %@ — tap to review & categorize.", miles, start, end)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "autodrive-\(UUID().uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension DriveDetector: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.isEnabled && status == .authorizedAlways {
                self.beginMonitoring()
            } else if status != .authorizedAlways {
                self.stop()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fixes = locations.map {
            Fix(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude,
                speed: $0.speed, accuracy: $0.horizontalAccuracy, time: $0.timestamp)
        }
        Task { @MainActor in self.handle(fixes) }
    }

    /// The OS detected the user stopped moving — finalize the drive (primary stop).
    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in self.finalizeDrive() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal — monitoring resumes on the next significant change.
    }
}
