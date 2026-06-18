import Foundation

/// Single source of truth for the app's currency formatting. Centralizes what
/// used to be a hardcoded `"USD"` scattered across ~25 files, so introducing a
/// per-user currency setting later is a one-line change here instead of an
/// app-wide find-and-replace.
enum AppCurrency {
    /// The active currency code. Currently fixed to USD; point this at an
    /// `@AppStorage`-backed setting to make the app currency configurable.
    static var code: String { "USD" }

    /// Shared currency `FormatStyle` for use in `Text(value, format:)`.
    static var style: FloatingPointFormatStyle<Double>.Currency { .currency(code: code) }
}

extension Double {
    /// Formats this value as the app's currency string, e.g. `"$1,234.56"`.
    var asCurrency: String { formatted(AppCurrency.style) }
}
