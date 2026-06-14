# BusinessTracker / Freelanced — Project Context

## What this is
A SwiftUI app for small business owners and contract workers to track time, mileage, expenses, and income. Built by Tyler with his friend/co-founder (50% stakeholder) who is the primary end user and provides product feedback after testing builds. App name may be changing to **Freelanced** — widget extension is already named `FreelancedWidget`.

## Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData + CloudKit (private database, syncs across devices when signed into iCloud)
- **Target:** iOS 26 minimum (use iOS 26 APIs freely)
- **Future platforms:** iPadOS, macOS (not yet)
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
| Expense Tracking | 🔶 In progress (core done, multi-receipt done) |
| Income & Tax Projection | ⬜ Not started |
| Reports & Analytics | 🔶 In progress (month glance, mileage fuel analysis, top clients) |
| Settings & Profile | 🔶 In progress (core sections done) |
| iCloud Sync | 🔶 In progress (CloudKit wired, entitlements set, needs real-device validation) |
| Package Tracking | ⬜ Future (API integration) |
| Home Screen Widgets | 🔶 In progress (medium quick-actions widget done; small widget built but disabled — config persistence bug) |
| Live Activities | ⬜ Future (ActivityKit) |
| Lock Screen Actions | ⬜ Future (WidgetKit lock screen widgets) |
| Shortcuts / Siri | ⬜ Future (App Intents) |
| Pro tier (paid) | ⬜ Future |

---

## Tab bar navigation

**Current tabs:** Home · Time · Mileage · Expenses · Reports (5 tabs, at iOS limit)

- **Settings** is accessible via a ⚙️ gear icon in the **top-left toolbar on every screen** — opens as a sheet
- **Income** tab is removed until the feature is built — placeholder view and model still exist in codebase
- Tab order reflects daily-use priority: Home first, then the three active tracking tabs, Reports last

---

## Data models

- **`Client`** — `name`. Container only; rate lives on Project.
- **`Project`** — `name`, `hourlyRate`, belongs to `Client`
- **`TimeEntry`** — `date`, `client?`, `project?`, `hours`, `hourlyRate` (snapshot), `notes`
- **`TimePreset`** — `name`, `client?`, `project?`, `sortOrder`, `hourlyRateOverride?`, `notesTemplate`
- **`MileageTrip`** — `date`, `startLocation`, `endLocation`, `miles`, `purpose`, `notes`. Computed `reimbursementAmount` using `ratePerMile` (IRS rate, currently 0.70)
- **`Expense`** — `date`, `amount`, `category`, `notes`, `receiptImageData?` (legacy — kept for migration), `receiptImagesData: [Data]` (current multi-image storage), `client?` (optional link). Categories defined in `Expense.categories`. Helper statics: `categoryIcon(_:)`, `categoryColor(_:)`
- **`IncomeEntry`** — `date`, `source`, `amount`, `notes` (placeholder model, view not built)
- **`TimerState`** — `@Observable` class (not SwiftData). Persists active timer start date to `UserDefaults` so timer survives backgrounding. Also holds `pendingWidgetAction: WidgetAction?` for routing widget deep links to the correct sheet.
- **`WidgetAction`** — enum in `TimerState.swift`: `.startTimer`, `.logTime`, `.logTrip`, `.addExpense`. Set by `BusinessTrackerApp.handleWidgetDeepLink(_:)`, consumed by `ContentView`.

---

## iCloud Sync — current state & notes

- **Container:** `iCloud.com.garbenTechnologies.BusinessTracker`
- **Bundle ID:** `com.garbenTechnologies.BusinessTracker`
- **Entitlements file:** `BusinessTracker/BusinessTracker.entitlements` — has `com.apple.developer.icloud-container-identifiers` + `com.apple.developer.icloud-services: CloudKit`
- **ModelContainer init:** `BusinessTrackerApp.swift` tries CloudKit private DB first; falls back to local-only if unavailable (simulator, not signed in, etc.)
- **Xcode capability:** iCloud → CloudKit must be enabled in Signing & Capabilities with container `iCloud.com.garbenTechnologies.BusinessTracker`
- **Known limitation:** CloudKit does not support `Decimal` natively — if sync issues arise, monetary fields may need to be stored as `Double` (cents as Int) with a migration plan
- Sync only works on a real device signed into iCloud; simulator always uses the local fallback

---

## Home Screen — key decisions & current state

