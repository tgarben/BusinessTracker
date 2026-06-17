# BusinessTracker / Freelanced — Project Context

## What this is
A SwiftUI app for small business owners and contract workers to track time, mileage, expenses, and income. Built by Tyler with his friend/co-founder (50% stakeholder) who is the primary end user and provides product feedback after testing builds. App name may be changing to **Freelanced** — widget extension is already named `FreelancedWidget`.

## Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData + CloudKit (private database, syncs across devices when signed into iCloud)
- **Target:** iOS 26 minimum (use iOS 26 APIs freely)
- **Future platforms:** macOS (not yet). **iPad: supported** — `ContentView` branches on `horizontalSizeClass`: iPhone (`.compact`) uses the bottom `TabView`; iPad (`.regular`) uses a `NavigationSplitView` (sidebar + detail). See the iPad section.
- **Git:** Local only (`main` branch), no remote configured

## Project location
`/Users/tylergarben/Desktop/BusinessTracker`

Working directly off `main` — no feature branches at the moment (Tyler's home machine handles branching separately).

---

## Feature status

| Feature | Status |
|---|---|
| App shell (TabView, SwiftData container) | ✅ Done |
| Home Screen | ✅ Done (personalized, reorderable, configurable quick actions) |
| Time Tracking | ✅ Done |
| Mileage Tracking | ✅ Done |
| Expense Tracking | ✅ Done (multi-receipt, optional client link, expense presets) |
| Clients Tab | ✅ Done (list + detail with photo, income + time + invoice sections, inline project creation) |
| Income Tracking | ✅ Done (logged per-client from Clients tab; IncomeEntry model fully wired) |
| Reports & Analytics | ✅ Done (3×2 glance, fuel analysis, mileage IRS deduction card, tax set-aside, top clients, client P&L, date range picker, PDF export via ShareLink) |
| Invoicing | ✅ Done (full professional invoice: business info from Settings, customer billing details from Client, time entries + manual line items w/ qty/unit price, discount, sales tax, payment terms/instructions/methods, PO#, multi-page PDF, paid/unpaid, Create Invoice quick action) |
| Settings & Profile | ✅ Done (Profile page with avatar header; presets management; all config sections) |
| Recently Deleted (soft-delete) | ✅ Done (30-day trash + restore for all six record types; Settings → Recently Deleted) |
| iCloud Sync | ✅ Done (confirmed working on device 2026-06-13) |
| Quote / Estimate generator | ⬜ Planned (Jack's idea — pre-sale counterpart to invoicing; reuse line items, business/customer info, PDF; "convert to invoice" action) |
| Package Tracking | ⬜ Future (API integration) |
| Home Screen Widgets | ✅ Done (medium 4-action + small single-action quick-action widgets; read-only Quarterly Tax Due Dates widget; Live Activity on timer start) |
| Live Activities | ✅ Done (Dynamic Island + lock screen banner while timer runs; starts when app foregrounds after widget tap) |
| Lock Screen Actions | ⬜ Deferred (built and removed — requires server push-to-start to launch Live Activity without opening app; revisit when MRR justifies Firebase Blaze) |
| Shortcuts / Siri | ✅ Done (App Intents for Start Timer, Log Time, Log Trip, Add Expense; auto-registered AppShortcuts with Siri phrases) |
| Tax deadline reminders | ✅ Done (opt-in local notifications a week + day before each quarterly IRS deadline) |
| Pro tier (paid) | ⬜ Future |

---

## Tab bar navigation

**Current tabs:** Home · Time · Mileage · Expenses · Clients (5 tabs, at iOS limit)

- **Settings** is accessible via a **profile icon** (`person.crop.circle`) in the **top-left toolbar on every screen** — opens as a sheet (alone on the left; other actions go top-right)
- **Reports** is accessible via a `chart.bar` toolbar button on the **Home screen** — opens as a sheet with drag indicator
- Tab order reflects daily-use priority: Home first, then the three active tracking tabs, Clients last

---

## Data models

- **`Client`** — `name`, `photoData: Data? = nil`, plus billing/customer fields `companyName`, `billingAddress`, `email`, `phone` (all `String = ""`, shown as "bill to" on invoices). Relationships: `projects` (cascade delete), `timeEntries` (nullify), `incomeEntries` (nullify), `expenses` (nullify), `timePresets` (nullify), `invoices` (cascade delete).
- **`Project`** — `name`, `hourlyRate`, belongs to `Client`
- **`TimeEntry`** — `date`, `client?`, `project?`, `hours`, `hourlyRate` (snapshot), `notes`, `invoice?` (nullify on invoice delete)
- **`Invoice`** — `invoiceNumber: Int`, `issueDate`, `dueDate`, `notes`, `isPaid: Bool`, `paidDate?`, `additionalAmount`/`additionalDescription` (legacy single extra, kept for migration), `discountAmount: Double`, `taxRate: Double` (percent), `paymentTerms`, `paymentInstructions`, `acceptedPayments`, `poNumber`, `client?`, `timeEntries` (nullify), `lineItems` (cascade → `InvoiceLineItem`). Computed: `subtotal` (time earnings + line items + legacy extra), `discountedSubtotal` (subtotal − discount), `taxAmount` (discounted × taxRate%), `total` (final amount due), `formattedNumber` = "INV-001". PDF via `ImageRenderer` → `makeInvoicePDF()`. **`subtotal` is pre-tax/discount; use `total` for the amount due** (InvoiceRow + detail show `total`).
- **`InvoiceLineItem`** — manual invoice line: `itemDescription`, `quantity: Double`, `unitPrice: Double`, `sortOrder`, `invoice?`. Computed `lineTotal = quantity × unitPrice`. Coexists with time-entry billing.
- **`TimePreset`** — `name`, `client?`, `project?`, `sortOrder`, `hourlyRateOverride?`, `notesTemplate`
- **`MileageTrip`** — `date`, `startLocation`/`endLocation` (short display labels from `shortAddress`), `startAddress`/`endAddress` (full addresses for CSV export, captured via `fullAddress(_:)` at save), `miles`, `purpose`, `notes`, `waypoints: [String] = []` (intermediate stops, in order). Computed `reimbursementAmount` using `ratePerMile` (IRS rate, currently 0.70), `allStops`, `routeDescription`, `startAddressForExport`/`endAddressForExport` (full address, else display label for older trips).
- **`MileagePreset`** / **`ExpensePreset`** — standalone saved templates (no relationships). MileagePreset: `name`, `startLocation`, `endLocation`, `purpose`, `notes`, `sortOrder`. ExpensePreset: `name`, `amount: Double?` (nil = variable), `category`, `notes`, `sortOrder`. Registered in the app Schema. Managed from Settings → Presets & Quick-Fill.
- **`Expense`** — `date`, `amount`, `category`, `notes`, `receiptImageData?` (legacy — kept for migration), `receiptImagesData: [Data]` (current multi-image storage), `client?` (optional link). Categories defined in `Expense.categories`. Helper statics: `categoryIcon(_:)`, `categoryColor(_:)`
- **`IncomeEntry`** — `date`, `source`, `amount`, `notes`, `client?`. Client is required in the UI (logged from ClientDetailView) but optional at the model level for migration safety.
- **`TimerState`** — `@Observable` class (not SwiftData). Persists active timer start date to App Group `UserDefaults` so timer survives backgrounding and is readable by the widget extension. Starts/ends `Activity<TimerActivityAttributes>` for the Live Activity. `syncFromSharedStore()` method syncs from the App Group store on foreground — call this to pick up timers written by widget intents. Also holds `pendingWidgetAction: WidgetAction?` for routing widget deep links to the correct sheet.
- **`WidgetAction`** — enum in `TimerState.swift`: `.startTimer`, `.logTime`, `.logTrip`, `.addExpense`, `.createInvoice`. Set by `BusinessTrackerApp.handleWidgetDeepLink(_:)`, consumed by `ContentView`.
- **`TimerActivityAttributes`** — `ActivityAttributes` struct in `BusinessTracker/Models/TimerActivityAttributes.swift`. `ContentState` holds `startDate: Date`. Also duplicated (identical) in `FreelancedWidget/FreelancedLiveActivity.swift` — the two targets are separate Swift modules so they cannot share the type directly. **Keep both in sync.**

---

## iCloud Sync — current state & notes

- **Container:** `iCloud.com.garbenTechnologies.BusinessTracker`
- **Bundle ID:** `com.garbenTechnologies.BusinessTracker`
- **Entitlements file:** `BusinessTracker/BusinessTracker.entitlements` — has `com.apple.developer.icloud-container-identifiers` + `com.apple.developer.icloud-services: CloudKit`
- **ModelContainer init:** `BusinessTrackerApp.swift` tries CloudKit private DB first; falls back to local-only if unavailable (simulator, not signed in, etc.)
- **Xcode capability:** iCloud → CloudKit must be enabled in Signing & Capabilities with container `iCloud.com.garbenTechnologies.BusinessTracker`
- **Known limitation:** CloudKit does not support `Decimal` natively — if sync issues arise, monetary fields may need to be stored as `Double` (cents as Int) with a migration plan
- Sync only works on a real device signed into iCloud; simulator always uses the local fallback

### Settings / business-info sync (NSUbiquitousKeyValueStore)

SwiftData models sync via CloudKit, but **business info, profile, and financial defaults live in `@AppStorage` (`UserDefaults.standard`), which is device-local.** `Settings/CloudKeyValueSync.swift` bridges a fixed allow-list of those keys to `NSUbiquitousKeyValueStore` (iCloud key-value store) so they follow the user across devices.

- **`CloudKeyValueSync.start()`** is called from `BusinessTrackerApp` on both the main `.task` and the onboarding `.task` (so a 2nd device pre-fills onboarding from iCloud). Idempotent.
- **Direction:** observes `NSUbiquitousKeyValueStore.didChangeExternallyNotification` (pull iCloud→`UserDefaults`, which `@AppStorage` re-renders from) and `UserDefaults.didChangeNotification` (push local→iCloud). An `isApplyingRemoteChange` guard prevents feedback loops.
- **Launch merge:** pull (remote wins on conflict) then push (uploads local-only keys). Keys never set by the user are absent from `UserDefaults` (still at `@AppStorage` default) so they're skipped — a local default never clobbers a remote value.
- **Synced keys** (`CloudKeyValueSync.syncedKeys`): `user_name`, `user_lastName`, `user_primaryUse`; all `business_*` (incl. invoicing defaults); `mileage_ratePerMile`, `default_hourlyRate`, `report_mpg`, `report_gasPrice`, `tax_selfEmploymentRate`, `tax_incomeBracketRate`, `tax_businessStructure`; `mileage_purposePresets`, `mileage_favoriteAddresses`.
- **Intentionally NOT synced** (device-specific): `home_*` layout/section order, widget config, notification toggles (`tax_remindersEnabled`, `expense_presetInstantSave`), `hasCompletedOnboarding`.
- **Entitlement:** `com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)com.garbenTechnologies.BusinessTracker` added to `BusinessTracker.entitlements`. Like CloudKit, only works on a real device signed into iCloud.
- **To add a new synced setting:** append its key to `CloudKeyValueSync.syncedKeys`. Only property-list scalars (String/Double/Bool/Data) sync cleanly.

---

## iPad layout — current state & notes

- **Navigation:** `ContentView` uses a single plain `TabView` (no size-class branching, no `NavigationSplitView`). On iPhone this renders the bottom tab bar; on iPad iOS 26 the **same** `TabView` automatically renders the App Store-style floating **top tab bar**. We deliberately do **not** apply `.tabViewStyle(.sidebarAdaptable)` — that would force an iPad sidebar, which was tried and rejected in favor of the top tab bar.
- **`AppSection` enum** (`ContentView.swift`) is the single source of truth for the five destinations (`home/mileage/time/expenses/clients`) — `title`, `icon`, and a `@ViewBuilder destination`. The `TabView` `ForEach`es over it.
- Each section root (`HomeView`, `MileageView`, …) wraps itself in its own `NavigationStack`; the `TabView` preserves per-tab state, so drill-down nav and scroll position survive tab switches.
- Shared `.sheet`s (timer, log time/trip, add expense, create invoice) and the `pendingWidgetAction` routing live on the `TabView`, so widget/Shortcut deep links work identically on both idioms.
- **Layout polish for wide screens:** Home Quick Actions grid uses `GridItem(.adaptive(minimum: 150))` (flows to 5 columns on iPad, stays 2-up on iPhone). Onboarding (`OnboardingScaffold`) is capped at `maxWidth: 540` centered so fields don't stretch edge-to-edge.
- **Timer sheet detents:** `TimerSheet` owns its own detents via the private `PhoneSheetDetents` modifier: **iPhone gets `[.medium, .large]`; iPad gets NO detents** so it presents as the standard centered form sheet like every other sheet (forcing `presentationDetents` on iPad produced an odd partial-height card). The three callers (`ContentView`, `HomeView`, `TimeTrackingView`) just present `TimerSheet()` with no detents of their own — don't re-add detents at the call site.
  - **Auto-expand to `.large` (iPhone):** `PhoneSheetDetents` takes a `selection` binding (`sheetDetent`). `TimerSheet.syncDetent()` sets it to `.large` when `prefersLargeDetent` (not running + project picker visible, i.e. a client-with-projects / preset is selected and the form is tall enough to clip at `.medium`), else `.medium`. Driven by `.onAppear` + `.onChange` of `selectedClient`/`selectedProject`/`timerState.isRunning`. The user can still drag down manually.
  - **GOTCHA:** the modifier keys off `UIDevice.current.userInterfaceIdiom == .phone`, **NOT `horizontalSizeClass`**. Content inside a *presented sheet* on iPad reports a `.compact` horizontal size class (the sheet container is a narrow compartment), so a size-class check wrongly applies the phone detents on iPad. Use the device idiom for "is this an iPad" decisions that are read from inside a sheet.
- **Future iPad polish (optional):** true two-column drill-down (master/detail) within Clients/history, multi-window. Not done.

### Onboarding prefill from iCloud (new-device experience)

When a returning user installs on a new device, onboarding pre-fills from the iCloud-synced settings (see `CloudKeyValueSync`) so they don't re-type everything:
- `BusinessTrackerApp` calls `CloudKeyValueSync.start()` on the onboarding `.task` too, which pulls iCloud key-values into `UserDefaults`.
- **`BusinessInfoPage`** binds its `TextField`s directly to the `business_*` `@AppStorage` keys, so values appear live as soon as iCloud delivers them.
- **`AboutYouPage`** seeds local `@State` from the stored keys in `.onAppear`, **and** has `.onChange` observers (`storedName`/`storedLastName`/`primaryUse`) that re-seed any field the user hasn't touched yet — needed because `NSUbiquitousKeyValueStore` downloads asynchronously and values can land *after* the page first appears.
- **`iCloudPrefillBadge`** (a small "Filled in from your iCloud account" pill) shows on About You when a name was restored, and on Business when any business field was restored.

## Home Screen — key decisions & current state

- **Personalized greeting:** "Good morning, Jack" — reads `@AppStorage("user_name")`
- **Reorderable sections:** Three sections (Quick Actions, Today, This Week) stored as an ordered comma-separated string in `@AppStorage("home_sectionOrder")`. Active timer card is always pinned at top.
- **Configurable quick actions:** Enabled actions + order stored in `@AppStorage("home_quickActionOrder")` and `@AppStorage("home_quickActionEnabled")`. Defined by `QuickAction` enum in `HomeView.swift`.
- **Quick Actions:** Start Timer (indigo), Log Time (indigo), Log Trip (blue), Add Expense (red), Create Invoice (purple). 2-wide `LazyVGrid` of individually rounded cards.
- **Zero quick actions:** if `home_quickActionEnabled` is empty, the Quick Actions section is completely hidden from the home screen. In `HomeLayoutEditor`, the Quick Actions row in Section Order shows "No actions enabled" in tertiary text and its drag handle is hidden.
- **Customize Home sheet:** `slider.horizontal.3` toolbar button → `HomeLayoutEditor` sheet. Always in edit mode (`.constant(.active)`). Two sections: Section Order (drag to reorder) and Quick Actions (toggle + drag to reorder). Done saves, Cancel discards. No minimum action count enforced.
- **Reports button:** `chart.bar` toolbar button (top-right, alongside customize button) → `ReportsView` as a sheet with `.presentationDragIndicator(.visible)`
- **Section rendering:** Each section is a single `List` row (`HomeSectionCard`) with a clear background so drag-to-reorder in the editor works correctly. Home uses `.listStyle(.plain)` with `Color(.systemGroupedBackground)`.
- **Today at a glance:** three stat cells (hours, miles, spend). Stats go muted when empty.
- **This week:** hours + earnings cells with per-day average subtitle.
- `ActiveTimerCard` is `internal` (not `private`) so both `HomeView` and `TimeTrackingView` can use it.

**`@AppStorage` keys for Home:**
- `user_name` — first name for greeting (Home greeting uses first name ONLY)
- `user_lastName` — last name; appears on invoices + data exports only, never the Home greeting. `userFullName()` free function in `SettingsView.swift` builds "First Last" from UserDefaults for non-View code (invoice PDF, Reports PDF, CSV header).
- `user_primaryUse` — **"App Focus"** in Settings: now **multi-select**, comma-separated rawValues from `["Time Tracking","Mileage","Expenses","Invoicing"]` (tappable chips, not a single-select picker). Drives Home section order via `HomeSection.orderString(forFocuses:)` — tailors the order only when exactly one focus is selected, else uses the balanced default. (Onboarding still writes a single legacy value via `orderString(forUse:)`, which remains for back-compat and maps "Time & Billing"→"Time Tracking".)
- `home_sectionOrder` — comma-separated `HomeSection` rawValues
- `home_quickActionOrder` — comma-separated `QuickAction` rawValues (display order)
- `home_quickActionEnabled` — comma-separated enabled `QuickAction` rawValues

**Default section orders by primary use:**
- Mixed: `quickActions,todayGlance,thisWeek`
- Time & Billing: `thisWeek,quickActions,todayGlance`
- Mileage: `todayGlance,thisWeek,quickActions`
- Expenses: `todayGlance,quickActions,thisWeek`

## Time Tracking — key decisions & current state

- **Rate lives on `Project`**, not `Client`
- **Two log modes:** Duration (type hours) or Start & End (pick times, hours calculated)
- **Timer flow:**
  - Pick client + project (or leave blank = uncategorized) before starting
  - Preset chips shown as horizontal scroll for quick pre-start selection
  - Stop → auto-saves immediately with known client/project/rate/notes template
  - Animated ✓ confirmation shown ~1.8s then sheet auto-dismisses
  - No post-stop form unless user taps into the saved entry to edit
- **Presets** (`TimePreset`): named combos of client + project + optional rate override + optional notes template. Managed from **Settings → Presets & Quick-Fill → Time Presets** (presented as a sheet) or the prominent "Manage Presets" / "Create a Preset" button in `TimerSheet` — both open `PresetsView`. (The old `⋯` toolbar button on `TimeTrackingView` was removed.) Preset chips also appear in `LogTimeView` and `TimerSheet`; active preset chip is highlighted indigo. Reorderable.
- **Clients & Projects** managed from the Clients tab (not Settings)
- **Tap any entry** to open `TimeEntryEditView` — edit all fields including notes
- **Week summary card** at top of Time Tracking screen — hidden when no entries exist (only `ContentUnavailableView` shown)
- **History button** (top-right toolbar — app-wide convention: profile icon alone top-left, actions top-right) → `TimeHistoryView`: months listed as rows with month name bold + hours badge (indigo) + entry count + earnings → `TimeMonthDetailView`: that month's entries with summary card + grouped-by-day list, tap to edit (`TimeEntryEditView`), swipe to delete. `TimeEntryRow` is `internal` (shared by `TimeTrackingView` + `TimeMonthDetailView`).
- **Swipe to delete** shows confirmation dialog before deleting

## Mileage Tracking — key decisions & current state

- **Two entry modes:** Address (MapKit autocomplete + MKDirections driving distance) or Manual (type miles, works offline)
- **Address autocomplete:** uses `AddressSearchView` which wraps `AddressSearcher` (MKLocalSearchCompleter). Callback delivers a `LocationResult` enum — either `.completion(MKLocalSearchCompletion)` or `.coordinate(CLLocationCoordinate2D, label: String)`.
- **Current location:** "Use Current Location" row at the top of `AddressSearchView`. Uses `LocationManager` (@Observable, CLLocationManagerDelegate) to request location, then CLGeocoder to reverse-geocode to a label. Requires `NSLocationWhenInUseUsageDescription` (already in build settings).
- **Address label format:** stored addresses use `shortAddress(_:)` helper — strips country from MapKit subtitle, keeps city + state for POIs (drops street from subtitle so result is "Place Name, City, State"), keeps "Street, City, State" for plain addresses.
- **Round trip toggle** appears once a distance is calculated; shows each-way + total breakdown
- **Month summary card** at top of Mileage screen — hidden when no trips exist (only `ContentUnavailableView` shown)
- **History button** (toolbar) → `MileageHistoryView`: months listed as rows with month name bold + miles badge + trip count — `MileageMonthDetailView`: that month's trips with summary card + grouped list
- **Tap any trip** (in both `MileageView` and `MileageMonthDetailView`) to open `MileageTripEditView`
- **`MileageTripEditView`** has a Manual / Address mode toggle matching `LogTripView` — switch to Address mode to pick new locations and recalculate distance
- **Swipe to delete** shows confirmation dialog before deleting
- **Trip purpose presets:** quick-fill chips below the purpose field in `LogTripView`/`MileageTripEditView`, backed by `@AppStorage("mileage_purposePresets")` (comma-separated; defaults Client Visit, Office, Airport, Errand, Medical). Managed in Settings → Trip Purposes (`PurposePresetsEditor`). Shared `PurposeChipsRow` view in `MileagePurposePresets.swift`.
- **Location favorites:** `AddressSearchView` shows a Favorites section above Recent. Swipe-leading on a recent = star it; swipe-trailing on a favorite = unstar. Stored in `@AppStorage("mileage_favoriteAddresses")` as JSON via `RecentAddressStore` (which now holds both `recents` and `favorites`).
- **Mileage presets:** route templates (`MileagePreset`). Chips at the top of the Distance section in `LogTripView` — tapping one pre-fills purpose/notes + start/end, then geocodes both endpoints (`CLGeocoder`) and auto-calculates driving distance; falls back to manual mode if geocoding fails. Managed in Settings → Mileage Presets.
- **Multi-stop routes:** address mode supports intermediate stops. `TripStop` array in `LogTripView`; "Add Stop" inserts a searchable stop row between From and To. Distance = sum of legs via `calculateDrivingMiles(stops:)`. Stops saved to `MileageTrip.waypoints`; `TripRow` shows a "via …" line. Manual mode stays start/end + typed miles (no waypoints).

## Expense Tracking — key decisions & current state

- **Categories:** Supplies, Equipment, Software, Travel, Meals, Marketing, Utilities, Rent, Insurance, Other — each has an SF Symbol icon and color defined in `Expense` statics
- **Client link:** optional — expense can be standalone or linked to a `Client`
- **Multiple receipts:** attach multiple images per expense via `PhotosPicker` (library) or `CameraView` (camera). Stored as `receiptImagesData: [Data]` on the model. Thumbnails shown in a horizontal scroll row in Add/Edit views; each has an × remove button. `ExpenseRow` shows a paperclip icon + count badge.
- **Legacy migration:** old `receiptImageData: Data?` field is preserved on the model. `ExpenseEditView` migrates it into `receiptImagesData` on first open and clears the old field on save.
- **Amount field:** displays a `$` prefix label beside the text input in both Add and Edit views. Parsed via `Double(string:)` on save.
- **Tap any entry** to open `ExpenseEditView`
- **Expense presets:** template chips at the top of `AddExpenseView` (`ExpensePreset`) pre-fill category, amount (when fixed), and notes. Managed in Settings → Expense Presets (`ExpensePresetsView`). `AddExpenseView(prefillPreset:)` opens pre-filled.
- **Speed-dial FAB:** `ExpensesView` has a floating red **+** button bottom-right (mirrors the Time tab's floating play button). Tapping it springs open a speed-dial of expense-preset shortcuts + a "New Expense" option; the + rotates 45° to an ✕, with a tap-scrim to dismiss. Default: a preset opens the pre-filled Add Expense form. With `@AppStorage("expense_presetInstantSave")` on (Settings → Presets & Quick-Fill → "Instant-Log Expense Presets"), tapping a fixed-amount preset saves immediately; presets without a fixed amount still open the form. If no presets exist, the FAB just opens a blank Add Expense.
- **Month summary card** shows total spend + transaction count — hidden when no expenses exist (only `ContentUnavailableView` shown)
- **Swipe to delete** shows confirmation dialog before deleting
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` must be in Info.plist for camera/photo on real device

## Clients Tab — key decisions & current state

- **Purpose:** central hub for all client relationships — view income received and time worked per client
- **`ClientsView`** (tab root): list of clients sorted by name. Each cell shows circular avatar (photo or indigo initials), client name, hours tracked + payment count, and a green total earnings badge (time earnings + income entries combined).
- **`ClientDetailView`**: large centered 100pt circle avatar at top, client name, total earned (green) + hours tracked (indigo) stats. Sections: Invoices, Income, Expenses, Time Entries. `@Query` with `#Predicate` filters all by `persistentModelID` for immediate reactivity.
- **Invoices section:** list of `InvoiceRow` (invoice #, amount badge orange/green, dates, paid status). `+` opens `CreateInvoiceView`. Tap to open `InvoiceDetailView`. Swipe to delete (warns linked entries become unbilled).
- **Income section:** list of `IncomeEntry` rows for this client. `+` button in section header opens `LogIncomeForClientView`. Tap to edit via `IncomeEditView`, swipe to delete with confirmation.
- **Time Entries section:** list of `ClientTimeEntryRow` (project name, hours, earnings badge, date). Tap to edit via `TimeEntryEditView`, swipe to delete with confirmation.
- **`LogIncomeForClientView`:** income log sheet with client pre-shown (not a picker). Date, amount (`$` prefix), source field + 5 preset chips (Invoice Payment, Retainer, Project Fee, Consulting, Other), notes.
- **`AddEditClientView`:** photo picker at top (shows live avatar preview, initials fallback). Eagerly inserts a new `Client` into model context on appear for "New Client" flow — Projects section is available immediately so projects can be added before saving. Cancel deletes the in-progress client. Edit mode works identically.
- **`ClientAvatar`:** shared `internal` struct (circle, photo or indigo initials fallback) used in `ClientsView`, `ClientDetailView`, `AddEditClientView`, and `LogIncomeForClientView`.
- **Color:** green for income amounts, indigo for time/hours — consistent with app-wide color coding.
- **Swipe to delete clients** (from `ClientsView`) warns that projects will also be deleted.

## Invoicing — key decisions & current state

- **Three info sources combine into each invoice:**
  1. **Your business info** — standardized in Settings → Business Information + Invoicing Defaults (`@AppStorage` keys `business_name`, `business_address`, `business_phone`, `business_email`, `business_website`, `business_taxID`, `business_defaultTaxRate`, `business_defaultPaymentTerms`, `business_acceptedPayments`, `business_paymentInstructions`). Rendered as the "from" header + tax ID + payment defaults.
  2. **Customer info** — from the `Client` (`name`, `companyName`, `billingAddress`, `billingAddress2`, `email`, `phone`), edited in `AddEditClientView` → Billing Details. Rendered as "BILL TO".
- **Address entry:** business address (Settings) and client billing address use the shared **`AddressEntryField`** (`Mileage/AddressEntryField.swift`) — an editable street line with a 🔍 button that opens the same `AddressSearchView` MapKit autocomplete used by Mileage (fills line 1 via `fullAddress(_:)`), plus a second line for Apt/Suite/Unit. Business line 2 = `@AppStorage("business_address2")`; client line 2 = `Client.billingAddress2`. Both render on the invoice PDF (`BusinessInfo.address2` + `client.billingAddress2`).
  3. **Per-invoice data** — entered in `CreateInvoiceContent`.
- **Line items = time entries + manual `InvoiceLineItem`s.** Time-entry billing (select unbilled entries) is unchanged; manual line items add arbitrary products/services with description, quantity, unit price. The PDF merges both into one table via `invoicePDFRows(for:)` → `[InvoicePDFRow]`.
- **Totals:** `subtotal` → minus `discountAmount` → `discountedSubtotal` → plus `taxAmount` (`taxRate%`) → `total`. New invoices pre-fill tax rate / terms / accepted payments / instructions from the business defaults (editable per invoice).
- **`CreateInvoiceContent`** pre-fills on first `onAppear` only (guarded by `didPrefill`) so user edits aren't clobbered. `DraftLineItem` is the editing struct; valid drafts (non-empty description + non-zero total) become `InvoiceLineItem`s on save.
- **PDF** (`makeInvoicePDF`): multi-page, letter size. `BusinessInfo.load(fallbackName:)` reads the business `@AppStorage` keys from `UserDefaults.standard` (falls back to `user_name`). `firstPageMax = 6` rows (taller header), `contPageMax = 10`. Footer (totals + payment + notes + tax ID) renders on the last page only.

## Income Tracking — key decisions & current state

- Income is always tied to a client — logged from `ClientDetailView`, never standalone
- **`IncomeEntry`** model: `date`, `source`, `amount`, `notes`, `client?` (optional at model level for migration safety, required in UI)
- **Source presets:** Invoice Payment, Retainer, Project Fee, Consulting, Other — shown as tappable chips that pre-fill the source field (still editable)
- **`IncomeRow`** and **`IncomeEditView`** live in `Views/IncomeView.swift` as shared components used by `ClientDetailView`
- **Color:** green throughout

## Reports — key decisions & current state

- **Access:** `chart.bar` toolbar button on Home screen → sheet with drag indicator (not a tab)
- **Scope:** currently month-only (current calendar month)
- **Empty state:** entire report content is hidden when there is no data — only `ContentUnavailableView` is shown
- **Month at a glance card:** 3×2 grid — hours + earnings (indigo), miles + reimbursement (blue), income received + expenses (green/red)
- **Mileage fuel analysis card:** MPG + gas price (stored in `@AppStorage`) → estimated gallons used → fuel cost vs reimbursement → net. "Edit" button in section header opens `FuelSettingsSheet`
- **Tax set-aside card:** shown when any gross income > 0. Formula: `grossIncome = timeEarnings + incomeReceived`, `taxableIncome = grossIncome − mileageDeduction − expenses`, set-aside = taxableIncome × (SE rate + income bracket rate). Shows deduction breakdown (mileage mi × rate, expenses). Rates editable in Settings.
- **Top clients:** ranked by hours, with proportional bar + earnings. Uses indigo badge.
- **Date range:** segmented picker at top — Week, Month, Quarter, Year. All cards respect the selected range.

## Settings & Profile — key decisions & current state

- **Titled "Profile"** with a centered avatar header at the top (indigo gradient circle + initials from `user_name`, name, and "<PrimaryUse> · Freelanced" subtitle). `profileInitials` computed in `SettingsView`. Still presented as a sheet from the gear icon.
- **Business Information** section (name, address, phone, email, website, tax ID/EIN) + **Invoicing Defaults** (payment terms picker, default sales tax %, accepted payments, payment instructions) — all `@AppStorage`, pulled into invoices. `businessField(...)` helper renders the labeled multiline text rows.
- **Presets & Quick-Fill section** links to Trip Purposes, Mileage Presets, and Expense Presets editors.
- Accessed via gear icon (top-left toolbar) on every screen — not a tab
- **Personalization:** first name (Home greeting), last name (invoices/exports only), and **App Focus** — multi-select chips ("Time Tracking / Mileage / Expenses / Invoicing") replacing the old single-select Primary Use picker; resets Home section order
- **Rates & Defaults:** IRS mileage rate (live, persisted), default hourly rate
- **Fuel:** MPG + gas price (shared with Reports fuel analysis card)
- **Tax Information:** business structure picker, SE tax rate, income bracket rate
- **Quarterly Tax Due Dates:** all four IRS estimated payment deadlines shown with period labels; next upcoming date highlighted in orange with days-until countdown
- **Data Export:** scoped CSV exports — **Export All Data** plus per-category **Time Entries / Mileage / Expenses** buttons, each limited to a selected **date range** (`ExportRange`: All Time / This Month / This Quarter / This Year / Custom with from/to `DatePicker`s). `exportBounds`/`inExportRange(_:)` filter every row builder by `date`; the range is written into the CSV header (`Range,…`) and the filename (`Freelanced_<Scope>_<Range>_<date>.csv`). `ExportScope` + `buildCSV(_:)` compose from `timeRows()`/`mileageRows()`/`expenseRows()` (each `[String]`) on top of `csvHeaderRows()` (name + export date + range). Mileage rows export the **full address** (`startAddressForExport`/`endAddressForExport`) plus a **Stops** column (waypoints). Fields are RFC-4180 quote-escaped via `csvField(_:)`.
- **App:** currency placeholder, app version from bundle
- Keyboard dismisses on scroll (`scrollDismissesKeyboard(.immediately)`)
- **Note:** Clients & Projects management was removed from Settings — it now lives entirely in the Clients tab

**`@AppStorage` keys used in Settings:**
- `user_name` — first name, shown in Home greeting
- `user_primaryUse` — primary use case, resets `home_sectionOrder` on change
- `mileage_ratePerMile` — IRS rate, defaults to `MileageTrip.defaultRatePerMile` (0.70)
- `default_hourlyRate` — fallback hourly rate when no project rate is set
- `report_mpg` — vehicle MPG for fuel analysis
- `report_gasPrice` — gas price per gallon
- `tax_selfEmploymentRate` — SE tax % (default 15.3)
- `tax_incomeBracketRate` — income tax bracket % (default 22.0)
- `tax_businessStructure` — business entity type string

`MileageTrip.ratePerMile` is now a computed static that reads from `UserDefaults` (`mileage_ratePerMile`) with a fallback to `defaultRatePerMile`. `LogTripView` syncs its local rate state from `@AppStorage` on appear.

---

## Onboarding — current state (redesigned)

5 pages: Welcome → About You → Your Business → Permissions → Ready. Branded redesign — `OnboardingScaffold` (animated capsule progress + optional Skip on top, `ScrollView` content with `.scrollDismissesKeyboard(.interactively)`, pinned bottom buttons, respects safe areas), `OnboardingBadge` (indigo-gradient rounded-square app-icon-style glyph).

- **Welcome:** "Welcome to Freelanced" + feature-highlight rows (time/mileage/expenses/invoices).
- **About You:** first + last name fields (last name labeled "appears on invoices and data exports") + **App Focus multi-select chips** (Time Tracking / Mileage / Expenses / Invoicing) — matches Settings. Writes `user_name`, `user_lastName`, comma-separated `user_primaryUse`, and `home_sectionOrder` via `HomeSection.orderString(forFocuses:)`. Continue disabled until a first name is entered.
- **Your Business (skippable):** business name, address (shared `AddressEntryField` w/ line 2), phone (auto-formatted), email, website, tax ID — writes the same `business_*` `@AppStorage` keys Settings uses, so invoices work out of the box. Skip advances.
- **Permissions (skippable):** Location, Camera (receipt photos, `AVCaptureDevice.requestAccess`), Notifications cards, each Enable → checkmark. No Photos card — `PhotosPicker`/PHPicker needs no permission.
- **Ready:** green success screen, greets by name.
- Gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing.

---

## Recently Deleted (soft-delete) — key decisions & current state

The six user-facing record types — **TimeEntry, MileageTrip, Expense, IncomeEntry, Invoice, Client** — use **soft-delete**: deleting sets `deletedDate = .now` instead of removing the row. Items live in a 30-day "Recently Deleted" area, can be restored, and are permanently purged after 30 days.

- **`SoftDeletable` protocol** (`Models/SoftDeletable.swift`): `var deletedDate: Date? { get set }` + `trashDaysRemaining` computed helper (0...30). All six in-scope models conform and declare `var deletedDate: Date? = nil` (CloudKit-safe optional with default).
- **Every `@Query` for these types filters `deletedDate == nil`** so trashed items vanish from all normal lists, pickers, reports, exports, and aggregates. Predicate-`init` queries (ClientDetailView, CreateInvoiceContent, the Month-detail views) AND `&& deletedDate == nil` into their existing predicate.
- **Relationship-array totals must also filter** — `ClientCell` computes earnings/hours from `client.timeEntries`/`incomeEntries` directly, so those sites use `.filter { $0.deletedDate == nil }`. (Invoice line items in `InvoiceDetailView`/PDF intentionally do NOT filter — an issued invoice is a finalized snapshot.)
- **Delete sites set `deletedDate = .now`** instead of `modelContext.delete(...)`. Exceptions that remain hard-delete: `TimePreset` (PresetsView), `Project` (AddEditClientView inline), and the eager-insert cancel path in AddEditClientView (`modelContext.delete(client)` discards an unsaved client).
- **`RecentlyDeletedView`** (`Settings/RecentlyDeletedView.swift`): six `@Query`s filtered to `deletedDate != nil`, merged into a unified sorted list. Swipe leading = Restore (`deletedDate = nil`), swipe trailing = Delete permanently (`modelContext.delete`). "Delete All" toolbar button. Shows "Nd left" per row (orange when ≤3 days). Reached via Settings → Data Management → Recently Deleted.
- **Purge:** `BusinessTrackerApp.purgeExpiredTrash()` runs on launch (`.task`) and on foreground. Fetches each type where `deletedDate != nil`, hard-deletes any older than 30 days. For a Client this fires the real cascade (projects + invoices) at purge time — matching the original hard-delete semantics.
- **Client soft-delete does NOT cascade during the 30-day window** — only the client's own `deletedDate` is set; its projects/invoices/entries are untouched until permanent purge. Restore brings the client back fully intact (better than the old hard-delete, which orphaned entries via nullify). Trade-off: a soft-deleted client's child records (time/income/expenses) remain visible in global lists during the window, consistent with the old nullify behavior where they survived client deletion.

## Delete confirmation pattern

All swipe-to-delete actions across the app show a `confirmationDialog` before executing. For the six soft-deleted types the message reads "You can restore this from Recently Deleted for 30 days." Pattern:
```swift
@State private var pendingDelete: ([ModelType], IndexSet)?

.onDelete { offsets in pendingDelete = (items, offsets) }

.confirmationDialog("Delete X?", isPresented: Binding(
    get: { pendingDelete != nil },
    set: { if !$0 { pendingDelete = nil } }
), titleVisibility: .visible) {
    Button("Delete", role: .destructive) { /* delete */ pendingDelete = nil }
    Button("Cancel", role: .cancel) { pendingDelete = nil }
} message: { Text("This cannot be undone.") }
```

Applied to: `TimeTrackingView`, `MileageView`, `MileageMonthDetailView`, `ExpensesView`, `ExpenseMonthDetailView`, `ClientsView` (client deletion warns projects will be deleted), `ClientDetailView` (separate dialogs for income entries, time entries, expenses, and invoices).

---

## Row / visual design language (consistent across all sections)

- **Title row:** entity name (bold semibold) + colored amount/hours badge (capsule pill) on the right
- **Detail row:** small icon column (10–12pt) + label text + Spacer + prominent value (`.subheadline.weight(.medium)`)
- **Color coding:** Time = indigo, Mileage = blue, Expenses = red, Income/money = green, Clients = teal (avatar + FAB; hours within a client stay indigo and earnings stay green per the time/money semantics)
- Notes always last, `.caption`, `.tertiary`, `lineLimit(1)`
- `.padding(.vertical, 4)` on all rows
- **History list rows** (Mileage + Expenses): month name as `.headline` primary text, colored badge on the right, secondary info (count + amount) below — not full summary cards

---

## File structure

```
BusinessTracker/
├── BusinessTrackerApp.swift         (CloudKit ModelContainer with local fallback)
├── BusinessTracker.entitlements     (iCloud + CloudKit entitlements)
├── ContentView.swift
├── Models/
│   ├── Client.swift                 (name, photoData, all relationships including invoices)
│   ├── Project.swift
│   ├── TimeEntry.swift              (includes invoice? relationship)
│   ├── TimePreset.swift
│   ├── MileageTrip.swift
│   ├── Expense.swift
│   ├── IncomeEntry.swift            (date, source, amount, notes, client?)
│   ├── Invoice.swift                (number, dates, isPaid, discount, taxRate, paymentTerms/instructions/accepted, poNumber, client?, timeEntries, lineItems; subtotal/discountedSubtotal/taxAmount/total)
│   ├── InvoiceLineItem.swift        (manual line: itemDescription, quantity, unitPrice, sortOrder, invoice? — lineTotal computed)
│   ├── MileagePreset.swift          (saved route template: name, start, end, purpose, notes, sortOrder — no relationships)
│   ├── ExpensePreset.swift          (saved expense template: name, amount: Double?, category, notes, sortOrder — no relationships)
│   ├── SoftDeletable.swift          (protocol: deletedDate + trashDaysRemaining — TimeEntry/MileageTrip/Expense/IncomeEntry/Invoice/Client conform)
│   └── TimerActivityAttributes.swift (ActivityAttributes for Live Activity — MUST stay in sync with FreelancedLiveActivity.swift copy)
├── Home/
│   └── HomeView.swift               (HomeSection enum, QuickAction enum, HomeSectionCard, HomeLayoutEditor)
├── TimeTracking/
│   ├── TimerState.swift
│   ├── TimeTrackingView.swift       (also contains ActiveTimerCard + TimeEntryRow — internal, shared)
│   ├── TimeHistoryView.swift        (months list → TimeMonthDetailView)
│   ├── TimeMonthDetailView.swift    (month entries + summary card, grouped by day)
│   ├── TimerSheet.swift
│   ├── LogTimeView.swift
│   ├── TimeEntryEditView.swift
│   ├── ClientListView.swift         (ClientsView tab, ClientCell, ClientAvatar, ClientDetailView, ClientTimeEntryRow, LogIncomeForClientView)
│   ├── AddEditClientView.swift      (photo picker, eager insert for new clients, projects section always visible)
│   ├── AddEditProjectView.swift
│   ├── PresetsView.swift
│   ├── (AddEditPresetView is inside PresetsView.swift)
│   └── InvoiceView.swift            (InvoiceRow, CreateInvoiceView/CreateInvoiceContent, InvoiceQuickActionSheet, InvoiceDetailView, MarkPaidSheet, InvoiceFirstPageLayout, InvoiceContinuationPageLayout, makeInvoicePDF())
├── Mileage/
│   ├── AddressSearcher.swift        (AddressSearcher, LocationManager, LocationResult, shortAddress, calculateDrivingMiles single + multi-leg)
│   ├── AddressSearchView.swift      (current location row + Favorites + Recent + MKLocalSearchCompletion results; star to favorite)
│   ├── RecentAddressStore.swift     (recents + favorites, both JSON in UserDefaults)
│   ├── MileagePurposePresets.swift  (purpose chip store + PurposeChipsRow + PurposePresetsEditor)
│   ├── MileagePresetsView.swift     (MileagePresetsView + AddEditMileagePresetView)
│   ├── LogTripView.swift            (multi-stop address mode: TripStop, Add Stop; mileage preset chips; purpose chips)
│   ├── MileageTripEditView.swift    (Manual / Address mode toggle, same as LogTripView)
│   ├── MileageView.swift            (also contains MileageSummaryCard, TripRow — shows "via …" waypoints)
│   ├── MileageHistoryView.swift
│   └── MileageMonthDetailView.swift
├── Expenses/
│   ├── ExpensesView.swift           (also contains ExpenseSummaryCard, ExpenseRow)
│   ├── AddExpenseView.swift         (expense preset chips pre-fill category/amount/notes)
│   ├── ExpenseEditView.swift
│   ├── ExpensePresetsView.swift     (ExpensePresetsView + AddEditExpensePresetView)
│   ├── ExpenseHistoryView.swift
│   ├── ExpenseMonthDetailView.swift
│   └── CameraView.swift             (also contains ReceiptPreviewSheet)
├── Settings/
│   ├── SettingsView.swift           (Profile header, Personalization, Rates & Defaults, Fuel, Tax Information, Quarterly Tax Dates + reminders toggle, Presets & Quick-Fill, Data Export, Recently Deleted, App — titled "Profile")
│   ├── TaxReminders.swift           (local-notification scheduler for quarterly deadlines — opt-in, rescheduled on launch)
│   └── RecentlyDeletedView.swift    (30-day trash — restore / permanent delete across all six soft-deleted types)
├── Shortcuts/
│   └── AppShortcuts.swift           (Siri/Shortcuts App Intents: StartTimer/LogTime/LogTrip/LogExpense + FreelancedShortcuts provider)
├── Onboarding/
│   └── OnboardingView.swift         (5 pages: welcome, about you, location, notifications, ready)
└── Views/
    ├── IncomeView.swift              (IncomeRow + IncomeEditView — shared components used by ClientDetailView)
    ├── ReportsView.swift             (3×2 glance card, fuel analysis, tax set-aside, top clients — opened as sheet from Home)
    └── PlaceholderView.swift

FreelancedWidget/                    (WidgetKit extension target)
├── FreelancedWidgetBundle.swift     (@main — registers FreelancedSmallWidget, FreelancedMediumWidget, FreelancedTaxWidget, FreelancedLiveActivity)
├── FreelancedWidget.swift           (providers, entry views, widget definitions, previews)
├── FreelancedTaxWidget.swift        (read-only Quarterly Tax Due Dates — StaticConfiguration, daily refresh; QuarterlyTaxDates logic duplicated from SettingsView)
├── FreelancedLiveActivity.swift     (TimerActivityAttributes copy, FreelancedLiveActivity Widget, TimerLockScreenView)
├── AppIntent.swift                  (WidgetQuickAction AppEnum, SingleActionConfiguration, QuadActionConfiguration)
├── FreelancedWidgetControl.swift    (Xcode-generated Control widget stub — unused, not in bundle; TimerControlIntent renamed to avoid conflict with AppIntent.swift)
└── Assets.xcassets/
```

---

## What's left to build

**Planned features (not started):**
- **Quote / Estimate generator** (Jack's idea) — let users create professional quotes/estimates for prospective work *before* it's done (pre-sale counterpart to an invoice). Should closely mirror Invoicing and reuse its infrastructure:
  - New `Quote` SwiftData model paralleling `Invoice` (`quoteNumber`, `issueDate`, `validUntil` instead of `dueDate`, `notes`, `discountAmount`, `taxRate`, `paymentTerms`, `poNumber`, `client?`, cascade `lineItems: [InvoiceLineItem]`-style). Quotes are manual line items only (description/qty/unit price) — no time-entry billing, since the work hasn't happened yet. Add a `status` (Draft / Sent / Accepted / Declined / Expired).
  - Reuse `BusinessInfo` (business header), `Client` billing details ("Quote For"), the line-item editor, and the totals math (subtotal → discount → tax → total).
  - PDF: clone the `makeInvoicePDF` multi-page approach with a `QUOTE` / `ESTIMATE` header, "Valid until" date, and an optional acceptance/signature line. Likely a shared PDF layout parameterized by document type to avoid duplication.
  - **Quote → Invoice conversion:** key value-add — an "Accept & convert to invoice" action that copies the quote's line items into a new `Invoice`. This is the main reason to share `InvoiceLineItem`.
  - Access: a new section in `ClientDetailView` (Quotes, above/below Invoices) + a "Create Quote" Home quick action and `WidgetQuickAction`/Shortcut, mirroring "Create Invoice".
  - Consider a unified "Documents" tab or grouping if Quotes + Invoices both live under each client.

**Remaining / future:**
- **Lock screen widgets** — deferred until Firebase Blaze (or equivalent server) is justified by MRR. Full design in the Widgets section.
- **Package Tracking** — future, needs carrier API integration.
- **Pro tier (paid)** — future, StoreKit.
- **macOS** — future. **iPad is now supported** (NavigationSplitView, see iPad section); remaining iPad polish (true 3-column drill-down, multi-window) is optional/future.

_(Shipped: Jack's full feedback batch — Reports PDF export, mileage deduction card, trip purpose presets, location favorites, multi-stop routes, mileage/expense presets, prominent timer-sheet presets button, Quarterly Tax widget, Settings→Profile redesign — plus Recently Deleted, Siri & Shortcuts, tax deadline reminders, and "Create Invoice" as a default Home quick action. See feature sections.)_

---

## Design conventions used throughout

- Segmented mode toggle lives **inside** the relevant form section (not above the form)
- Summary cards at top of Time, Mileage, and Expenses list views — suppressed when there is no data (only `ContentUnavailableView` shown in that case)
- `ContentUnavailableView` for all empty states
- Entries grouped by date, swipe-to-delete on all lists (with confirmation dialog)
- All sheets use `NavigationStack` with Cancel/Save (or Done) toolbar items
- **Toolbar layout convention:** profile icon (`person.crop.circle`, opens Settings sheet) sits **alone** in the top-left on every tab; all other actions (History, presets ⋯, +) live in the top-right. History is the right-edge button on Time/Mileage/Expenses.
- `ToolbarSpacer(placement:)` separates grouped trailing items (e.g. presets ⋯ and History on Time) to prevent iOS 26 Liquid Glass pill grouping
- Home section cards use `.listStyle(.plain)` with `Color(.systemGroupedBackground)` — each section is a single list row for reliable drag-to-reorder

---

## Widgets & Live Activities — current state & notes

- **Extension target:** `FreelancedWidget` (bundle: `com.garbenTechnologies.BusinessTracker.FreelancedWidget`)
- **URL scheme:** `freelanced://` registered in `BusinessTracker/Info.plist`. Deep link format: `freelanced://startTimer`, `freelanced://logTime`, `freelanced://logTrip`, `freelanced://addExpense`, `freelanced://createInvoice`
- **Deep link routing:** `BusinessTrackerApp.handleWidgetDeepLink(_:)` sets `timerState.pendingWidgetAction`; `ContentView` observes it with `onChange` and opens the right sheet
- **Foreground sync:** `BusinessTrackerApp` calls `timerState.syncFromSharedStore()` then `WidgetCenter.shared.reloadAllTimelines()` on `UIApplication.willEnterForegroundNotification`
- **`WidgetQuickAction`** — `AppEnum` in `AppIntent.swift`. Cases: `.startTimer`, `.logTime`, `.logTrip`, `.addExpense`, `.createInvoice`. Has `typeIdentifier = "com.garbenTechnologies.BusinessTracker.WidgetQuickAction"` for stable serialization. Mirrors `QuickAction` from the main app (kept separate — widget extension can't import main app module).
- **Config policy:** both providers use `policy: .never` — `AppIntentConfiguration` widgets reload automatically on config change; any other policy fights with WidgetKit's intent-driven reload and causes stale UI.
- **Duplicate actions:** `QuadActionWidgetView` uses `ForEach(Array(actions.enumerated()), id: \.offset)` — using `id: \.rawValue` collapses duplicate actions into one cell.

**Medium widget (active):**
- Kind: `FreelancedMediumWidget`
- Config: `QuadActionConfiguration` — 4 individually selectable `WidgetQuickAction` parameters
- View: 2×2 `LazyVGrid` of `WidgetActionCell` (circle icon + label, color-tinted card)

**Small widget (active):**
- Kind: `FreelancedSmallWidget`
- Config: `SingleActionConfiguration` — one `WidgetQuickAction` parameter
- Family: `.systemSmall` only (home screen)
- All actions deep-link into the app via `.widgetURL(action.deepLink)`
- Previously had a config-persistence bug with `policy: .after(24h)` — fixed by switching to `policy: .never`

**Quarterly Tax Due Dates widget (active, read-only):**
- Kind: `FreelancedTaxWidget` in `FreelancedWidget/FreelancedTaxWidget.swift`
- `StaticConfiguration` (no user config), families `.systemSmall` + `.systemMedium`
- Shows the next due date prominently (small) plus all four quarters (medium), next one highlighted orange with a day countdown
- `QuarterlyTaxDates.upcoming()` duplicates the date logic from `SettingsView` (widget can't import the app). Timeline refreshes at next midnight so "next due" + countdown stay current. No App Group / no deep link.

**Live Activity (active, branded redesign):**
- Kind: `FreelancedLiveActivity` in `FreelancedWidget/FreelancedLiveActivity.swift`
- Attributes: `TimerActivityAttributes` (`clientName`, `projectName`); `ContentState` (`startDate: Date`)
- **Design:** app-icon-style badge (`TimerAppBadge` — indigo rounded-square + white `stopwatch.fill`), a red-dot "TRACKING TIME" label (`TrackingLabel`), rounded monospaced indigo timer (`liveTimer`), indigo-tinted gradient container background. Brand colors `brandIndigo`/`brandIndigoDark` defined at top of file.
- Lock screen `TimerLockScreenView`: badge · tracking label + client/project · live timer + "Freelanced" wordmark.
- Dynamic Island: compact (stopwatch + timer), minimal (stopwatch). **Expanded uses ONLY the `.bottom` region** for the full banner (badge + tracking label/client/project on the left, timer + "Freelanced" on the right) — the narrow leading/trailing regions clip long text (they hand content its natural size then truncate, so `minimumScaleFactor` never engages), whereas `.bottom` spans the full island width.
- **Informational only** — no Stop button (deliberately reserved to the app to avoid accidental stops). Tapping the activity opens the app via `widgetURL(freelanced://startTimer)`, where the timer is stopped. (A Stop button was built then removed; if revisited it needs a shared App-Intent target + persisting the running client/project to the App Group.)
- Started by `TimerState.startLiveActivity()` in the **main app process only** — widget extensions cannot call `Activity.request()`
- Ended by `TimerState.endLiveActivity()` on timer stop
- `NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` must be `true` in `BusinessTracker/Info.plist`
- **Future:** drop a logo image into `FreelancedWidget/Assets.xcassets` to replace the `stopwatch.fill` glyph in `TimerAppBadge` with the real app mark.

**Widget timer start flow:**
- Tapping any widget action calls `.widgetURL(action.deepLink)` → app opens → `handleWidgetDeepLink(_:)` routes to correct sheet
- The "Start Timer" action on the home screen small widget follows the same deep-link path (opens app, timer sheet appears)
- `TimerState.syncFromSharedStore()` is called on every foreground — reserved for future background-start scenarios

**Lock screen widgets — deferred:**
- Was fully built (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` families + `StartTimerIntent` with `openAppWhenRun: false` writing to App Group UserDefaults)
- Core problem: widget extensions cannot call `Activity.request()` — the Live Activity only appeared after the user opened the app
- Attempted fix: ActivityKit push-to-start via Firebase Cloud Function — rejected because Firebase Blaze plan required
- Decision: removed lock screen families and `StartTimerIntent`; revisit when MRR justifies the server cost
- Re-implementation path when ready: push-to-start token listener in main app → store in App Group UserDefaults → widget intent POSTs token + startDate to server → server sends APNs push with `apns-push-type: liveactivity` and topic `com.garbenTechnologies.BusinessTracker.push-type.liveactivity`

## Siri & Shortcuts — current state & notes

- **`Shortcuts/AppShortcuts.swift`** (main app target): `StartTimerShortcut`, `LogTimeShortcut`, `LogTripShortcut`, `LogExpenseShortcut` — all `AppIntent` with `openAppWhenRun = true`.
- **Routing:** each intent writes a raw action string to App Group UserDefaults key `pendingShortcutAction`. `BusinessTrackerApp.consumePendingShortcutAction()` reads it on `.task` (launch) and on foreground, then calls `routeAction(_:)` → sets `timerState.pendingWidgetAction` → ContentView opens the matching sheet. Same routing target as widget deep links (`routeAction` is shared by both).
- **`FreelancedShortcuts: AppShortcutsProvider`** auto-registers the four shortcuts (no user setup) with Siri phrases — phrases must include `\(.applicationName)`.
- Uses the existing App Group (`group.com.garbenTechnologies.BusinessTracker`) and the existing `WidgetAction` enum routing — no new infrastructure.

## Tax deadline reminders — current state & notes

- **`Settings/TaxReminders.swift`**: schedules local `UNCalendarNotificationTrigger`s a week before and the day before each quarterly IRS deadline (9am local). Opt-in via `@AppStorage("tax_remindersEnabled")`, toggle in the Quarterly Tax Dates section.
- `handleToggle(enabled:)` requests authorization when turning on; `reschedule()` clears prior `tax-deadline-*` requests and re-adds upcoming ones. Called on app launch (`.task`) so deadlines roll forward each cycle.
- No push entitlement / no server — purely local notifications. `TaxReminders.dueDates()` duplicates the quarterly-date logic (same as SettingsView + the tax widget).

## Planned platform extensions

- **Lock screen widgets** — deferred (see Widgets section)

---

## Known patterns / gotchas

- **CloudKit model rules (all must be followed or CloudKit silently falls back to local-only):**
  1. Every stored attribute needs a default on the *property declaration* — `var name: String = ""` not just `var name: String` (CloudKit reads metadata, not `init`)
  2. All to-many relationships must be `[T]? = nil`, not `[T] = []` — access sites use `(x ?? [])`
  3. Every relationship must have an inverse defined with `@Relationship(inverse:)`
  4. Use `Double` not `Decimal` for monetary values — CloudKit has no native Decimal type
  5. `remote-notification` must be in `UIBackgroundModes` in Info.plist — CloudKit uses silent push to trigger sync
  6. Schema must be manually deployed from Development → Production in CloudKit Console after first device run
- `onChange(of: selectedClient)` only clears `selectedProject` if the project doesn't belong to the new client — prevents presets from requiring two taps
- SwiftData filtered `@Query` in detail views uses custom `init` with `#Predicate` — `ClientDetailView` filters time entries and income entries by `persistentModelID` for immediate reactivity
- `TimerState.stop()` clears client/project — always capture them into locals before calling it
- `Text +` concatenation is deprecated in iOS 26 — use string interpolation instead
- `Decimal(string:)` used for amount parsing from text fields — handles currency input safely. Strip any `$` prefix before passing if the field displays one.
- `Color.tertiary` doesn't exist as a `Color` — use `.foregroundStyle(.tertiary)` or `AnyShapeStyle(.tertiary)` when mixing with `Color` in a ternary
- `scrollDismissesKeyboard(.immediately)` must be added to every `Form` that contains text fields — applied to all sheets app-wide
- `ToolbarSpacer(placement:)` is an iOS 26 API — use it to break Liquid Glass grouping between toolbar items in the same placement
- Onboarding gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing
- `ITSAppUsesNonExemptEncryption = NO` is set in build settings via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` — no TestFlight export compliance prompts
- **Info.plist split:** physical `BusinessTracker/Info.plist` holds `NSSupportsLiveActivities(+FrequentUpdates)`, `UIBackgroundModes: remote-notification` (CloudKit), and the `freelanced://` URL scheme. Permission strings + display name live in `INFOPLIST_KEY_*` build settings (merged at build): `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription` (present but unused — PHPicker needs no permission), `CFBundleDisplayName = Freelanced`. Local notifications need no usage string. iCloud container / App Group / push live in `BusinessTracker.entitlements` (separate from Info.plist).
- **Settings keyboard "Done"** dismisses via BOTH `fieldFocused = false` AND `UIApplication…resignFirstResponder` — the latter is required because `AddressEntryField`'s internal TextFields aren't bound to Settings' `@FocusState`, so clearing the focus state alone wouldn't dismiss them.
- `MKLocalSearchCompletion` cannot be instantiated directly — address search uses `LocationResult` enum (`.completion` or `.coordinate`) to handle both MapKit results and current-location coordinates uniformly
- `UIImage` conforms to `Identifiable` via a `@retroactive` extension in `AddExpenseView.swift` — needed for `.sheet(item:)` on the receipt preview. Do not add a second conformance elsewhere.
- SwiftData lightweight migration requires default values on the **property declaration**, not just in `init` — e.g. `var receiptImagesData: [Data] = []`. Missing the `= []` causes the store to silently fail to open, breaking saves for all models.
- `CLLocationManagerDelegate.locationManagerDidChangeAuthorization` fires immediately when the delegate is set in `init` — always guard on an explicit `isLocating` flag before calling `requestLocation()` to prevent auto-triggering on sheet open
- `LabeledContent` splits a row roughly 50/50 — long label text gets truncated. For rows with icons + text labels, use `HStack { icon; Text; Spacer(); value }` with a fixed-width value field instead. Reserve `LabeledContent` for short labels (e.g. "Structure" picker) where the right side needs the extra space.
- Currency prefix on amount fields: use `HStack { Text("Amount"); Spacer(); Text("$"); TextField(...).frame(width: 100) }` — putting `$` inside a `LabeledContent` content HStack pushes it to the center of the row rather than adjacent to the typed value.
- `ContentUnavailableView` should always be placed in `.overlay` on the `List`, not inside a `Section` — overlay centers it on the full screen, Section just stacks it below existing content
- `NavigationLink` label VStack in a List needs `.frame(maxWidth: .infinity, alignment: .leading)` to fill the row width — without it the row may render with content top-aligned instead of vertically centered
- **Home reorder:** `ForEach { Section { } }.onMove` does NOT move sections as units — it attaches drag handles to individual rows inside sections. To reorder sections, each section must be a single `List` row. `HomeView` uses this pattern via `HomeSectionCard`.
- **CloudKit ModelContainer:** constructing `ModelContainer` with a manual `Schema` object can fail if the on-disk store was created by the `.modelContainer(for:)` scene modifier. Use `ModelConfiguration(schema:cloudKitDatabase:)` inside a `do/catch` with a local fallback using `ModelConfiguration(schema:cloudKitDatabase:.none)`.
- **`AddEditClientView` eager insert:** for new clients, the `Client` object is inserted into the model context immediately on `onAppear` so the Projects section is available before saving. If the user cancels, the client is deleted. This means a cancelled "New Client" sheet briefly creates and then removes a record — expected behavior.
- **Do not use relationship arrays for reactive UI in detail views** — `client.timeEntries` and `client.incomeEntries` accessed directly on a passed-in model object don't update the view promptly when entries are added elsewhere. Always use `@Query` with `#Predicate { $0.client?.persistentModelID == id }` for live-updating lists.
- **`ImageRenderer` PDF coordinate system** — `ImageRenderer.render { size, draw in }` already handles the Y-axis flip internally. Do NOT apply `translateBy`/`scaleBy` before calling `draw(ctx)` — a second flip produces upside-down output. Set page `mediaBox` to `CGRect(origin: .zero, size: size)` and call `draw(ctx)` directly. For a fixed letter-size page (612×792), set `renderer.proposedSize = ProposedViewSize(width: 612, height: 792)` and constrain the layout view with `.frame(width: 612, height: 792)`.
- **Currency text fields use string-based input with 2-decimal hard limit** — all monetary TextFields use `text: $someText` (not `value: $someDouble, format: .currency`) with an `onChange` filter: strip non-numeric chars except `.`, then cap fractional digits at 2 using `String.firstIndex(of: ".")`. This prevents rounding artifacts on every keystroke. Applied to: hourly rate fields in `LogTimeView`, `TimeEntryEditView`, `AddEditProjectView`, `PresetsView`; amount fields in `AddExpenseView`, `ExpenseEditView`, `IncomeView`, `ClientListView` (LogIncomeForClientView), `InvoiceView`.
- **`AppIntentConfiguration` widgets must use `policy: .never`** — any other reload policy (e.g. `.after(24h)`) conflicts with WidgetKit's intent-driven reload and causes the widget to ignore configuration changes. WidgetKit reloads the timeline automatically when the user changes an `AppIntentConfiguration`.
- **`ForEach` with `AppEnum` — use `id: \.offset`, not `id: \.rawValue`** — if the user picks the same action for multiple slots, `id: \.rawValue` collapses duplicates into a single cell. Wrap with `Array(actions.enumerated())` and use `id: \.offset`.
- **Widget extensions cannot start Live Activities** — `Activity<T>.request()` must be called from the main app process. Widget `AppIntent.perform()` can write to shared App Group UserDefaults; the main app calls `TimerState.syncFromSharedStore()` on foreground which reads that value and starts the Live Activity. There is no way to show the Live Activity immediately on widget tap without a server-side ActivityKit push-to-start (APNs `apns-push-type: liveactivity`).
- **`TimerActivityAttributes` is duplicated across two targets** — the main app (`BusinessTracker/Models/TimerActivityAttributes.swift`) and widget extension (`FreelancedWidget/FreelancedLiveActivity.swift`) are separate Swift modules and cannot share the type. The struct must be kept identical in both files; a comment in each file calls this out.
- **Multi-page invoice PDF uses multiple `ImageRenderer` renders into one `CGContext`** — call `ctx.beginPDFPage(nil)` / `draw(ctx)` / `ctx.endPDFPage()` per page, then `ctx.closePDF()`. Each page is a separate `ImageRenderer` with its own SwiftUI layout (`InvoiceFirstPageLayout` max 7 items, `InvoiceContinuationPageLayout` max 10). Do not try to render all pages in a single `ImageRenderer`.
- **`CreateInvoiceView` wraps `CreateInvoiceContent`** — `CreateInvoiceContent` is a private struct holding all form state and the body. `CreateInvoiceView(client:)` just wraps it in a `NavigationStack`. `InvoiceQuickActionSheet` shows a client picker that pushes to `CreateInvoiceContent` directly, reusing the same form without duplication.
- **Soft-delete: any NEW `@Query` for TimeEntry/MileageTrip/Expense/IncomeEntry/Invoice/Client MUST filter `deletedDate == nil`** — there is no global query scope in SwiftData, so a forgotten filter makes trashed items reappear. Simple form: `@Query(filter: #Predicate<T> { $0.deletedDate == nil }, sort: ...)`. Predicate-`init` form: AND `&& $0.deletedDate == nil` into the predicate. Any code summing a **relationship array** (e.g. `client.timeEntries`) must `.filter { $0.deletedDate == nil }` too. To trash a record set `deletedDate = .now` (never `modelContext.delete`, except for the hard-delete exceptions: TimePreset, Project, and the AddEditClientView eager-insert cancel). See the Recently Deleted section.
