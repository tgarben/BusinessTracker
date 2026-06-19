import SwiftUI

/// One of our other apps, promoted in Settings → "More from Garben Technologies".
///
/// TODO: fill in real `appStoreURL`s (and optionally drop real icon images into
/// Assets and set `iconAsset`) once each app's App Store listing is live.
/// Until an `appStoreURL` is set the row renders but is not tappable.
struct PromotedApp: Identifiable {
    let id = UUID()
    let name: String
    let tagline: String
    /// SF Symbol shown in the rounded app-icon tile when `iconAsset` is nil.
    let iconSymbol: String
    /// Optional image set name in Assets for a real app icon (preferred over the symbol).
    let iconAsset: String?
    let tint: Color
    /// App Store product URL. Nil until the listing is live (then `testFlightURL` is used).
    let appStoreURL: URL?
    /// Public TestFlight invite link (`https://testflight.apple.com/join/…`) for an
    /// app still in beta. Shown as a "Beta" row when `appStoreURL` is nil.
    let testFlightURL: URL?

    init(name: String, tagline: String, iconSymbol: String, iconAsset: String? = nil,
         tint: Color, appStoreURL: URL? = nil, testFlightURL: URL? = nil) {
        self.name = name
        self.tagline = tagline
        self.iconSymbol = iconSymbol
        self.iconAsset = iconAsset
        self.tint = tint
        self.appStoreURL = appStoreURL
        self.testFlightURL = testFlightURL
    }

    /// Where the row links to — App Store preferred, TestFlight as fallback.
    var link: URL? { appStoreURL ?? testFlightURL }
}

enum GarbenApps {
    /// The studio's other apps. Excludes Freelanced itself.
    /// Replace the placeholder taglines and add real `appStoreURL`s as they ship.
    static let all: [PromotedApp] = [
        PromotedApp(
            name: "CradleLight",
            tagline: "Night Feed & Holding Tracker",
            iconSymbol: "moon.stars.fill",
            iconAsset: "cradleLightLogo",
            tint: .blue,
            appStoreURL: URL(string: "https://apps.apple.com/us/app/cradlelight/id6766136937")
        ),
        PromotedApp(
            name: "Sipfolio",
            tagline: "Track and rate every drink you try",
            iconSymbol: "cup.and.saucer",
            iconAsset: "sipfolioLogo",
            tint: .green,
            appStoreURL: nil,                                   // TODO: set once it ships on the App Store
            testFlightURL: URL(string: "https://testflight.apple.com/join/QYM455vN")
        ),
    ]
}

/// The Settings section promoting the studio's other apps.
struct MoreAppsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            ForEach(GarbenApps.all) { app in
                row(for: app)
            }
        } header: {
            Text("More from Garben Technologies")
        } footer: {
            Text("Other apps we make. Tap to view on the App Store, or join a beta on TestFlight.")
        }
    }

    @ViewBuilder
    private func row(for app: PromotedApp) -> some View {
        let content = HStack(spacing: 12) {
            appIcon(app)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(app.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if app.appStoreURL != nil {
                badge("Get", icon: nil, tint: app.tint)
            } else if app.testFlightURL != nil {
                badge("Beta", icon: "airplane", tint: app.tint)
            } else {
                Text("Coming soon")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)

        if let url = app.link {
            Button { openURL(url) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// Trailing call-to-action pill ("Get" for the App Store, "Beta" for TestFlight).
    private func badge(_ text: String, icon: String?, tint: Color) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func appIcon(_ app: PromotedApp) -> some View {
        Group {
            if let asset = app.iconAsset, UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(app.tint.gradient)
                    .overlay(
                        Image(systemName: app.iconSymbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