- **Personalized greeting:** "Good morning, Jack" — reads `@AppStorage("user_name")`
- **Reorderable sections:** Three sections (Quick Actions, Today, This Week) stored as an ordered comma-separated string in `@AppStorage("home_sectionOrder")`. Active timer card is always pinned at top.
- **Configurable quick actions:** Enabled actions + order stored in `@AppStorage("home_quickActionOrder")` and `@AppStorage("home_quickActionEnabled")`. Defined by `QuickAction` enum in `HomeView.swift`.
- **Quick Actions display:** 2-wide `LazyVGrid` of individually rounded cards (`QuickActionCell`) — icon in a filled circle, label below, subtle color tint + stroke border per action. Cards use `action.color.opacity(0.07)` fill and `0.12` stroke.
- **Zero quick actions:** if `home_quickActionEnabled` is empty, the Quick Actions section is completely hidden from the home screen. In `HomeLayoutEditor`, the Quick Actions row in Section Order shows "No actions enabled" in tertiary text and its drag handle is hidden.
- **Customize Home sheet:** `slider.horizontal.3` toolbar button → `HomeLayoutEditor` sheet. Always in edit mode (`.constant(.active)`). Two sections: Section Order (drag to reorder) and Quick Actions (toggle + drag to reorder). Done saves, Cancel discards. No minimum action count enforced.
- **Section rendering:** Each section is a single `List` row (`HomeSectionCard`) with a clear background so drag-to-reorder in the editor works correctly. Home uses `.listStyle(.plain)` with `Color(.systemGroupedBackground)`.
- **Today at a glance:** three stat cells (hours, miles, spend). Stats go muted when empty.
- **This week:** hours + earnings cells with per-day average subtitle.
- `ActiveTimerCard` is `internal` (not `private`) so both `HomeView` and `TimeTrackingView` can use it.

**`@AppStorage` keys for Home:**
- `user_name` — first name for greeting
- `user_primaryUse` — "Mixed" | "Time & Billing" | "Mileage" | "Expenses" — sets default section order
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
- **Presets** (`TimePreset`): named combos of client + project + optional rate override + optional notes template. Managed from `⋯` button (opens `PresetsView` directly — no menu, single item). Reorderable.
- **Clients & Projects** managed exclusively from Settings → Business section (removed from `⋯` menu)
- **Tap any entry** to open `TimeEntryEditView` — edit all fields including notes
- **Week summary card** at top of Time Tracking screen — hidden when no entries exist (only `ContentUnavailableView` shown)
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

## Expense Tracking — key decisions & current state

