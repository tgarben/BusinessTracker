import SwiftUI
import Observation

/// The paid plans for Freelanced Pro. Display prices here are **placeholders** —
/// the real, localized prices come from the store layer (`Product.displayPrice`
/// in StoreKit 2, or RevenueCat's `Package`). The `productID`s must match what
/// you configure in App Store Connect.
enum ProPlan: String, CaseIterable, Identifiable {
    case monthly, annual, lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:  return "Monthly"
        case .annual:   return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    /// Placeholder price string. Replace with the store-provided localized price.
    var placeholderPrice: String {
        switch self {
        case .monthly:  return "$4.99"
        case .annual:   return "$29.99"
        case .lifetime: return "$49.99"
        }
    }

    var unit: String {
        switch self {
        case .monthly:  return "/ month"
        case .annual:   return "/ year"
        case .lifetime: return "one-time"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly:  return "Cancel anytime"
        case .annual:   return "Save ~50% vs monthly · 7-day free trial"
        case .lifetime: return "Pay once, yours forever"
        }
    }

    var isBestValue: Bool { self == .annual }

    /// App Store Connect product identifier. TODO: confirm these match the products
    /// you create (and the RevenueCat offering, if you go that route).
    var productID: String {
        "com.garbenTechnologies.BusinessTracker.pro.\(rawValue)"
    }
}

/// A capability gated behind Freelanced Pro. Used both to decide access and to
/// give the paywall context ("Invoicing is a Pro feature").
enum ProFeature: String, CaseIterable, Identifiable {
    case invoicing
    case quotes
    case reports
    case dataExport
    case unlimitedClients

    var id: String { rawValue }

    /// Short title for the paywall header ("Unlock <title>").
    var title: String {
        switch self {
        case .invoicing:        return "Invoicing"
        case .quotes:           return "Estimates"
        case .reports:          return "Reports & Analytics"
        case .dataExport:       return "Data Export"
        case .unlimitedClients: return "Unlimited Clients"
        }
    }

    var blurb: String {
        switch self {
        case .invoicing:        return "Create, brand, and send professional invoice PDFs."
        case .quotes:           return "Send estimates and convert them to invoices in a tap."
        case .reports:          return "Date-range reports, client P&L, and tax set-aside."
        case .dataExport:       return "Export your time, mileage, and expenses to CSV."
        case .unlimitedClients: return "Track as many clients and projects as you need."
        }
    }

    var icon: String {
        switch self {
        case .invoicing:        return "doc.text.fill"
        case .quotes:           return "list.clipboard.fill"
        case .reports:          return "chart.bar.fill"
        case .dataExport:       return "square.and.arrow.up.fill"
        case .unlimitedClients: return "person.2.fill"
        }
    }
}

// MARK: - Store provider seam

/// The boundary RevenueCat **or** StoreKit 2 plugs into. `Entitlements` talks only
/// to this protocol, so swapping providers never touches feature-gating code.
///
/// To go live, implement one of these and hand it to `Entitlements(provider:)`:
/// - **StoreKit 2:** wrap `Product`, `Transaction.currentEntitlements`, `product.purchase()`.
/// - **RevenueCat:** wrap `Purchases.shared` — `customerInfo.entitlements`, `purchase(package:)`.
protocol StoreProvider: Sendable {
    /// Whether the user currently owns the Pro entitlement (any qualifying product).
    func isProActive() async -> Bool
    /// Attempt a purchase; returns the resulting Pro state.
    func purchase(_ plan: ProPlan) async throws -> Bool
    /// Restore prior purchases; returns the resulting Pro state.
    func restore() async throws -> Bool
}

/// No-op provider used until a real store layer is wired in. Simulates a
/// successful purchase so the paywall → unlock flow is testable end-to-end.
/// **Replace before shipping paid features.**
struct StubStoreProvider: StoreProvider {
    func isProActive() async -> Bool { false }
    func purchase(_ plan: ProPlan) async throws -> Bool {
        try? await Task.sleep(for: .milliseconds(400))   // mimic store round-trip
        return true
    }
    func restore() async throws -> Bool { false }
}

// MARK: - Entitlements (single source of truth)

/// App-wide source of truth for "is this user Pro?". Inject once at the app root
/// and read it via `@Environment(Entitlements.self)`. Feature code asks
/// `isProEffective`; it never knows or cares which store backs it.
@MainActor
@Observable
final class Entitlements {

    /// ⚑ LAUNCH SWITCH. While `false`, monetization is completely dormant —
    /// every feature is unlocked, no paywall ever appears, the client cap is off,
    /// and the Settings "Subscription" section is hidden. Develop and test freely.
    ///
    /// **Flip to `true` right before App Store submission** — and only after you've
    /// wired a real `StoreProvider` (StoreKit 2 / RevenueCat) and created the
    /// products in App Store Connect. Shipping `true` with `StubStoreProvider`
    /// would show a fake paywall to real users.
    static let monetizationEnabled = false

    /// True once a qualifying purchase is confirmed by the store layer.
    private(set) var isPro: Bool = false

    /// True while a purchase/restore is in flight (drives paywall spinners).
    private(set) var isPurchasing = false

    private let provider: StoreProvider

    /// Free-tier client cap. Past this, adding a client prompts the paywall.
    static let freeClientLimit = 2

    init(provider: StoreProvider = StubStoreProvider()) {
        self.provider = provider
        #if DEBUG
        debugProOverride = UserDefaults.standard.bool(forKey: "debug_proOverride")
        #endif
    }

    #if DEBUG
    /// Dev-only switch (toggle in Settings) to exercise Pro flows before the
    /// store layer exists. Persisted so it survives relaunches during testing.
    var debugProOverride: Bool = false {
        didSet { UserDefaults.standard.set(debugProOverride, forKey: "debug_proOverride") }
    }
    #endif

    /// The value feature-gates should check. Folds in the launch switch + DEBUG override.
    var isProEffective: Bool {
        if !Self.monetizationEnabled { return true }   // dormant until launch — everything unlocked
        #if DEBUG
        if debugProOverride { return true }
        #endif
        return isPro
    }

    /// Whether a client can be created given how many already exist.
    func canCreateClient(currentCount: Int) -> Bool {
        isProEffective || currentCount < Self.freeClientLimit
    }

    // MARK: Store lifecycle (delegates to the provider)

    /// Refresh entitlement state from the store. Call on launch + on foreground.
    func refresh() async {
        let active = await provider.isProActive()
        isPro = active
    }

    func purchase(_ plan: ProPlan) async {
        isPurchasing = true
        defer { isPurchasing = false }
        if let result = try? await provider.purchase(plan) {
            isPro = result
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        if let result = try? await provider.restore() {
            isPro = result
        }
    }
}

// MARK: - Paywall presentation helper

extension View {
    /// Presents the paywall whenever `item` is non-nil. Attach once per container
    /// that has gated buttons; set `item = .someFeature` to trigger it.
    func proPaywall(_ item: Binding<ProFeature?>) -> some View {
        sheet(item: item) { feature in
            PaywallView(context: feature)
        }
    }
}
