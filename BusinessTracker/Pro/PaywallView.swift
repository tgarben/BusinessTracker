import SwiftUI

/// The Pro upgrade sheet. Provider-agnostic — it drives `Entitlements`, which
/// talks to whichever `StoreProvider` is wired in. Prices shown are placeholders
/// (`ProPlan.placeholderPrice`) until the store layer supplies localized prices.
struct PaywallView: View {
    /// The feature the user tried to use, for a tailored header. Nil = generic.
    let context: ProFeature?

    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var entitlements

    @State private var selectedPlan: ProPlan = .annual

    private let brand = Color.indigo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    featureList
                    planPicker
                    subscribeButton
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Freelanced Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restore") {
                        Task { await entitlements.restore(); if entitlements.isPro { dismiss() } }
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(brand.gradient)
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: context?.icon ?? "crown.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: brand.opacity(0.3), radius: 14, x: 0, y: 8)

            Text(context.map { "Unlock \($0.title)" } ?? "Go Pro")
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text(context?.blurb ?? "Everything you need to bill clients and run the numbers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: Feature list

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(ProFeature.allCases.enumerated()), id: \.element) { index, feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(brand)
                        .frame(width: 28, height: 28)
                        .background(brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title).font(.subheadline.weight(.semibold))
                        Text(feature.blurb).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 10)
                if index < ProFeature.allCases.count - 1 {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Plan picker

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(ProPlan.allCases) { plan in
                planRow(plan)
            }
        }
    }

    private func planRow(_ plan: ProPlan) -> some View {
        let selected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? AnyShapeStyle(brand) : AnyShapeStyle(.tertiary))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.title).font(.subheadline.weight(.semibold))
                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.green, in: Capsule())
                        }
                    }
                    Text(plan.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(plan.placeholderPrice).font(.subheadline.weight(.bold))
                    Text(plan.unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? brand.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Subscribe

    private var subscribeButton: some View {
        Button {
            Task {
                await entitlements.purchase(selectedPlan)
                if entitlements.isPro { dismiss() }
            }
        } label: {
            ZStack {
                if entitlements.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedPlan == .lifetime ? "Unlock Lifetime" : "Start Free Trial")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(brand.gradient, in: RoundedRectangle(cornerRadius: 15))
        }
        .disabled(entitlements.isPurchasing)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            #if DEBUG
            Text("Demo build — no real charge. Purchase is simulated until the store layer is wired in.")
                .font(.caption2)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            #endif
            Text("Payment is charged to your Apple ID. Subscriptions auto-renew until cancelled. Manage in Settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            // TODO: link real Terms of Use (EULA) + Privacy Policy URLs — required by App Review.
            HStack(spacing: 14) {
                Text("Terms of Use")
                Text("Privacy Policy")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Upgrade CTA banner

/// The free → Pro upgrade call-to-action. A gradient card meant to live at the
/// top of Settings (under the profile header). Tapping it runs `action` — the
/// host opens the paywall. Doubles as the paywall test-launcher while
/// monetization is dormant (see `SettingsView`'s visibility rule).
struct ProUpgradeBanner: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Freelanced Pro")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Invoicing, estimates, reports & more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .indigo.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(context: .invoicing)
        .environment(Entitlements())
}
