import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import UserNotifications
import Observation
import UIKit

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

    /// ⚑ Master feature switch. **Auto-Mileage is SHELVED for 1.0** (Tyler + Jack,
    /// 2026-06-27) — kept fully built but dormant. While `false`: `refreshFromSettings`
    /// no-ops (releasing any election so other devices aren't blocked), no background
    /// monitoring ever starts, and the Settings "Automatic Mileage (BETA)" section is
    /// hidden. Flip to `true` to re-enable the beta (see the Auto-Mileage plan in
    /// CLAUDE.md — also re-check the CloudKit redeploy of the auto fields before shipping).
    static let featureEnabled = false

    /// Opt-in toggle key. Device-specific → intentionally NOT in `CloudKeyValueSync`.
    static let enabledKey = "mileage_autoDetectEnabled"

    /// iCloud key-value store keys electing WHICH device runs background tracking.
    /// Synced across the user's devices so only one device logs a given drive —
    /// prevents double-logging when auto-tracking is on for >1 device (e.g. an
    /// iPhone + iPad both in the car). The other devices stay dormant but still
    /// receive the logged trips via CloudKit and can review/categorize them.
    /// The election is a **lease**: the owner stamps a heartbeat; if it goes stale
    /// (owner uninstalled / off for days / lost permission) another device takes over.
    static let trackingDeviceKey = "mileage_autoDetectDeviceID"
    static let trackingHeartbeatKey = "mileage_autoDetectHeartbeat"   // owner lastSeen (epoch seconds)

    /// A stable per-install ID + the `identifierForVendor` it was minted under, so a
    /// device restored from another's backup (which carries the same UserDefaults)
    /// re-mints a fresh ID instead of impersonating the source device's election.
    private static let localDeviceIDKey = "mileage_localDeviceID"
    private static let localDeviceVendorIDKey = "mileage_localDeviceVendorID"

    /// Owner silent (no heartbeat) this long → the election is considered dead and
    /// another enabled+authorized device may take it over. Generous so a phone left
    /// home overnight doesn't trigger a handoff; a sold/dead/permission-lost owner does.
    private let leaseTimeout: TimeInterval = 60 * 60 * 72   // 72h

    /// Set once at launch (`BusinessTrackerApp`) so the detector can insert trips.
    var modelContainer: ModelContainer?

    /// Mirrors the system authorization so Settings can show a "needs Always" hint.
    private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var isMonitoring = false

    // Active drive session
    private(set) var isTrackingDrive = false   // read by TripTracker to avoid auto+manual double-logging
    private var routeFixes: [Fix] = []
    private var driveStartedAt: Date?
    private var lastMovementAt: Date?
    /// Wall-clock backstop so a drive finalizes even if location callbacks stop
    /// entirely (parked, no OS pause event) — the old in-`handle` check needed a
    /// fresh fix to ever run.
    private var finalizeTask: Task<Void, Never>?
    /// On-disk snapshot of the in-progress drive so a route isn't lost if the app
    /// is force-quit / purged mid-drive (recovered + finalized on next launch).
    /// Caches dir is always present (vs. Application Support) and a purge here only
    /// costs recovery — no worse than before the snapshot existed.
    private var crashSnapshotURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("autodrive_inprogress.json")
    }
    private var lastSnapshotAt = Date.distantPast

    // Heuristics (tuned with real drives during beta). Lower = more sensitive
    // (catches drives sooner / shorter ones) at the cost of more false positives.
    private let driveStartSpeed: Double = 4.5     // m/s ≈ 10 mph — instant-start threshold (else falls back to motion)
    private let movingSpeed: Double = 2.0         // m/s ≈ 4.5 mph — still moving
    private let stationaryTimeout: TimeInterval = 240   // finalize after 4 min stopped (backup to the OS pause)
    private let minMiles: Double = 0.2            // drop GPS noise / a step outside
    private let maxStoredPoints = 500             // downsample the route for the CloudKit field

    /// A Sendable snapshot of a `CLLocation` so we can hop off the delegate thread.
    private struct Fix: Sendable, Codable {
        let lat: Double, lon: Double, speed: Double, accuracy: Double, time: Date
        var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    }

    /// Persisted shape of an in-progress drive (for force-quit recovery).
    private struct DriveSnapshot: Codable {
        var fixes: [Fix]
        var startedAt: Date
        var lastMovementAt: Date
    }

    private override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.activityType = .automotiveNavigation

        // React when another device claims/releases the tracking election remotely.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshFromSettings() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    // MARK: - Tracking-device election (multi-device de-dup)

    private var kvStore: NSUbiquitousKeyValueStore { .default }

    /// A stable ID for this install. Re-minted if `identifierForVendor` changes
    /// (e.g. the app was restored onto a new device from another device's backup),
    /// so two installs never share an ID and impersonate one election.
    private var localDeviceID: String {
        let currentVendor = UIDevice.current.identifierForVendor?.uuidString
        let storedVendor = UserDefaults.standard.string(forKey: Self.localDeviceVendorIDKey)
        if let id = UserDefaults.standard.string(forKey: Self.localDeviceIDKey),
           currentVendor == nil || storedVendor == currentVendor {
            return id   // existing ID still valid (or vendor momentarily unavailable — don't churn)
        }
        let id = currentVendor ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: Self.localDeviceIDKey)
        UserDefaults.standard.set(currentVendor, forKey: Self.localDeviceVendorIDKey)
        return id
    }

    /// The device elected to run background tracking (nil = unclaimed).
    var trackingDeviceID: String? {
        let v = kvStore.string(forKey: Self.trackingDeviceKey)
        return (v == nil || v!.isEmpty) ? nil : v
    }

    private var electionHeartbeat: Date? {
        let t = kvStore.double(forKey: Self.trackingHeartbeatKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// The election is "live" only if an owner is set AND its heartbeat is recent.
    /// A stale/absent heartbeat ⇒ the owner is gone → another device may take over.
    var electionIsLive: Bool {
        guard trackingDeviceID != nil, let hb = electionHeartbeat else { return false }
        return Date.now.timeIntervalSince(hb) < leaseTimeout
    }

    /// This device runs GPS tracking only if it owns the election, or the election
    /// is dead/unclaimed (so it can take over).
    var isTrackingDevice: Bool {
        if trackingDeviceID == localDeviceID { return true }
        return !electionIsLive
    }

    /// Auto-mileage is enabled here, but ANOTHER device holds a LIVE election → we
    /// stay dormant (still see its trips via CloudKit). Drives the Settings UI.
    var otherDeviceIsTracking: Bool {
        isEnabled && trackingDeviceID != localDeviceID && electionIsLive
    }

    private func claimTrackingDevice() {
        kvStore.set(localDeviceID, forKey: Self.trackingDeviceKey)
        kvStore.set(Date.now.timeIntervalSince1970, forKey: Self.trackingHeartbeatKey)
        kvStore.synchronize()
    }

    /// Refresh the owner's lease, throttled so we don't write the KV store on every
    /// foreground (quota-friendly) — a quarter of the lease is plenty of margin.
    private func heartbeatIfOwner() {
        guard trackingDeviceID == localDeviceID else { return }
        if let hb = electionHeartbeat, Date.now.timeIntervalSince(hb) < leaseTimeout / 4 { return }
        kvStore.set(Date.now.timeIntervalSince1970, forKey: Self.trackingHeartbeatKey)
        kvStore.synchronize()
    }

    private func releaseTrackingDeviceIfOwner() {
        if trackingDeviceID == localDeviceID {
            kvStore.removeObject(forKey: Self.trackingDeviceKey)
            kvStore.removeObject(forKey: Self.trackingHeartbeatKey)
            kvStore.synchronize()
        }
    }

    /// User tapped "Use this device" — take over the election from another device.
    func makeThisTrackingDevice() {
        claimTrackingDevice()
        refreshFromSettings()
    }

    var hasAlwaysAuthorization: Bool { authorizationStatus == .authorizedAlways }
    var needsAlwaysPermission: Bool {
        isEnabled && authorizationStatus != .authorizedAlways && authorizationStatus != .notDetermined
    }

    /// Call on launch + foreground (and on auth / KV changes). Centralizes the whole
    /// policy: only an enabled device that actually has "Always" permission holds the
    /// election; it claims when the election is its own / unowned / stale, and starts
    /// monitoring. Anything else releases the election (so it can't silently block
    /// other devices) and stays dormant.
    func refreshFromSettings() {
        // Auto-Mileage shelved for 1.0 — stay fully dormant (release any election we
        // still hold so other devices aren't blocked, and never start monitoring).
        guard Self.featureEnabled else { clearSnapshot(); releaseTrackingDeviceIfOwner(); stop(); return }

        guard isEnabled else { clearSnapshot(); releaseTrackingDeviceIfOwner(); stop(); return }

        recoverInterruptedDriveIfNeeded()

        // Without "Always" we can't track in the background. Don't squat on the
        // election — release it so another capable device can take over — but still
        // drive the permission-request flow.
        guard hasAlwaysAuthorization else {
            releaseTrackingDeviceIfOwner()
            stop()
            start()   // requests Always when notDetermined / whenInUse
            return
        }

        // We can track. Take/refresh the lease when it's ours, unclaimed, or stale.
        if trackingDeviceID == localDeviceID {
            heartbeatIfOwner()
        } else if !electionIsLive {
            claimTrackingDevice()
        }

        if isTrackingDevice { start() } else { stop() }
    }

    /// Toggle entry point (from Settings). Persists the flag; everything else (claim,
    /// permission request, start/stop) flows through `refreshFromSettings`.
    func setEnabled(_ on: Bool) {
        guard Self.featureEnabled else { return }   // shelved — ignore
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        refreshFromSettings()
    }

    private func start() {
        guard isEnabled, isTrackingDevice else { return }
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
            var moved = false
            for f in fixes where f.accuracy >= 0 && f.accuracy < 100 {
                routeFixes.append(f)
                if f.speed >= movingSpeed { lastMovementAt = .now; moved = true }
            }
            if moved { scheduleFinalizeTimer() }   // re-arm the stationary backstop on movement
            persistSnapshot()                      // for force-quit recovery
            // Immediate backup stop (the OS pause is the primary signal — see didPause;
            // the wall-clock `finalizeTask` covers the "no more fixes arrive" case).
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
        scheduleFinalizeTimer()
        persistSnapshot()
    }

    /// The user started a MANUAL trip — abandon any in-progress auto-drive (don't
    /// save it) so the same drive isn't logged twice. The manual trip will cover it.
    func cancelActiveDriveForManualTracking() {
        guard isTrackingDrive else { return }
        routeFixes = []
        driveStartedAt = nil
        cancelFinalizeTimer()
        clearSnapshot()
        endActiveSession()
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
        cancelFinalizeTimer()
        clearSnapshot()
        endActiveSession()
        Task { await buildTrip(from: fixes, startedAt: startedAt) }
    }

    // MARK: - Stationary backstop (wall-clock, independent of incoming fixes)

    private func scheduleFinalizeTimer() {
        cancelFinalizeTimer()
        let timeout = stationaryTimeout
        finalizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.finalizeIfStillStationary()
        }
    }

    private func cancelFinalizeTimer() {
        finalizeTask?.cancel()
        finalizeTask = nil
    }

    private func finalizeIfStillStationary() {
        guard isTrackingDrive else { return }
        if let last = lastMovementAt, Date.now.timeIntervalSince(last) >= stationaryTimeout {
            finalizeDrive()
        } else {
            scheduleFinalizeTimer()   // moved since the timer was set — re-arm
        }
    }

    // MARK: - Force-quit recovery

    private func persistSnapshot() {
        guard isTrackingDrive, let startedAt = driveStartedAt, let moved = lastMovementAt else { return }
        guard Date.now.timeIntervalSince(lastSnapshotAt) >= 15 else { return }   // throttle disk I/O
        lastSnapshotAt = .now
        let snap = DriveSnapshot(fixes: routeFixes, startedAt: startedAt, lastMovementAt: moved)
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: crashSnapshotURL) }
    }

    private func clearSnapshot() {
        lastSnapshotAt = .distantPast
        try? FileManager.default.removeItem(at: crashSnapshotURL)
    }

    /// On launch, salvage a drive that was in progress when the app was killed/purged.
    /// Only finalizes a snapshot whose last movement is older than the stationary
    /// timeout (the drive clearly ended while we were dead) — a still-recent snapshot
    /// is discarded so we never double-log a drive the live session is continuing.
    private func recoverInterruptedDriveIfNeeded() {
        // Wait until the container is wired (set at launch) so we don't delete the
        // snapshot before we can build the trip from it.
        guard modelContainer != nil, !isTrackingDrive,
              let data = try? Data(contentsOf: crashSnapshotURL),
              let snap = try? JSONDecoder().decode(DriveSnapshot.self, from: data) else { return }
        clearSnapshot()
        guard Date.now.timeIntervalSince(snap.lastMovementAt) >= stationaryTimeout else { return }
        Task { await buildTrip(from: snap.fixes, startedAt: snap.startedAt) }
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

        // Insert-time de-dup backstop for the brief election-claim race: if a near-
        // identical auto-trip already exists locally (the OTHER device finalized first
        // and it synced over), skip this one rather than double-log. Conservative —
        // requires both a tight time overlap AND matching endpoints, so distinct trips
        // are never merged.
        if hasDuplicateAutoTrip(startedAt: startedAt, start: fixes.first!.coordinate,
                                end: fixes.last!.coordinate, container: container) { return }

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

    /// True if an auto-detected trip closely matching this one already exists (same
    /// approximate start time AND both endpoints) — the cross-device claim-race backstop.
    private func hasDuplicateAutoTrip(startedAt: Date, start: CLLocationCoordinate2D,
                                      end: CLLocationCoordinate2D, container: ModelContainer) -> Bool {
        let window: TimeInterval = 300        // ±5 min
        let lower = startedAt.addingTimeInterval(-window)
        let upper = startedAt.addingTimeInterval(window)
        let descriptor = FetchDescriptor<MileageTrip>(predicate: #Predicate {
            $0.isAutoDetected && $0.deletedDate == nil && $0.date >= lower && $0.date <= upper
        })
        guard let candidates = try? container.mainContext.fetch(descriptor) else { return false }
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let tol: CLLocationDistance = 300     // meters — endpoints must both be this close
        for t in candidates {
            let coords = t.routeCoordinates
            guard let s = coords.first, let e = coords.last else { continue }
            let sNear = startLoc.distance(from: CLLocation(latitude: s.latitude, longitude: s.longitude)) < tol
            let eNear = endLoc.distance(from: CLLocation(latitude: e.latitude, longitude: e.longitude)) < tol
            if sNear && eNear { return true }
        }
        return false
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
            // Centralized policy: claim+start with Always, release+stop without it
            // (so a downgraded owner can't silently block other devices).
            self.refreshFromSettings()
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
