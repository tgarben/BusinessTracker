import Foundation

/// Mirrors a fixed set of user-level settings between `UserDefaults.standard`
/// (where all the app's `@AppStorage` keys live) and `NSUbiquitousKeyValueStore`
/// (Apple's iCloud key-value store) so they follow the user across devices.
///
/// The SwiftData models already sync via CloudKit, but business info, the user's
/// profile, and financial defaults are stored in `@AppStorage` — which is purely
/// local. This bridges that gap without touching any of the existing `@AppStorage`
/// declarations: it pushes local changes up to iCloud and pulls remote changes
/// back down into `UserDefaults`, which `@AppStorage` observes and re-renders from.
///
/// Layout/device-specific keys (home_* section order, widget config, notification
/// toggles) are intentionally NOT synced — those should stay per-device.
enum CloudKeyValueSync {

    /// Keys that should follow the user across every device signed into the same
    /// iCloud account. These are "account setup" values, not device preferences.
    static let syncedKeys: [String] = [
        // Profile / personalization
        "user_name",
        "user_lastName",
        "user_primaryUse",

        // Business information + invoicing defaults
        "business_name",
        "business_address",
        "business_address2",
        "business_phone",
        "business_email",
        "business_website",
        "business_taxID",
        "business_defaultTaxRate",
        "business_defaultPaymentTerms",
        "business_acceptedPayments",
        "business_paymentInstructions",

        // Rates, fuel & tax defaults
        "mileage_ratePerMile",
        "default_hourlyRate",
        "report_mpg",
        "report_gasPrice",
        "tax_selfEmploymentRate",
        "tax_incomeBracketRate",
        "tax_businessStructure",

        // Mileage quick-fill templates
        "mileage_purposePresets",
        "mileage_favoriteAddresses",
    ]

    private static let keySet = Set(syncedKeys)

    /// Set while we copy remote values into `UserDefaults` so the resulting
    /// `UserDefaults.didChangeNotification` doesn't bounce straight back to iCloud.
    private static var isApplyingRemoteChange = false

    private static var observersInstalled = false

    /// Begin syncing. Safe to call more than once (idempotent). Call from app launch.
    static func start() {
        let store = NSUbiquitousKeyValueStore.default

        if !observersInstalled {
            observersInstalled = true

            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { note in
                applyRemoteChange(note)
            }

            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: UserDefaults.standard,
                queue: .main
            ) { _ in
                pushLocalToCloud()
            }
        }

        // Pull anything iCloud already has (remote wins on launch), then push any
        // local-only values up so they propagate to other devices.
        store.synchronize()
        pullCloudToLocal(keys: syncedKeys)
        pushLocalToCloud()
    }

    /// Copy the given keys from iCloud into `UserDefaults` (only keys iCloud actually holds).
    private static func pullCloudToLocal(keys: [String]) {
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }

        for key in keys where keySet.contains(key) {
            guard let value = store.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }
    }

    /// Push every locally-set tracked key up to iCloud. Keys the user never set
    /// (still at their `@AppStorage` default) are absent from `UserDefaults` and
    /// are skipped, so we never clobber a remote value with a local default.
    private static func pushLocalToCloud() {
        guard !isApplyingRemoteChange else { return }
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        var didChange = false
        for key in syncedKeys {
            guard let local = defaults.object(forKey: key) else { continue }
            if !areEqual(store.object(forKey: key), local) {
                store.set(local, forKey: key)
                didChange = true
            }
        }
        if didChange { store.synchronize() }
    }

    private static func applyRemoteChange(_ note: Notification) {
        let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        pullCloudToLocal(keys: changedKeys ?? syncedKeys)
    }

    /// Loose equality for the property-list scalar types we store (String, Double,
    /// Bool wrapped in NSNumber). Used to avoid redundant writes / sync churn.
    private static func areEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x as NSObject, y as NSObject): return x.isEqual(y)
        default: return false
        }
    }
}
