import Foundation

/// Single source of truth for the app's currency formatting. Centralizes what
/// used to be a hardcoded `"USD"` scattered across ~25 files, so introducing a
/// per-user currency setting later is a one-line change here instead of an
/// app-wide find-and-replace.
enum AppCurrency {
    /// UserDefaults key (synced via CloudKeyValueSync). Settings binds an
    /// `@AppStorage("app_currencyCode")` picker to this.
    static let storageKey = "app_currencyCode"

    /// The active currency code, read live from the user's setting (default USD).
    static var code: String { UserDefaults.standard.string(forKey: storageKey) ?? "USD" }

    /// Shared currency `FormatStyle` for use in `Text(value, format:)`.
    static var style: FloatingPointFormatStyle<Double>.Currency { .currency(code: code) }

    /// Currency codes offered in the Settings picker.
    static let supported: [String] = [
        "USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY", "INR",
        "MXN", "BRL", "NZD", "SEK", "NOK", "DKK", "ZAR", "SGD", "HKD", "AED"
    ]

    /// Localized name for a code, e.g. "USD — US Dollar".
    static func displayName(_ code: String) -> String {
        if let name = Locale.current.localizedString(forCurrencyCode: code) {
            return "\(code) — \(name)"
        }
        return code
    }
}

extension Double {
    /// Formats this value as the app's currency string, e.g. `"$1,234.56"`.
    var asCurrency: String { formatted(AppCurrency.style) }
}
