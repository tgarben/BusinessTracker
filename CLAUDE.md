# BusinessTracker — Project Context

## What this is
A SwiftUI app for small business owners and contract workers to track time, mileage, expenses, and income. Built by Tyler with his friend/co-founder (50% stakeholder) who is the primary end user and provides product feedback after testing builds.

## Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData (on-device only, no sync, no remote)
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
| Home Screen | ✅ Done |
| Time Tracking | ✅ Done |
| Mileage Tracking | ✅ Done |
| Expense Tracking | 🔶 In progress (core done, receipt photo done) |
| Income & Tax Projection | ⬜ Not started |
| Reports & Analytics | 🔶 In progress (month glance, mileage fuel analysis, top clients) |
| Settings & Profile | 🔶 In progress (core sections done) |
| Package Tracking | ⬜ Future (API integration) |
| Home Screen Widgets | ⬜ Future (WidgetKit) |
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
- **`Expense`** — `date`, `amount`, `category`, `notes`, `receiptImageData?`, `client?` (optional link). Categories defined in `Expense.categories`. Helper statics: `categoryIcon(_:)`, `categoryColor(_:)`
- **`IncomeEntry`** — `date`, `source`, `amount`, `notes` (placeholder model, view not built)
- **`TimerState`** — `@Observable` class (not SwiftData). Persists active timer start date to `UserDefaults` so timer survives backgrounding.

---

## Home Screen — key decisions & current state

- **Purpose:** launchpad + at-a-glance status, not a duplicate of Reports
- **Quick Actions:** four list rows — Start/View Timer, Log Time, Log Trip, Add Expense. Each opens the relevant existing sheet directly
- **Today at a glance:** three stat cells (hours, miles, spend) in a single divider-separated list row. Stats go muted when empty
- **This week:** hours + earnings cells with per-day average subtitle
- **Active timer card** floats at the top when a timer is running (same `ActiveTimerCard` component reused from `TimeTrackingView`)
- Uses `List` with `.insetGrouped` style — matches all other screens, correct dark mode contrast automatically
- Greeting in the nav title changes by time of day (morning / afternoon / evening)
- `ActiveTimerCard` is `internal` (not `private`) so both `HomeView` and `TimeTrackingView` can use it

## Time Tracking — key decisions & current state

- **Rate lives on `Project`**, not `Client`
- **Two log modes:** Duration (type hours) or Start & End (pick times, hours calculated)
- **Timer flow:**
  - Pick client + project (or leave blank = uncategorized) before starting
  - Preset chips shown as horizontal scroll for quick pre-start selection
  - Stop → auto-saves immediately with known client/project/rate/notes template
  - Animated ✓ confirmation shown ~1.8s then sheet auto-dismisses
  - No post-stop form unless user taps into the saved entry to edit
- **Presets** (`TimePreset`): named combos of client + project + optional rate override + optional notes template. Managed from `⋯` menu → Presets. Reorderable.
- **Tap any entry** to open `TimeEntryEditView` — edit all fields including notes
- **Week summary card** at top of Time Tracking screen

## Mileage Tracking — key decisions & current state

- **Two entry modes:** Address (MapKit autocomplete + MKDirections driving distance) or Manual (type miles, works offline)
- **Round trip toggle** appears once a distance is calculated; shows each-way + total breakdown
- **Month summary card** at top of Mileage screen
- **History button** (toolbar) → `MileageHistoryView`: months listed as tappable summary cards → `MileageMonthDetailView`: that month's trips with summary card + grouped list
- **Tap any trip** (in both `MileageView` and `MileageMonthDetailView`) to open `MileageTripEditView` — manual edit of all fields

## Expense Tracking — key decisions & current state