- **Categories:** Supplies, Equipment, Software, Travel, Meals, Marketing, Utilities, Rent, Insurance, Other — each has an SF Symbol icon and color defined in `Expense` statics
- **Client link:** optional — expense can be standalone or linked to a `Client`
- **Multiple receipts:** attach multiple images per expense via `PhotosPicker` (library) or `CameraView` (camera). Stored as `receiptImagesData: [Data]` on the model. Thumbnails shown in a horizontal scroll row in Add/Edit views; each has an × remove button. `ExpenseRow` shows a paperclip icon + count badge.
- **Legacy migration:** old `receiptImageData: Data?` field is preserved on the model. `ExpenseEditView` migrates it into `receiptImagesData` on first open and clears the old field on save.
- **Amount field:** displays a `$` prefix label beside the text input in both Add and Edit views. Parsed via `Decimal(string:)` on save.
- **Tap any entry** to open `ExpenseEditView`
- **Month summary card** shows total spend + transaction count — hidden when no expenses exist (only `ContentUnavailableView` shown)
- **Swipe to delete** shows confirmation dialog before deleting
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` must be in Info.plist for camera/photo on real device

## Reports — key decisions & current state

- **Scope:** currently month-only (current calendar month)
- **Empty state:** entire report content is hidden when there is no data for the current month — only `ContentUnavailableView` is shown
- **Month at a glance card:** 2×2 grid — hours + earnings (indigo), miles + reimbursement (blue). Month label is the `Section` header above the card (not overlaid on the card).
- **Mileage fuel analysis card:** MPG + gas price (stored in `@AppStorage`) → estimated gallons used → fuel cost vs reimbursement → net. "Edit" button in section header opens `FuelSettingsSheet`
- **Top clients:** ranked by hours, with proportional bar + earnings. Uses indigo badge matching `TimeEntryRow` style
- Reports is the convergence point for all four data types — will grow as Expenses and Income are built out

## Settings & Profile — key decisions & current state

- Accessed via gear icon (top-left toolbar) on every screen — not a tab
- **Personalization:** user name (used in Home greeting), primary use case picker (resets Home section order to use-case default)
- **Business:** links to `ClientListView` for managing clients + projects
- **Rates & Defaults:** IRS mileage rate (live, persisted), default hourly rate
- **Fuel:** MPG + gas price (shared with Reports fuel analysis card)
- **Tax Information:** business structure picker, SE tax rate, income bracket rate
- **Quarterly Tax Due Dates:** all four IRS estimated payment deadlines shown with period labels; next upcoming date highlighted in orange with days-until countdown
- **Data Export:** "Export All Data (CSV)" button — generates time entries + mileage + expenses as a single CSV, shares via `UIActivityViewController`
- **App:** currency placeholder, app version from bundle
- Keyboard dismisses on scroll (`scrollDismissesKeyboard(.immediately)`)

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

## Onboarding — current state

5 pages: Welcome → About You → Location → Notifications → Ready

- **About You (page 2):** asks for first name + primary use case (4 options with checkmark selection). Sets `user_name`, `user_primaryUse`, and `home_sectionOrder` AppStorage keys.
- Gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing.

---

## Delete confirmation pattern

All swipe-to-delete actions across the app show a `confirmationDialog` before executing. Pattern:
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

Applied to: `TimeTrackingView`, `MileageView`, `MileageMonthDetailView`, `ExpensesView`, `ExpenseMonthDetailView`, `ClientListView` (client deletion message also warns projects will be deleted).

---

## Row / visual design language (consistent across all sections)

- **Title row:** entity name (bold semibold) + colored amount/hours badge (capsule pill) on the right
- **Detail row:** small icon column (10–12pt) + label text + Spacer + prominent value (`.subheadline.weight(.medium)`)
- **Color coding:** Time = indigo, Mileage = blue, Expenses = red, Income = TBD
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
│   ├── Client.swift
│   ├── Project.swift
│   ├── TimeEntry.swift
│   ├── TimePreset.swift
│   ├── MileageTrip.swift
│   ├── Expense.swift
│   └── IncomeEntry.swift
├── Home/
│   └── HomeView.swift               (HomeSection enum, QuickAction enum, HomeSectionCard, HomeLayoutEditor)
├── TimeTracking/
│   ├── TimerState.swift
│   ├── TimeTrackingView.swift       (also contains ActiveTimerCard — internal, shared with HomeView)
│   ├── TimerSheet.swift
│   ├── LogTimeView.swift
│   ├── TimeEntryEditView.swift
│   ├── ClientListView.swift
│   ├── AddEditClientView.swift
│   ├── AddEditProjectView.swift
│   ├── PresetsView.swift
│   └── (AddEditPresetView is inside PresetsView.swift)
├── Mileage/
│   ├── AddressSearcher.swift        (AddressSearcher, LocationManager, LocationResult, shortAddress, calculateDrivingMiles)
│   ├── AddressSearchView.swift      (current location row + MKLocalSearchCompletion results)
│   ├── LogTripView.swift
│   ├── MileageTripEditView.swift    (Manual / Address mode toggle, same as LogTripView)
│   ├── MileageView.swift            (also contains MileageSummaryCard, TripRow)
│   ├── MileageHistoryView.swift
│   └── MileageMonthDetailView.swift
├── Expenses/
│   ├── ExpensesView.swift           (also contains ExpenseSummaryCard, ExpenseRow)
│   ├── AddExpenseView.swift
│   ├── ExpenseEditView.swift
│   ├── ExpenseHistoryView.swift
│   ├── ExpenseMonthDetailView.swift
│   └── CameraView.swift             (also contains ReceiptPreviewSheet)
├── Settings/
│   └── SettingsView.swift           (also contains SettingsIcon helper; has Personalization, Quarterly Tax Dates, Data Export sections)
├── Onboarding/
│   └── OnboardingView.swift         (5 pages: welcome, about you, location, notifications, ready)
└── Views/
    ├── IncomeView.swift              (placeholder — no tab until feature is built)
    ├── ReportsView.swift             (in progress)
    └── PlaceholderView.swift

FreelancedWidget/                    (WidgetKit extension target)
├── FreelancedWidgetBundle.swift     (@main — registers FreelancedMediumWidget only; small built but disabled)
├── FreelancedWidget.swift           (providers, entry views, widget definitions, previews)
├── AppIntent.swift                  (WidgetQuickAction AppEnum, SingleActionConfiguration, QuadActionConfiguration)
├── FreelancedWidgetControl.swift    (Xcode-generated Control widget stub — unused, not in bundle)
└── Assets.xcassets/
```

---

## What's left to build

**Near term (logical next steps):**
- **Income tab** — `IncomeEntry` model exists, needs full UI: log income, list view, edit view, month summary card
- **Reports expansion** — add expenses section, tax set-aside estimate (uses Settings tax rates), date range picker (week / month / quarter / year)
- **iCloud sync validation** — confirm sync works correctly on real device; watch for Decimal type issues
- **Small widget config bug** — `FreelancedSmallWidget` is built but disabled; `AppIntentConfiguration` with a single `AppEnum` parameter doesn't reflect user configuration changes. Investigate whether the issue is serialization, timeline invalidation, or an iOS bug.