- **Categories:** Supplies, Equipment, Software, Travel, Meals, Marketing, Utilities, Rent, Insurance, Other — each has an SF Symbol icon and color defined in `Expense` statics
- **Client link:** optional — expense can be standalone or linked to a `Client`
- **Receipt photo:** attach from photo library (`PhotosPicker`) or capture via camera (`CameraView` UIImagePickerController wrapper). Stored as JPEG data on the model. Thumbnail shown in row (paperclip indicator) and full-screen preview via `ReceiptPreviewSheet`
- **Tap any entry** to open `ExpenseEditView`
- **Month summary card** shows total spend + transaction count
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` must be in Info.plist for camera/photo on real device

## Reports — key decisions & current state

- **Scope:** currently month-only (current calendar month)
- **Month at a glance card:** 2×2 grid — hours + earnings (indigo), miles + reimbursement (blue)
- **Mileage fuel analysis card:** MPG + gas price (stored in `@AppStorage`) → estimated gallons used → fuel cost vs reimbursement → net. "Edit" button in section header opens `FuelSettingsSheet`
- **Top clients:** ranked by hours, with proportional bar + earnings. Uses indigo badge matching `TimeEntryRow` style
- Reports is the convergence point for all four data types — will grow as Expenses and Income are built out

## Settings & Profile — key decisions & current state

- Accessed via gear icon (top-left toolbar) on every screen — not a tab
- **Business:** links to `ClientListView` for managing clients + projects
- **Rates & Defaults:** IRS mileage rate (live, persisted), default hourly rate
- **Fuel:** MPG + gas price (shared with Reports fuel analysis card)
- **Tax Information:** business structure picker, SE tax rate, income bracket rate
- **App:** currency placeholder, app version from bundle
- Keyboard dismisses on scroll (`scrollDismissesKeyboard(.immediately)`)

**`@AppStorage` keys used in Settings:**
- `mileage_ratePerMile` — IRS rate, defaults to `MileageTrip.defaultRatePerMile` (0.70)
- `default_hourlyRate` — fallback hourly rate when no project rate is set
- `report_mpg` — vehicle MPG for fuel analysis
- `report_gasPrice` — gas price per gallon
- `tax_selfEmploymentRate` — SE tax % (default 15.3)
- `tax_incomeBracketRate` — income tax bracket % (default 22.0)
- `tax_businessStructure` — business entity type string

`MileageTrip.ratePerMile` is now a computed static that reads from `UserDefaults` (`mileage_ratePerMile`) with a fallback to `defaultRatePerMile`. `LogTripView` syncs its local rate state from `@AppStorage` on appear.

---

## Row / visual design language (consistent across all sections)

- **Title row:** entity name (bold semibold) + colored amount/hours badge (capsule pill) on the right
- **Detail row:** small icon column (10–12pt) + label text + Spacer + prominent value (`.subheadline.weight(.medium)`)
- **Color coding:** Time = indigo, Mileage = blue, Expenses = red, Income = TBD
- Notes always last, `.caption`, `.tertiary`, `lineLimit(1)`
- `.padding(.vertical, 4)` on all rows

---

## File structure

```
BusinessTracker/
├── BusinessTrackerApp.swift
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
│   └── HomeView.swift
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
│   ├── AddressSearcher.swift
│   ├── AddressSearchView.swift
│   ├── LogTripView.swift
│   ├── MileageTripEditView.swift
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
│   └── SettingsView.swift           (also contains SettingsIcon helper)
├── Onboarding/
│   └── OnboardingView.swift          (4 pages: welcome, location, notifications, ready)
└── Views/
    ├── IncomeView.swift              (placeholder — no tab until feature is built)
    ├── ReportsView.swift             (in progress)
    └── PlaceholderView.swift
```

---

## What's left to build

**Near term (logical next steps):**
- **Income tab** — `IncomeEntry` model exists, needs full UI: log income, list view, edit view, month summary card
- **Reports expansion** — add expenses section, tax set-aside estimate (uses Settings tax rates), date range picker (week / month / quarter / year)

**Settings gaps:**
- Quarterly tax payment due dates (UI not built)
- Data export (CSV / PDF) — needs implementation
- Account / iCloud sync — future, requires CloudKit ModelContainer swap

**Polish / UX:**
- Consider moving Clients & Projects out of Time Tracking `⋯` menu entirely once Settings feels like the right home
- Home screen quick actions layout — currently a list; 2×2 card grid was attempted but had dark mode rendering issues. Worth revisiting with a different approach

---

## Design conventions used throughout

- Segmented mode toggle lives **inside** the relevant form section (not above the form)
- Summary cards at top of each main list view
- `ContentUnavailableView` for all empty states
- Entries grouped by date, swipe-to-delete on all lists
- All sheets use `NavigationStack` with Cancel/Save (or Done) toolbar items
- Gear icon (⚙️) always top-left toolbar, opens Settings as a sheet, always its own separate Liquid Glass pill
- `ToolbarSpacer(placement: .topBarLeading)` separates the gear from adjacent leading toolbar items to prevent iOS 26 Liquid Glass pill grouping
- Quick actions on Home are standard list rows inside a `Section` — clean, dark-mode safe, no custom backgrounds needed

---

## Planned platform extensions (not started)

- **Home screen widgets** (WidgetKit) — surface key stats like week hours, month earnings, month miles. Will need a shared `ModelContainer` accessible to the widget extension since SwiftData is on-device only.
- **Live Activities** (ActivityKit) — show active timer elapsed time and active trip on the Dynamic Island / lock screen. Timer and mileage are the primary candidates.
- **Lock screen actions** (WidgetKit lock screen widgets) — quick-tap buttons to start logging time or a trip without opening the app.
- **Shortcuts / Siri** (App Intents) — `AppIntent` conformances for "start timer", "stop timer", "log a trip", "log an expense". Siri can invoke these by voice. Donate intents after use to surface suggestions.

All four features will require a separate app extension target and careful thought around SwiftData container sharing (App Groups).

---

## Known patterns / gotchas

- `onChange(of: selectedClient)` only clears `selectedProject` if the project doesn't belong to the new client — prevents presets from requiring two taps
- SwiftData filtered `@Query` in detail views uses custom `init` with `#Predicate`
- `TimerState.stop()` clears client/project — always capture them into locals before calling it
- `Text +` concatenation is deprecated in iOS 26 — use string interpolation instead
- `Decimal(string:)` used for amount parsing from text fields — handles currency input safely
- `Color.tertiary` doesn't exist as a `Color` — use `.foregroundStyle(.tertiary)` or `AnyShapeStyle(.tertiary)` when mixing with `Color` in a ternary
- `scrollDismissesKeyboard(.immediately)` added to Settings form — pattern to reuse on any form with number fields
- `ToolbarSpacer(placement:)` is an iOS 26 API — use it to break Liquid Glass grouping between toolbar items in the same placement
- Onboarding gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing
- `ITSAppUsesNonExemptEncryption = NO` is set in build settings (both Debug and Release) via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` — no more TestFlight export compliance prompts