**Polish / UX:**
- Verify Home screen primary use picker correctly reorders sections (Settings onChange triggers correctly)
- Home screen quick actions — consider adding more actions as features are built (Log Income, etc.)

---

## Design conventions used throughout

- Segmented mode toggle lives **inside** the relevant form section (not above the form)
- Summary cards at top of Time, Mileage, and Expenses list views — suppressed when there is no data (only `ContentUnavailableView` shown in that case)
- `ContentUnavailableView` for all empty states
- Entries grouped by date, swipe-to-delete on all lists (with confirmation dialog)
- All sheets use `NavigationStack` with Cancel/Save (or Done) toolbar items
- Gear icon (⚙️) always top-left toolbar, opens Settings as a sheet, always its own separate Liquid Glass pill
- `ToolbarSpacer(placement: .topBarLeading)` separates the gear from adjacent leading toolbar items to prevent iOS 26 Liquid Glass pill grouping
- Home section cards use `.listStyle(.plain)` with `Color(.systemGroupedBackground)` — each section is a single list row for reliable drag-to-reorder

---

## Widgets — current state & notes

- **Extension target:** `FreelancedWidget` (bundle: `com.garbenTechnologies.BusinessTracker.FreelancedWidget`)
- **URL scheme:** `freelanced://` registered in `BusinessTracker/Info.plist`. Deep link format: `freelanced://startTimer`, `freelanced://logTime`, `freelanced://logTrip`, `freelanced://addExpense`
- **Deep link routing:** `BusinessTrackerApp.handleWidgetDeepLink(_:)` sets `timerState.pendingWidgetAction`; `ContentView` observes it with `onChange` and opens the right sheet
- **Reload on foreground:** `BusinessTrackerApp` calls `WidgetCenter.shared.reloadAllTimelines()` on `UIApplication.willEnterForegroundNotification`
- **`WidgetQuickAction`** — `AppEnum` in `AppIntent.swift`. Has `typeIdentifier = "com.garbenTechnologies.BusinessTracker.WidgetQuickAction"` for stable serialization. Mirrors `QuickAction` from the main app (kept separate — widget extension can't import main app module).

**Medium widget (active):**
- Kind: `FreelancedMediumWidget`
- Config: `QuadActionConfiguration` — 4 individually selectable `WidgetQuickAction` parameters
- View: 2×2 `LazyVGrid` of `WidgetActionCell` (circle icon + label, color-tinted card matching in-app `QuickActionCell` style)
- Outer padding: `4`

**Small widget (built, disabled):**
- Kind: `FreelancedSmallWidget` — exists in `FreelancedWidget.swift` but not registered in the bundle
- Config: `SingleActionConfiguration` — one `WidgetQuickAction` parameter
- Known issue: configuration changes don't update the rendered widget despite `typeIdentifier`, `policy: .after(24h)`, and foreground reload. Needs further investigation before re-enabling.
- To re-enable: add `FreelancedSmallWidget()` back to `FreelancedWidgetBundle.body`

## Planned platform extensions (not started)

- **Live Activities** (ActivityKit) — show active timer elapsed time on Dynamic Island / lock screen.
- **Lock screen widgets** (WidgetKit) — quick-tap buttons for starting timer or logging a trip.
- **Shortcuts / Siri** (App Intents) — `AppIntent` conformances for "start timer", "stop timer", "log a trip", "log an expense".

---

## Known patterns / gotchas

- `onChange(of: selectedClient)` only clears `selectedProject` if the project doesn't belong to the new client — prevents presets from requiring two taps
- SwiftData filtered `@Query` in detail views uses custom `init` with `#Predicate`
- `TimerState.stop()` clears client/project — always capture them into locals before calling it
- `Text +` concatenation is deprecated in iOS 26 — use string interpolation instead
- `Decimal(string:)` used for amount parsing from text fields — handles currency input safely. Strip any `$` prefix before passing if the field displays one.
- `Color.tertiary` doesn't exist as a `Color` — use `.foregroundStyle(.tertiary)` or `AnyShapeStyle(.tertiary)` when mixing with `Color` in a ternary
- `scrollDismissesKeyboard(.immediately)` must be added to every `Form` that contains text fields — applied to all sheets app-wide
- `ToolbarSpacer(placement:)` is an iOS 26 API — use it to break Liquid Glass grouping between toolbar items in the same placement
- Onboarding gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing
- `ITSAppUsesNonExemptEncryption = NO` is set in build settings via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` — no TestFlight export compliance prompts
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
