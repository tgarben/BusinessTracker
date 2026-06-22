# BusinessTracker / Freelanced — Project Context

## What this is
A SwiftUI app for small business owners and contract workers to track time, mileage, expenses, and income. Built by Tyler with his friend/co-founder (50% stakeholder) who is the primary end user and provides product feedback after testing builds. App name may be changing to **Freelanced** — widget extension is already named `FreelancedWidget`.

## Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData + CloudKit (private database, syncs across devices when signed into iCloud)
- **Target:** iOS 26 minimum (use iOS 26 APIs freely)
- **Future platforms:** macOS (not yet). **iPad: supported** — `ContentView` uses a single plain `TabView` (no size-class branching): bottom tab bar on iPhone, App Store-style floating top tab bar on iPad. See the iPad section.
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
| iCloud Sync | ✅ Done. Dev-environment sync confirmed on device 2026-06-13. **Production schema deployed 2026-06-17** (Development → Production via "Deploy Schema Changes…"), including all `CD_*` types plus `CD_Quote`/`CD_QuoteLineItem` — TestFlight/App Store builds now sync. Reminder: any future new `@Model` or new field requires running the build on a device (to register it in the Development schema) then re-deploying Dev → Production before that build ships. **⚠️ PENDING REDEPLOY:** these additive fields — `Invoice.discountIsPercent`, `Quote.discountIsPercent`, `ExpensePreset.instantLog` (2026-06-19), and `MileageTrip.isAutoDetected` + `needsReview` + `routePoints` (Auto-Mileage Phase 0/2, 2026-06-21) — must be registered on-device then Dev → Production deployed before the next TestFlight/App Store build (all have declaration defaults, so the local store migrates fine; this is only for CloudKit sync of the new columns). |
| Quote / Estimate generator | ✅ Done (Jack's idea — pre-sale counterpart to invoicing; manual line items, business/customer info, multi-page PDF with acceptance line, status workflow, "Accept & convert to invoice"; Estimates section per client + Create Estimate quick action) |
| Package Tracking | ⬜ Future (API integration) |
| Home Screen Widgets | ✅ Done (medium 4-action + small single-action quick-action widgets; read-only Quarterly Tax Due Dates widget; Live Activity on timer start) |
| Live Activities | ✅ Done (Dynamic Island + lock screen banner while timer runs; starts when app foregrounds after widget tap) |
| Lock Screen Actions | ⬜ Deferred (built and removed — requires server push-to-start to launch Live Activity without opening app; revisit when MRR justifies Firebase Blaze) |
| Shortcuts / Siri | ✅ Done (App Intents for Start Timer, Log Time, Log Trip, Add Expense; auto-registered AppShortcuts with Siri phrases) |
| Tax deadline reminders | ✅ Done (opt-in local notifications a week + day before each quarterly IRS deadline) |
| Pro tier (paid) | 🟡 Scaffolded — provider-agnostic `Entitlements` boundary + `PaywallView` + feature gates wired at all entry points; store layer is a **stub** (`StubStoreProvider`). Drop in StoreKit 2 or RevenueCat behind `StoreProvider` to go live. See Monetization section. |

---

## Tab bar navigation

**Current tabs:** Home · Time · Mileage · Expenses · Clients (5 tabs, at iOS limit)

- **Settings** is accessible via a **profile icon** (`person.crop.circle`) in the **top-left toolbar on every screen** — opens as a sheet (alone on the left; other actions go top-right)
- **Reports** is accessible via a `chart.bar` toolbar button on the **Home screen** — opens as a sheet with drag indicator
- Tab order reflects daily-use priority: Home first, then the three active tracking tabs, Clients last

---

## Data models

- **`Client`** — `name`, `photoData: Data? = nil`, plus billing/customer fields `companyName`, `billingAddress`, `email`, `phone` (all `String = ""`, shown as "bill to" on invoices). Relationships: `projects` (cascade delete), `timeEntries` (nullify), `incomeEntries` (nullify), `expenses` (nullify), `timePresets` (nullify), `invoices` (cascade delete), `quotes` (cascade delete).
- **`Project`** — `name`, `hourlyRate`, belongs to `Client`
- **`TimeEntry`** — `date`, `client?`, `project?`, `hours`, `hourlyRate` (snapshot), `notes`, `invoice?` (nullify on invoice delete)
- **`Invoice`** — `invoiceNumber: Int`, `issueDate`, `dueDate`, `notes`, `isPaid: Bool`, `paidDate?`, `additionalAmount`/`additionalDescription` (legacy single extra, kept for migration), `discountAmount: Double`, **`discountIsPercent: Bool = false`** (when true, `discountAmount` is a percent of subtotal — Jack's standup 2026-06-19; UI has a $/% segmented toggle in the create form), `taxRate: Double` (percent), `paymentTerms`, `paymentInstructions`, `acceptedPayments`, `poNumber`, `client?`, `timeEntries` (nullify), `lineItems` (cascade → `InvoiceLineItem`). Computed: `subtotal` (time earnings + line items + legacy extra), **`effectiveDiscount`** (resolves the percent case to dollars — use this everywhere a dollar discount is needed, incl. the PDF), `discountedSubtotal` (subtotal − effectiveDiscount), `taxAmount` (discounted × taxRate%), `total` (final amount due), `formattedNumber` = "INV-001", **`displayTitle`** = "INV-001 · Clancy Bros" (in-app label — never show bare `formattedNumber` in lists/titles), **`shareFileName`** = "2026_06_19_ClancyBros_INV_001" (the PDF filename), `isOverdue`/`daysOverdue` (unpaid + `dueDate` before today). PDF via `ImageRenderer` → `makeInvoicePDF()`. **`subtotal` is pre-tax/discount; use `total` for the amount due** (InvoiceRow + detail show `total`).
- **`InvoiceLineItem`** — manual invoice line: `itemDescription`, `quantity: Double`, `unitPrice: Double`, `sortOrder`, `invoice?`. Computed `lineTotal = quantity × unitPrice`. Coexists with time-entry billing.
- **`Quote`** — pre-sale estimate paralleling `Invoice` (SoftDeletable). `quoteNumber: Int`, `issueDate`, `validUntil` (instead of dueDate), `notes`, `status: String` (raw `QuoteStatus`: Draft/Sent/Accepted/Declined/Expired), `convertedInvoiceNumber: Int` (0 = not converted), `discountAmount`, `taxRate`, `paymentTerms`/`paymentInstructions`/`acceptedPayments`, `poNumber`, `client?`, cascade `lineItems: [QuoteLineItem]`. Computed `subtotal`/`discountedSubtotal`/`taxAmount`/`total` (same math as Invoice, **manual line items only — no time entries**; Quote also has the **`discountIsPercent: Bool = false`** $/% toggle + `effectiveDiscount` computed, mirroring Invoice — added 2026-06-20), `formattedNumber` = "QUO-001" (default prefix changed EST-→QUO- in the Estimate→Quote rename, Jack's standup 2026-06-19; configurable via `doc_quotePrefix`), `displayTitle`/`shareFileName` (same pattern as Invoice — client name + date), `statusValue`, `displayStatus` (surfaces Expired when `validUntil` passed on an open quote, without mutating stored status), `isConverted`. `QuoteStatus` enum (icon + color) lives in `Quote.swift`. **User-facing terminology is "Quote" everywhere now** (was "Estimate"); the model/key names (`Quote`, `quoteNumber`, `doc_quotePrefix`, `WidgetQuickAction`/`QuickAction.createQuote`) were already quote-based.
- **`QuoteLineItem`** — manual quote line: `itemDescription`, `quantity`, `unitPrice`, `sortOrder`, `quote?`. Computed `lineTotal`. **Kept distinct from `InvoiceLineItem`** (not shared) because SwiftData relationships need a single owning inverse — on "convert to invoice" the items are copied into fresh `InvoiceLineItem`s.
- **`TimePreset`** — `name`, `client?`, `project?`, `sortOrder`, `hourlyRateOverride?`, `notesTemplate`
- **`MileageTrip`** — `date`, `startLocation`/`endLocation` (short display labels from `shortAddress`), `startAddress`/`endAddress` (full addresses for CSV export, captured via `fullAddress(_:)` at save), `miles`, `purpose`, `notes`, `waypoints: [String] = []` (intermediate stops, in order). Computed `reimbursementAmount` using `ratePerMile` (IRS rate, currently 0.70), `allStops`, `routeDescription`, `startAddressForExport`/`endAddressForExport` (full address, else display label for older trips).
- **`MileagePreset`** / **`ExpensePreset`** — standalone saved templates (no relationships). MileagePreset: `name`, `startLocation`, `endLocation`, `purpose`, `notes`, `sortOrder`. ExpensePreset: `name`, `amount: Double?` (nil = variable), `category`, `notes`, `sortOrder`, **`instantLog: Bool = false`** (per-preset — replaced the old global `expense_presetInstantSave` toggle, Jack's standup 2026-06-19; only applies to fixed-amount presets, edited via an "Instant-Log" toggle in `AddEditExpensePresetView` shown when Fixed Amount is on). Registered in the app Schema. Managed from Settings → Presets & Quick-Fill.
- **`Expense`** — `date`, `amount`, `category`, `notes`, `receiptImageData?` (legacy — kept for migration), `receiptImagesData: [Data]` (current multi-image storage), `client?` (optional link). Categories defined in `Expense.categories`. Helper statics: `categoryIcon(_:)`, `categoryColor(_:)`
- **`IncomeEntry`** — `date`, `source`, `amount`, `notes`, `client?`. Client is required in the UI (logged from ClientDetailView) but optional at the model level for migration safety.
- **`TimerState`** — `@Observable` class (not SwiftData). **Supports pause/resume.** State = `runningSince: Date?` (current running segment, nil when paused) + `accumulated: TimeInterval` (banked seconds) + `isPaused: Bool`. Derived: `isActive` (session exists, running **or** paused — use this for "is there a timer" UI branches), `isRunning` (counting now), `elapsed` (= accumulated + now−runningSince). Methods: `start`/`pause`/`resume`/`stop`. Persisted to App Group `UserDefaults` (keys `timerRunningSince`/`timerAccumulated`/`timerPaused`; migrates the legacy `timerStartDate`) so a paused or running timer survives relaunch. Mirrors state into `Activity<TimerActivityAttributes>` — the Live Activity timer **freezes via `pauseTime`** while paused (start/pause/resume call `activity.update`). `syncFromSharedStore()` (foreground) honours an external stop. Also holds `pendingWidgetAction: WidgetAction?` for routing widget deep links.
- **`WidgetAction`** — enum in `TimerState.swift`: `.startTimer`, `.logTime`, `.logTrip`, `.addExpense`, `.createInvoice`. Set by `BusinessTrackerApp.handleWidgetDeepLink(_:)`, consumed by `ContentView`.
- **`TimerActivityAttributes`** — `ActivityAttributes` struct in `BusinessTracker/Models/TimerActivityAttributes.swift`. `ContentState` holds `startDate: Date` (a *synthetic effective* start, so `now − startDate == elapsed`) + `pauseTime: Date?` (set while paused — the widget's `Text(timerInterval:pauseTime:)` freezes there). Also duplicated (identical) in `FreelancedWidget/FreelancedLiveActivity.swift` — the two targets are separate Swift modules so they cannot share the type directly. **Keep both in sync.**

---

## ⚠️ Schema changes & data safety — READ BEFORE editing any `@Model`

**App updates do NOT delete data by themselves** — iOS preserves the local store across updates; only the code is replaced. Data is only ever at risk when a **schema change can't be migrated**. There is currently **NO `SchemaMigrationPlan`** — the app relies entirely on SwiftData's automatic *lightweight* migration, which only works for additive changes. Follow these guardrails so an update never loses a user's data.

### ✅ Always safe (automatic lightweight migration)
- **Adding a new `@Model`** — register it in the `Schema` array in `BusinessTrackerApp`, run on a device, then redeploy CloudKit Dev → Production.
- **Adding a new property — ONLY with a default on the declaration:** `var foo: T = <default>`; to-many relationships must be `[T]? = nil`. **No default ⇒ the store silently fails to open** (this is the #1 rule, also under CloudKit model rules below).

### 🛑 NOT safe without a migration plan (can fail to migrate → crash / data loss)
- Renaming a model or a property
- Changing a property's type (`String`↔`Int`, `Double`↔`Decimal`, etc.)
- Removing a property that holds data
- Making an optional property non-optional, or removing its default
- Changing a relationship's cardinality, inverse, or delete rule

For ANY of the above you **must** add a `SchemaMigrationPlan` (`VersionedSchema`s + a migration stage). Don't ship the change without one.

### Pre-ship checklist for ANY `@Model` change
1. Every new stored property has a **default on the declaration**? (to-many = `[T]? = nil`, money = `Double` not `Decimal`)
2. Change is **additive only**? If not → write a `SchemaMigrationPlan` + migration stage first.
3. **Test the real upgrade path on a device:** install the *current* App Store/TestFlight build, enter real data, then upgrade to the new build and confirm nothing is lost. ⭐ Single most important safeguard.
4. Run the new build on a device so new types register in the **Development** CloudKit schema, then **Deploy Schema Changes… Dev → Production** before shipping. (CloudKit Production is **additive-only** — you can never remove/rename there.)
5. Before a major release, suggest users **Export a Backup** (Settings → Backup & Sync); they can re-import if anything ever goes wrong.

### Safety nets already in place (defense in depth)
- **iCloud mirror** (CloudKit private DB) — data isn't only on one device.
- **Full JSON Backup/Restore** (`DataBackup`, Settings → Backup & Sync) — a complete manual copy.
- **30-day soft-delete trash** — accidental deletions are recoverable.
- **No "delete & recreate store on failure" path** in the container init — a failed migration crashes / fails to open (recoverable by fixing the build), rather than silently wiping the store. Keep it that way; never add a `catch` that deletes the store.

## iCloud Sync — current state & notes

- **Container:** `iCloud.com.garbenTechnologies.BusinessTracker`
- **Bundle ID:** `com.garbenTechnologies.BusinessTracker`
- **Entitlements file:** `BusinessTracker/BusinessTracker.entitlements` — has `com.apple.developer.icloud-container-identifiers` + `com.apple.developer.icloud-services: CloudKit`
- **ModelContainer init:** `BusinessTrackerApp.swift` tries CloudKit private DB first; falls back to local-only if unavailable (simulator, not signed in, etc.)
- **Xcode capability:** iCloud → CloudKit must be enabled in Signing & Capabilities with container `iCloud.com.garbenTechnologies.BusinessTracker`
- **Known limitation:** CloudKit does not support `Decimal` natively — if sync issues arise, monetary fields may need to be stored as `Double` (cents as Int) with a migration plan
- Sync only works on a real device signed into iCloud; simulator always uses the local fallback
- **Visible status:** `BusinessTrackerApp.cloudKitEnabled` (set during container init — true = CloudKit store, false = local-only fallback) + a CloudKit `accountStatus()` check drive **`CloudSyncRow`** (`Settings/CloudSyncStatusView.swift`), a read-only "iCloud Sync" row in the Settings **"Backup & Sync"** section (alongside the manual export/import). States: On (green) / Paused — signed out (orange) / This Device — local-only fallback (orange) / Checking. **Data is always written locally first; iCloud is a background mirror** — local is never the only-missing copy.

### Settings / business-info sync (NSUbiquitousKeyValueStore)

SwiftData models sync via CloudKit, but **business info, profile, and financial defaults live in `@AppStorage` (`UserDefaults.standard`), which is device-local.** `Settings/CloudKeyValueSync.swift` bridges a fixed allow-list of those keys to `NSUbiquitousKeyValueStore` (iCloud key-value store) so they follow the user across devices.

- **`CloudKeyValueSync.start()`** is called from `BusinessTrackerApp` on both the main `.task` and the onboarding `.task` (so a 2nd device pre-fills onboarding from iCloud). Idempotent.
- **Direction:** observes `NSUbiquitousKeyValueStore.didChangeExternallyNotification` (pull iCloud→`UserDefaults`, which `@AppStorage` re-renders from) and `UserDefaults.didChangeNotification` (push local→iCloud). An `isApplyingRemoteChange` guard prevents feedback loops.
- **Launch merge:** pull (remote wins on conflict) then push (uploads local-only keys). Keys never set by the user are absent from `UserDefaults` (still at `@AppStorage` default) so they're skipped — a local default never clobbers a remote value.
- **Synced keys** (`CloudKeyValueSync.syncedKeys`): `user_name`, `user_lastName`, `user_primaryUse`, `user_avatar` (downscaled JPEG `Data`); all `business_*` (incl. invoicing defaults + `business_paymentLink`); `app_currencyCode`; `mileage_ratePerMile`, `default_hourlyRate`, `report_mpg`, `report_gasPrice`, `tax_selfEmploymentRate`, `tax_incomeBracketRate`, `tax_businessStructure`; `mileage_purposePresets`, `mileage_favoriteAddresses`.
- **Intentionally NOT synced** (device-specific): `home_*` layout/section order, widget config, notification toggles (`tax_remindersEnabled`), `mileage_autoDetectEnabled` (Auto-Mileage opt-in), `hasCompletedOnboarding`. (The old `expense_presetInstantSave` global key was removed — instant-log is now a per-`ExpensePreset` field, which syncs via CloudKit like any other model field.)
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
- **Reorderable + toggleable sections** (sections gained an enable/disable model 2026-06-20, mirroring quick actions): order in `@AppStorage("home_sectionOrder")`, the enabled subset in `@AppStorage("home_sectionEnabled")`. `HomeView.isVisible(_:)` renders a section only if it's in the enabled set (Quick Actions additionally needs ≥1 enabled action). Active timer card + Overdue invoices card are always pinned at top (not part of this system). The `HomeSection` enum has **14 cases**: the 3 originals (`quickActions`, `todayGlance`, `thisWeek`) + 8 focus "hero" sections + 3 general sections (see below).
- **Focus hero sections** (each App Focus surfaces a **primary + secondary** pair via `HomeSection.heroes(forUse:)`; all `off` by default unless App Focus or the user enables them):
  - Time Tracking → **`readyToInvoice`** (unbilled time $ + hours, Pro-gated "Create Invoice" CTA) + **`topClients`** (top 3 clients this month, hours bars + earnings).
  - Mileage → **`mileageDeduction`** (YTD miles × `MileageTrip.ratePerMile` = est. deduction $) + **`recentTrips`** (last 3 trips + "Log Trip" CTA).
  - Expenses → **`spendingByCategory`** (this month's top 3 categories, bars) + **`thisMonthVsLast`** (spend + delta vs last month, up/down arrow).
  - Invoicing → **`outstanding`** (total unpaid $ + count, overdue in subtitle) + **`quotePipeline`** (open Draft/Sent quotes count + total value).
- **General sections** (not tied to a focus; opt-in via Customize Home): **`thisMonth`** (month twin of This Week — hours + earnings), **`moneySnapshot`** (month income − expenses = net, with income/expense breakdown), **`recentActivity`** (merged newest-first feed across time/mileage/expenses, last 4).
- All hero/general sections read from **`HomeMetrics`** (a struct computed once in `HomeView.metrics`, passed to `HomeSectionCard` — avoids a giant param list) plus the `HomeActivityItem` struct for the feed. Empty/zero states show a muted placeholder. `HomeView` now also `@Query`s `IncomeEntry` + `Quote` for these. **All `metrics` aggregation is in one computed property** — when adding a section, extend `HomeMetrics` + that property.
- **App Focus CURATES sections** (not just order). `HomeSection.curation(forFocuses:)` returns `(order, enabled)`: each selected focus's `heroes(forUse:)` (primary+secondary) lead in selection order, then Quick Actions / Today / This Week; remaining sections are appended to `order` (disabled) so they stay toggleable. Multiple focuses → union of heroes. No focus → balanced default (the original 3). Both `SettingsView.toggleFocus` and onboarding `AboutYouPage.save()` write **both** `home_sectionOrder` and `home_sectionEnabled` from this. (Replaced the old order-only `orderString(forUse:)`/`orderString(forFocuses:)`, deleted.)
- **Configurable quick actions:** Enabled actions + order stored in `@AppStorage("home_quickActionOrder")` and `@AppStorage("home_quickActionEnabled")`. Defined by `QuickAction` enum in `HomeView.swift`.
- **Quick Actions:** Start Timer (indigo), Log Time (indigo), Log Trip (blue), Add Expense (red), Create Invoice (purple), Generate Quote (teal — `QuickAction.createQuote`, label was "Create Estimate"). 2-wide `LazyVGrid` of individually rounded cards.
- **Zero quick actions:** if `home_quickActionEnabled` is empty, the Quick Actions section is hidden from Home regardless of its own enabled flag (`isVisible` guard). In `HomeLayoutEditor`, the Quick Actions row shows a "No actions enabled" caption under its title (it's still toggleable/draggable like every other section row).
- **Customize Home sheet** (`slider.horizontal.3` toolbar button → `HomeLayoutEditor`): always in edit mode (`.constant(.active)`). A **segmented Picker** (`Sections` / `Quick Actions`) switches which group you edit — this is what keeps each screen short (the original complaint was sections+actions stacked together). **Each tab is ONE list of all that type's items**, each row = icon + title + a trailing **`Toggle`** (on/off) and the edit-mode **drag grip (☰)** for reorder (`.onMove`). State is `sectionsAll: [HomeSection]` + `sectionEnabledSet: Set` (and `actionsAll`/`actionEnabledSet`) — reorder mutates the `*All` array, the toggle flips membership in the `*Enabled` set. **Deliberately NOT an "enabled vs available / add-remove" two-list split**: that earlier attempt moved items *between* two `@State` arrays (appends), which under forced-active edit mode left newly-added rows without their − / ☰ decorations, and the `.id()`-rebuild workaround for that reset the scroll position on every add. Keeping all rows present in one list (only a Bool/order changes, never an append) sidesteps both bugs. Save writes `sectionsAll` order + the enabled subset (in order); Cancel discards.
- **Reports button:** `chart.bar` toolbar button (top-right, alongside customize button) → `ReportsView` as a sheet with `.presentationDragIndicator(.visible)`
- **Section rendering:** Each section is a single `List` row (`HomeSectionCard`) with a clear background so drag-to-reorder in the editor works correctly. Home uses `.listStyle(.plain)` with `Color(.systemGroupedBackground)`.
- **Today at a glance:** three stat cells (hours, miles, spend). Stats go muted when empty.
- **This week:** hours + earnings cells with per-day average subtitle.
- `ActiveTimerCard` is `internal` (not `private`) so both `HomeView` and `TimeTrackingView` can use it.

**`@AppStorage` keys for Home:**
- `user_name` — first name for greeting (Home greeting uses first name ONLY)
- `user_lastName` — last name; appears on invoices + data exports only, never the Home greeting. `userFullName()` free function in `SettingsView.swift` builds "First Last" from UserDefaults for non-View code (invoice PDF, Reports PDF, CSV header).
- `user_primaryUse` — **"App Focus"** in Settings: **multi-select**, comma-separated rawValues from `["Time Tracking","Mileage","Expenses","Invoicing"]` (a 2×2 grid of tappable chips). Drives Home section curation via `HomeSection.curation(forFocuses:)` (writes both `home_sectionOrder` + `home_sectionEnabled`). Each focus maps to a primary+secondary hero pair via `HomeSection.heroes(forUse:)` ("Time & Billing" legacy value → Time Tracking pair).
- `home_sectionOrder` — comma-separated `HomeSection` rawValues (full order, incl. disabled)
- `home_sectionEnabled` — comma-separated **enabled** `HomeSection` rawValues (default `quickActions,todayGlance,thisWeek` — existing users keep the original 3; heroes off until App Focus/editor enables them)
- `home_quickActionOrder` — comma-separated `QuickAction` rawValues (display order)
- `home_quickActionEnabled` — comma-separated enabled `QuickAction` rawValues

**App Focus → hero pair mapping** (`HomeSection.heroes(forUse:)`):
- Time Tracking → `readyToInvoice` + `topClients` · Mileage → `mileageDeduction` + `recentTrips` · Expenses → `spendingByCategory` + `thisMonthVsLast` · Invoicing → `outstanding` + `quotePipeline`
- Curation order for a single focus: `<primary>, <secondary>, quickActions, todayGlance, thisWeek`. Multiple focuses → all heroes (in selection order) then the base three. No focus → `quickActions, todayGlance, thisWeek`.

**To add a NEW Home section:** add a `HomeSection` case + `title`; add a `HomeSectionCard` content builder + a case in its `switch`; add `sectionIcon`/`sectionColor` cases in `HomeLayoutEditor`; wire any new metric into `HomeMetrics` + the `HomeView.metrics` computed property; extend `defaultOrderString`; optionally add it to `heroes(forUse:)`. (The 7 sections brainstormed 2026-06-20 — This Month, Money Snapshot, Recent Activity, Top Clients, Quote Pipeline, Spending vs Last Month, Recent Trips — are all **built**.)

## Time Tracking — key decisions & current state

- **Rate lives on `Project`**, not `Client`
- **Two log modes:** Duration (type hours) or Start & End (pick times, hours calculated)
- **Timer flow:**
  - Pick client + project (or leave blank = uncategorized) before starting
  - Preset chips shown as horizontal scroll for quick pre-start selection
  - **Pause / Resume** mid-session (Jack's request) — `TimerSheet` shows Pause/Resume + Stop while active; `ActiveTimerCard` has an inline pause/resume button and turns orange while paused. Banks elapsed via `accumulated`; the Live Activity freezes. No need to start a new timer after a break.
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

- **THREE ways to log a trip** (2026-06-21): (1) **manual entry** (the `+` FAB → `LogTripView`), (2) **live tracked trip** (the green play/`location.fill` FAB → `TripTracker`, the reliable battery-friendly GPS tracker), and (3) **automatic detection** (`DriveDetector`, opt-in Always-location background, Settings → Automatic Mileage). Manual + live-track ship enabled; auto is the off-by-default power-user option. The Mileage tab shows **two stacked FABs** (green Start Tracked Trip on top, blue manual `+` below) when not tracking.
- **Live Trip Tracking (`Mileage/TripTracker.swift`)** — `@MainActor @Observable` singleton (`TripTracker.shared`), **When-In-Use** auth (NOT Always — background tracking is allowed because the session starts in the foreground + shows the blue status-bar indicator via `showsBackgroundLocationIndicator`; needs the `location` background mode, already present). `startTrip`/`pause`/`resume`/`stopTrip`/`cancelTrip`. Accumulates live `distanceMeters` (summed `CLLocation.distance`, sub-meter jitter ignored) + elapsed time (banked like `TimerState`); captures the route into `MileageTrip.routePoints` (Phase-2 storage, downsampled ≤500 pts). On **stop** it inserts a **normal** trip (`isAutoDetected = false`, `needsReview = false`), reverse-geocodes endpoints async, and returns it so `MileageView` opens its editor to categorize. Container set from `BusinessTrackerApp` at launch. A pinned **`TripInProgressCard`** (top of the Mileage list) shows live miles + elapsed + pause/resume + stop. Mirrors a Live Activity (below). **Double-log guard:** `DriveDetector.maybeStartDrive` bails while `TripTracker.shared.isTracking`.
- **Two entry modes (within manual/edit):** Address (MapKit autocomplete + MKDirections driving distance) or Manual (type miles, works offline)
- **Address autocomplete:** uses `AddressSearchView` which wraps `AddressSearcher` (MKLocalSearchCompleter). Callback delivers a `LocationResult` enum — either `.completion(MKLocalSearchCompletion)` or `.coordinate(CLLocationCoordinate2D, label: String)`.
- **Current location:** "Use Current Location" row at the top of `AddressSearchView`. Uses `LocationManager` (@Observable, CLLocationManagerDelegate) to request location, then CLGeocoder to reverse-geocode to a label. Requires `NSLocationWhenInUseUsageDescription` (already in build settings).
- **Address label format:** stored addresses use `shortAddress(_:)` helper — strips country from MapKit subtitle, keeps city + state for POIs (drops street from subtitle so result is "Place Name, City, State"), keeps "Street, City, State" for plain addresses.
- **Round trip toggle** appears once a distance is calculated; shows each-way + total breakdown
- **Month summary card** at top of Mileage screen — hidden when no trips exist (only `ContentUnavailableView` shown)
- **History button** (toolbar) → `MileageHistoryView`: months listed as rows with month name bold + miles badge + trip count — `MileageMonthDetailView`: that month's trips with summary card + grouped list
- **Tap any trip** (in both `MileageView` and `MileageMonthDetailView`) to open `MileageTripEditView`
- **`MileageTripEditView`** has a Manual / Address mode toggle matching `LogTripView` — switch to Address mode to pick new locations and recalculate distance
- **Swipe to delete** shows confirmation dialog before deleting
- **Trip categories** (renamed from "Trip Purposes" — Jack's standup 2026-06-19; the storage key `mileage_purposePresets` and the `MileageTrip.purpose` / chip-binding `purpose` names are UNCHANGED — only user-facing labels became "Category"/"Trip Categories"): quick-fill chips below the category field in `LogTripView`/`MileageTripEditView`, backed by `@AppStorage("mileage_purposePresets")` (comma-separated; defaults Client Visit, Office, Airport, Errand, Medical). Managed in Settings → Trip Categories (`PurposePresetsEditor`), which now supports **tap-to-rename** (alert with a text field) in addition to add / swipe-delete / reorder. Shared `PurposeChipsRow` view in `MileagePurposePresets.swift`.
- **Mileage preset addresses are searchable** (Jack's standup 2026-06-19): `AddEditMileagePresetView` start/end use `SearchableAddressRow` (in `MileagePresetsView.swift`) — a text field + 🔍 that opens the shared `AddressSearchView` autocomplete and fills the field via `fullAddress(_:)`. The stored strings are still geocoded when the preset is applied in `LogTripView`.
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
- **Speed-dial FAB:** `ExpensesView` has a floating red **+** button bottom-right (mirrors the Time tab's floating play button). Tapping it springs open a speed-dial of expense-preset shortcuts + a "New Expense" option; the + rotates 45° to an ✕, with a tap-scrim to dismiss. Default: a preset opens the pre-filled Add Expense form. **Instant-Log is now per-preset** (`ExpensePreset.instantLog`, Jack's standup 2026-06-19 — replaced the global `expense_presetInstantSave` toggle): tapping a preset that has `instantLog` on **and** a fixed amount > 0 saves immediately (`ExpensesView.selectPreset`); everything else opens the form. The toggle lives in `AddEditExpensePresetView` (visible only when Fixed Amount is on) and a ⚡️ `bolt.fill` badge marks instant-log presets in the list. If no presets exist, the FAB just opens a blank Add Expense.
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
- **Totals:** `subtotal` → minus `effectiveDiscount` → `discountedSubtotal` → plus `taxAmount` (`taxRate%`) → `total`. New invoices pre-fill tax rate / terms / accepted payments / instructions from the business defaults (editable per invoice).
- **Discount can be $ or %** (Jack's standup 2026-06-19): the create form's Discount row has a `$`/`%` segmented `Picker` bound to `discountIsPercent`. The model stores the raw `discountAmount` + the flag; `Invoice.effectiveDiscount` resolves it to a dollar figure used by `discountedSubtotal`, the detail "Discount (N%)" row, and the PDF (`makeInvoicePDF` passes `effectiveDiscount`). In the create form, the computed `discount` is the dollar value, `discountInput` is the raw typed number. **The same $/% toggle is on Quote too** (`Quote.discountIsPercent`/`effectiveDiscount`, `CreateQuoteContent` + `QuoteDetailView` + `makeQuotePDF`) — added 2026-06-20.
- **Deleted-invoice frees its time entries** (Jack bug, standup 2026-06-19): `CreateInvoiceContent.unbilledEntries` now includes entries whose linked invoice is *soft-deleted* (`$0.invoice == nil || $0.invoice?.deletedDate != nil`), so deleting an invoice makes its time entries available to bill again. Saving the new invoice reassigns `entry.invoice`, which detaches them from the trashed invoice. (Trade-off: restoring that trashed invoice no longer shows those entries — acceptable, the alternative was them being stuck forever.)
- **Document naming** (Jack's standup 2026-06-19): `DocumentNaming` (in `Views/DocumentPDF.swift`) builds both the **share filename** (`fileName(date:clientName:number:)` → `2026_06_19_ClancyBros_INV_001`, fed to `DocumentPDFSpec.fileName` and used for the temp `.pdf` path) and the **in-app label** (`displayTitle(clientName:number:)` → `INV-001 · Clancy Bros`). `Invoice.shareFileName`/`displayTitle` and `Quote.shareFileName`/`displayTitle` wrap it. **Use `displayTitle` for any in-app invoice/quote label** (InvoiceRow, detail nav titles, preview titles, Recently Deleted rows) — never bare `formattedNumber`.
- **`CreateInvoiceContent`** pre-fills on first `onAppear` only (guarded by `didPrefill`) so user edits aren't clobbered. `DraftLineItem` is the editing struct; valid drafts (non-empty description + non-zero total) become `InvoiceLineItem`s on save.
- **Preview-on-create:** `save()` persists (`modelContext.save()` so the render sees finalized relationships), generates the PDF, and presents **`DocumentPreviewView`** (`Views/DocumentPreviewView.swift`, PDFKit + ShareLink) via `.sheet(item: $preview)`. Closing the preview (`onDismiss`) dismisses the create form. Same pattern in `CreateQuoteContent`. So creating an invoice/estimate drops the user straight into a shareable preview of the finished document.
- **PDF** (`makeInvoicePDF`): multi-page, letter size. `BusinessInfo.load(fallbackName:)` reads the business `@AppStorage` keys from `UserDefaults.standard` (falls back to `user_name`) including the optional **logo** (`business_logo` Data → `BusinessInfo.logoData` → `DocumentPDFSpec.logoData`, rendered top-left of the header). `firstPageMax = 6` rows (taller header), `contPageMax = 10`. Footer (totals + payment + notes + tax ID) renders on the last page only.

## Monetization / Pro tier — scaffolding (store layer not yet wired)

Freemium model scaffolded but **not yet revenue-generating** — the store layer is a stub. Decided: freemium with monthly/annual subscriptions + a lifetime one-time unlock (see the monetization brief). RevenueCat vs native StoreKit 2 is deferred; the architecture is provider-agnostic so either slots in behind one protocol.

- **⚑ Master launch switch: `Entitlements.monetizationEnabled` (currently `false`).** While `false`, monetization is fully **dormant** — `isProEffective` always returns `true`, so every feature is unlocked, no paywall ever appears, the client cap is off, and the Settings "Subscription" section is hidden. This lets the app be developed/tested with zero paywall friction. **Flip to `true` only at App Store submission, and only after a real `StoreProvider` is wired** (shipping `true` with `StubStoreProvider` would show a fake paywall to real users).
- **`Pro/Entitlements.swift`:**
  - **`Entitlements`** — `@MainActor @Observable` single source of truth, injected at the app root (`BusinessTrackerApp`) via `.environment(entitlements)` on both ContentView and OnboardingView; read with `@Environment(Entitlements.self)`. `refresh()` is called on launch `.task` and on foreground. Feature code checks **`isProEffective`** (never `isPro` directly — `isProEffective` folds in the DEBUG override).
  - **`StoreProvider` protocol** — the seam RevenueCat **or** StoreKit 2 implements (`isProActive()`, `purchase(_:)`, `restore()`). `Entitlements` talks only to this, so swapping providers never touches gating code. Currently backed by **`StubStoreProvider`** which simulates a successful purchase (so the paywall→unlock flow is testable) — **replace before shipping.**
  - **`ProPlan`** (monthly/annual/lifetime) — placeholder prices + `productID`s (`com.garbenTechnologies.BusinessTracker.pro.*`, TODO confirm in App Store Connect). Real localized prices come from the store layer.
  - **`ProFeature`** (invoicing/quotes/reports/dataExport/unlimitedClients) — the gated capabilities; carries title/blurb/icon for paywall context.
  - **DEBUG override:** `debugProOverride` (persisted to `debug_proOverride` UserDefaults) + a "Debug: Force Pro" toggle in Settings (DEBUG only) to exercise gated vs. ungated flows without the store.
- **`Pro/PaywallView.swift`** — branded upgrade sheet (feature list + plan picker + subscribe/restore). Takes an optional `ProFeature` for a tailored header ("Unlock Invoicing"). Driven entirely through `Entitlements`. Also defines **`ProUpgradeBanner`** — the gradient free→Pro CTA card.
- **Upgrade CTA / paywall launcher:** `ProUpgradeBanner` sits at the **top of Settings, under the profile header** (`SettingsView.showUpgradeBanner`). It's the real free→Pro CTA once monetization is live (`monetizationEnabled && !isProEffective`), and a **paywall preview launcher in DEBUG builds while monetization is dormant** (so it never shows to real users in a dormant release build). One button serving both roles. The lower "Subscription" section (shown only when `monetizationEnabled`) holds status / Restore Purchases / the DEBUG force-Pro toggle.
- **Gating pattern (one line per call site):** each gated container holds `@State private var paywall: ProFeature?`, attaches the **`.proPaywall($paywall)`** modifier (a `View` extension wrapping `.sheet(item:)`), and buttons do `if pro.isProEffective { action } else { paywall = .feature }`. Local presentation (not a single global sheet) so it works correctly even when triggered from inside other sheets. **To gate a new feature: add a `ProFeature` case + that one-liner.**
- **Gated entry points wired:** Home quick actions (Create Invoice/Estimate) + Reports toolbar button (`HomeView`/`HomeSectionCard`); widget/Shortcut Create-Invoice route (`ContentView`); Client detail Invoices + Estimates `+` buttons (`ClientDetailView`); new-client FAB past the free cap (`ClientsView`, `Entitlements.freeClientLimit = 2`, `canCreateClient(currentCount:)`); Settings CSV export buttons. **Free vs Pro split** matches the brief: tracking stays free; invoicing/quotes/reports/export/unlimited-clients are Pro.
- **Not gated (deliberate):** iCloud sync — it's structural (SwiftData CloudKit container), can't be cleanly per-feature gated yet; revisit if sync becomes a Pro differentiator. Also: real Terms of Use / Privacy Policy URLs in the paywall footer are TODO (required by App Review).

## Quotes / Estimates — key decisions & current state

The pre-sale counterpart to Invoicing (Jack's idea). Mirrors invoicing infrastructure but for work that hasn't happened yet.

- **Models:** `Quote` + `QuoteLineItem` (see Data models). Manual line items only — no time-entry billing. Registered in the app Schema + `purgeExpiredTrash` (soft-delete, 30-day trash like invoices). `Client.quotes` is a cascade relationship (only cascades at permanent purge, same as invoices).
- **Views** (`TimeTracking/QuoteView.swift`): `QuoteRow` (status-colored, teal totals), `CreateQuoteView`/`CreateQuoteContent` (form: Quote For / details / line items / totals / payment terms / notes — pre-fills tax & terms from business defaults on first `onAppear`, guarded by `didPrefill`), `QuoteQuickActionSheet` (client picker → create, for the Home quick action), `QuoteDetailView` (status `Picker`, PDF `ShareLink`, **Accept & Convert to Invoice**).
- **Status workflow:** `QuoteStatus` Draft → Sent → Accepted/Declined; `displayStatus` derives **Expired** when an open quote's `validUntil` passes. Set via a menu picker in `QuoteDetailView`; changing it invalidates the cached PDF.
- **Convert to Invoice:** `QuoteDetailView.convertToInvoice()` creates a new `Invoice` (next number from an invoices `@Query`), copies discount/tax/terms/PO/notes + each `QuoteLineItem` → fresh `InvoiceLineItem`, sets `quote.status = Accepted` + `convertedInvoiceNumber`, then presents the new `InvoiceDetailView`. Guarded behind a confirmation dialog.
- **PDF** (`makeQuotePDF` in QuoteView.swift): builds a `DocumentPDFSpec` and calls the **shared `makeDocumentPDF`** (`Views/DocumentPDF.swift`) — the same renderer invoices use. "QUOTE" header (was "ESTIMATE"), "Valid Until" meta, status, and an **acceptance/signature line** (Accepted By / Date, via `showAcceptanceLine`). Earlier this duplicated the invoice PDF; unified 2026-06-18.
- **Auto-Sent on share:** sharing an estimate (from `QuoteDetailView` or the create-time preview) advances Draft → Sent, but only on a genuine send — `ActivityShareSheet` + `ShareOutcome.wasSent` exclude Save to Files/Photos/Copy/Print so saving locally doesn't count.
- **Access:** Quotes section in `ClientDetailView` (above Invoices — create/view/soft-delete; section header + empty/delete copy all say "Quote" now) + a **Generate Quote** Home quick action (`QuickAction.createQuote`, teal, `list.clipboard.fill`). No widget/Shortcut entry point (deliberately scoped out).

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

- **Titled "Profile"** with a centered avatar header at the top — a tappable `PhotosPicker` wrapping `UserAvatar` (uploaded photo, else indigo gradient circle + initials), with a camera badge + "Remove Photo" button. Below: name and "<AppFocus> · Freelanced" subtitle. Still presented as a sheet from the gear icon.
- **Profile picture:** `UserAvatar` (`Settings/UserAvatar.swift`) is the user's own avatar (indigo — distinct from the teal `ClientAvatar`). Stored in `@AppStorage("user_avatar")` as a **downscaled JPEG thumbnail** (`UserAvatarImage.processed` → longest edge ≤256px, JPEG q0.7) so it fits the iCloud key-value store quota; `user_avatar` is in `CloudKeyValueSync.syncedKeys` so it follows the user across devices. Tapping the avatar opens a **`confirmationDialog` with Take Photo / Choose from Library / Remove Photo** (the last only when a photo is set; clears back to initials). **Both Take Photo and Choose from Library go through `CameraView`** (now generalized: `sourceType` + `allowsEditing`) so the user gets the built-in square crop ("Move and Scale") before it's saved — no separate crop UI needed. Receipts still use `CameraView()` with defaults (`.camera`, no editing). The onboarding About You page has a simpler direct `PhotosPicker` (no crop; falls back to the `OnboardingBadge` person glyph when unset).
- **Profile button uses the avatar:** the top-left Settings toolbar button on every tab renders **`ProfileToolbarLabel`** (`Settings/UserAvatar.swift`) — the user's circular avatar when set, else the `person.fill` glyph. Reads `@AppStorage("user_avatar")`.
- **Condensed layout:** the long config sections are grouped behind two `NavigationLink` sub-pages (computed `@ViewBuilder` props on `SettingsView`, so they keep the same `@AppStorage`/`@FocusState`/helpers — no state moved): **Business & Invoicing** (`businessInvoicingPage` — Logo + Business Information + Invoicing Defaults + Document Numbering) and **Rates & Taxes** (`ratesTaxPage` — Rates & Defaults + Fuel + Tax Information + Quarterly Tax Dates). Both reuse `keyboardDoneToolbar`. The top level keeps the profile header, upgrade banner, Personalization, Presets & Quick-Fill, Data Export, Recently Deleted, Subscription, More Apps, and App sections.
- **More from Garben Technologies** section (`Settings/MoreAppsView.swift`): promotes the studio's other apps (`GarbenApps.all`). Each `PromotedApp` row is a rounded app-icon tile (`iconAsset` image if present, else SF Symbol fallback via `UIImage(named:) != nil` guard) + name/tagline + a trailing CTA. Link resolution (`PromotedApp.link`): **`appStoreURL` → "Get" pill → App Store**; else **`testFlightURL` → "Beta" pill (airplane icon) → TestFlight**; else **"Coming soon"** (not tappable). CradleLight is live (App Store URL + `cradleLightLogo` asset). Sipfolio is TestFlight-only — paste its public `https://testflight.apple.com/join/…` link into `testFlightURL`. Taglines still marked TODO to confirm. **To add/promote an app: append to `GarbenApps.all` with an `appStoreURL` or `testFlightURL` (and optionally an `iconAsset` image in Assets).**
- **Business Information** section (name, address, phone, email, website, tax ID/EIN) + **Invoicing Defaults** (payment terms picker, default sales tax %, accepted payments, payment instructions) — all `@AppStorage`, pulled into invoices. `businessField(...)` helper renders the labeled multiline text rows.
- **Presets & Quick-Fill section** links to Trip Categories, Mileage Presets, and Expense Presets editors. (The Time Presets row is a `Button` presenting `PresetsView` as a sheet — it now carries `.buttonStyle(.plain)` so its label renders primary like the NavigationLink rows, instead of the blue accent tint Jack flagged.)
- Accessed via gear icon (top-left toolbar) on every screen — not a tab
- **Personalization:** first name (Home greeting), last name (invoices/exports only), and **App Focus** — multi-select chips ("Time Tracking / Mileage / Expenses / Invoicing") replacing the old single-select Primary Use picker; resets Home section order
- **Rates & Defaults:** IRS mileage rate (live, persisted), default hourly rate
- **Fuel:** MPG + gas price (shared with Reports fuel analysis card)
- **Tax Information:** business structure picker, SE tax rate, income bracket rate
- **Quarterly Tax Due Dates:** all four IRS estimated payment deadlines shown with period labels; next upcoming date highlighted in orange with days-until countdown
- **Backup & Restore** (`Settings/DataBackup.swift`, in the Settings **"Backup & Sync"** section below the `CloudSyncRow`): **Export Backup (.json)** writes a complete copy of every record (all 13 models, incl. soft-deleted) + the synced `@AppStorage` settings to a `Freelanced_Backup_<date>.json` file shared via the share sheet. **Import from Backup…** (`.fileImporter` → confirmation) re-inserts it. Relationships survive via **export-scoped UUIDs** (`persistentModelID` isn't portable). Import is **additive** (inserts alongside existing data — meant for a fresh install; warns about duplicates). **Not Pro-gated** — it's a data-integrity safety net. `SettingValue` enum carries the typed settings (string/double/bool/data).
- **Data Export:** scoped CSV exports — **Export All Data** plus per-category **Time Entries / Mileage / Expenses** buttons, each limited to a selected **date range** (`ExportRange`: All Time / This Month / This Quarter / This Year / Custom with from/to `DatePicker`s). `exportBounds`/`inExportRange(_:)` filter every row builder by `date`; the range is written into the CSV header (`Range,…`) and the filename (`Freelanced_<Scope>_<Range>_<date>.csv`). `ExportScope` + `buildCSV(_:)` compose from `timeRows()`/`mileageRows()`/`expenseRows()` (each `[String]`) on top of `csvHeaderRows()` (name + export date + range). Mileage rows export the **full address** (`startAddressForExport`/`endAddressForExport`) plus a **Stops** column (waypoints). Fields are RFC-4180 quote-escaped via `csvField(_:)`. **CSV exports now preview before sharing** (Jack's standup 2026-06-19): an export button sets `ExportItem(csv:title:preview: true)`, which routes the `$exportItem` sheet to **`CSVPreviewView`** (scrollable monospaced text + a Share toolbar button via `ActivityShareSheet`) instead of going straight to the system share sheet — mirroring the invoice/quote `DocumentPreviewView` flow. The JSON **Export Backup** path still shares directly (`preview: false`).
- **App:** currency placeholder, app version **+ build number** from bundle (`appVersionString` → "1.0 (42)" from `CFBundleShortVersionString` + `CFBundleVersion`)
- Keyboard dismisses on scroll (`scrollDismissesKeyboard(.immediately)`)
- **Note:** Clients & Projects management was removed from Settings — it now lives entirely in the Clients tab

**`@AppStorage` keys used in Settings:**
- `user_name` — first name, shown in Home greeting
- `user_primaryUse` — App Focus (multi-select); re-curates `home_sectionOrder` + `home_sectionEnabled` on change
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
- **About You:** first + last name fields (last name labeled "appears on invoices and data exports") + **App Focus multi-select chips** (Time Tracking / Mileage / Expenses / Invoicing) — matches Settings. Writes `user_name`, `user_lastName`, comma-separated `user_primaryUse`, and **both** `home_sectionOrder` + `home_sectionEnabled` via `HomeSection.curation(forFocuses:)`. Continue disabled until a first name is entered.
- **Your Business (skippable):** business name, address (shared `AddressEntryField` w/ line 2), phone (auto-formatted), email, website, tax ID — writes the same `business_*` `@AppStorage` keys Settings uses, so invoices work out of the box. Skip advances.
- **Permissions (skippable):** Location, Camera (receipt photos, `AVCaptureDevice.requestAccess`), Notifications cards, each Enable → checkmark. No Photos card — `PhotosPicker`/PHPicker needs no permission.
- **Ready:** green success screen, greets by name.
- Gated by `@AppStorage("hasCompletedOnboarding")` — set to `false` in UserDefaults to re-trigger for testing.

---

## Recently Deleted (soft-delete) — key decisions & current state

The seven user-facing record types — **TimeEntry, MileageTrip, Expense, IncomeEntry, Invoice, Quote, Client** — use **soft-delete**: deleting sets `deletedDate = .now` instead of removing the row. Items live in a 30-day "Recently Deleted" area, can be restored, and are permanently purged after 30 days.

- **`SoftDeletable` protocol** (`Models/SoftDeletable.swift`): `var deletedDate: Date? { get set }` + `trashDaysRemaining` computed helper (0...30). All seven in-scope models conform and declare `var deletedDate: Date? = nil` (CloudKit-safe optional with default).
- **Every `@Query` for these types filters `deletedDate == nil`** so trashed items vanish from all normal lists, pickers, reports, exports, and aggregates. Predicate-`init` queries (ClientDetailView, CreateInvoiceContent, the Month-detail views) AND `&& deletedDate == nil` into their existing predicate.
- **Relationship-array totals must also filter** — `ClientCell` computes earnings/hours from `client.timeEntries`/`incomeEntries` directly, so those sites use `.filter { $0.deletedDate == nil }`. (Invoice line items in `InvoiceDetailView`/PDF intentionally do NOT filter — an issued invoice is a finalized snapshot.)
- **Delete sites set `deletedDate = .now`** instead of `modelContext.delete(...)`. Exceptions that remain hard-delete: `TimePreset` (PresetsView), `Project` (AddEditClientView inline), and the eager-insert cancel path in AddEditClientView (`modelContext.delete(client)` discards an unsaved client).
- **`RecentlyDeletedView`** (`Settings/RecentlyDeletedView.swift`): seven `@Query`s filtered to `deletedDate != nil`, merged into a unified sorted list. Swipe leading = Restore (`deletedDate = nil`), swipe trailing = Delete permanently (`modelContext.delete`). "Delete All" toolbar button. Shows "Nd left" per row (orange when ≤3 days). Reached via Settings → Data Management → Recently Deleted.
- **Purge:** `BusinessTrackerApp.purgeExpiredTrash()` runs on launch (`.task`) and on foreground. Fetches each type where `deletedDate != nil`, hard-deletes any older than 30 days. For a Client this fires the real cascade (projects + invoices) at purge time — matching the original hard-delete semantics.
- **Client soft-delete CASCADES the trash to all child records** (Jack's standup 2026-06-19). `ClientsView.softDeleteClient(_:)` sets `deletedDate = .now` on the client **and** each not-already-trashed child (`timeEntries`, `incomeEntries`, `expenses`, `invoices`, `quotes`) so none linger in global lists during the 30-day window (the prior "stays visible" behavior was the complaint). Projects aren't `SoftDeletable` — removed by the real cascade at permanent purge. **Restore brings back the CLIENT ONLY**: restoring from Recently Deleted clears only the client's `deletedDate`; children keep their own independent 30-day timers (and show as separate Recently Deleted rows). Deliberate trade-off chosen over "restore everything" so we don't have to track which children the cascade trashed vs. were already trashed.

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
│   ├── Quote.swift                  (estimate paralleling Invoice: quoteNumber, validUntil, status, convertedInvoiceNumber, totals; QuoteStatus enum)
│   ├── QuoteLineItem.swift          (manual quote line — distinct from InvoiceLineItem, copied on convert)
│   ├── MileagePreset.swift          (saved route template: name, start, end, purpose, notes, sortOrder — no relationships)
│   ├── ExpensePreset.swift          (saved expense template: name, amount: Double?, category, notes, sortOrder — no relationships)
│   ├── SoftDeletable.swift          (protocol: deletedDate + trashDaysRemaining — TimeEntry/MileageTrip/Expense/IncomeEntry/Invoice/Client conform)
│   ├── TimerActivityAttributes.swift (ActivityAttributes for Live Activity — MUST stay in sync with FreelancedLiveActivity.swift copy)
│   └── TripActivityAttributes.swift  (ActivityAttributes for the manual trip Live Activity — MUST stay in sync with TripLiveActivity.swift copy)
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
│   ├── InvoiceView.swift            (InvoiceRow, CreateInvoiceView/CreateInvoiceContent, InvoiceQuickActionSheet, InvoiceDetailView, MarkPaidSheet, InvoiceFirstPageLayout, InvoiceContinuationPageLayout, makeInvoicePDF())
│   └── QuoteView.swift              (QuoteRow, CreateQuoteView/CreateQuoteContent, QuoteQuickActionSheet, QuoteDetailView w/ convert-to-invoice, makeQuotePDF())
├── Mileage/
│   ├── AddressSearcher.swift        (AddressSearcher, LocationManager, LocationResult, shortAddress, calculateDrivingMiles single + multi-leg)
│   ├── DriveDetector.swift          (Auto-Mileage Phases 0–2: @MainActor @Observable singleton — significant-change wake → motion/speed-triggered active GPS route session → stop on OS pause/stationary → needs-review MileageTrip with captured route; CMMotionActivityManager for automotive confirmation)
│   ├── TripTracker.swift            (manual live trip: @MainActor @Observable singleton — When-In-Use GPS session, start/pause/resume/stop, live miles + route, Trip Live Activity, inserts a normal MileageTrip on stop)
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
│   ├── InvoiceReminders.swift       (local-notification scheduler for unpaid invoice due dates — opt-in, takes ModelContainer to fetch invoices)
│   ├── ReminderTime.swift           (ReminderTime — shared configurable fire time for all local notifications; notify_hour/notify_minute, default 9:00am)
│   ├── UserAvatar.swift             (user's own avatar view + UserAvatarImage downscale helper — user_avatar @AppStorage)
│   ├── CloudSyncStatusView.swift    (CloudSyncRow — read-only "iCloud Sync" status row; lives in the Backup & Sync section)
│   ├── DataBackup.swift             (full JSON export/import of every record + synced settings; relationships via export-scoped UUIDs; additive import)
│   ├── MoreAppsView.swift           (PromotedApp + GarbenApps.all + MoreAppsSection — "More from Garben Technologies")
│   └── RecentlyDeletedView.swift    (30-day trash — restore / permanent delete across all six soft-deleted types)
├── Shortcuts/
│   └── AppShortcuts.swift           (Siri/Shortcuts App Intents: StartTimer/LogTime/LogTrip/LogExpense + FreelancedShortcuts provider)
├── Pro/
│   ├── Entitlements.swift           (Entitlements @Observable + isProEffective, ProPlan, ProFeature, StoreProvider seam + StubStoreProvider, .proPaywall modifier)
│   └── PaywallView.swift            (branded upgrade sheet — feature list, plan picker, subscribe/restore; provider-agnostic)
├── Onboarding/
│   └── OnboardingView.swift         (5 pages: welcome, about you, location, notifications, ready)
└── Views/
    ├── IncomeView.swift              (IncomeRow + IncomeEditView — shared components used by ClientDetailView)
    ├── DocumentPDF.swift             (unified invoice+estimate PDF: DocumentPDFSpec + DocPDFRow + makeDocumentPDF; both makeInvoicePDF/makeQuotePDF feed it)
    ├── DocumentPreviewView.swift     (PDFKit preview + Share/Done + "created" toast; shown after creating an invoice/estimate. PreviewDoc, SharePDF, ActivityShareSheet, ShareOutcome)
    ├── ReportsView.swift             (3×2 glance card, fuel analysis, tax set-aside, top clients — opened as sheet from Home)
    └── PlaceholderView.swift

FreelancedWidget/                    (WidgetKit extension target)
├── FreelancedWidgetBundle.swift     (@main — registers FreelancedSmallWidget, FreelancedMediumWidget, FreelancedTaxWidget, FreelancedLiveActivity, TripLiveActivity)
├── TripLiveActivity.swift           (manual trip Live Activity: TripActivityAttributes copy, TripLiveActivity Widget, TripLockScreenView — blue theme, live miles + elapsed)
├── FreelancedWidget.swift           (providers, entry views, widget definitions, previews)
├── FreelancedTaxWidget.swift        (read-only Quarterly Tax Due Dates — StaticConfiguration, daily refresh; QuarterlyTaxDates logic duplicated from SettingsView)
├── FreelancedLiveActivity.swift     (TimerActivityAttributes copy, FreelancedLiveActivity Widget, TimerLockScreenView)
├── AppIntent.swift                  (WidgetQuickAction AppEnum, SingleActionConfiguration, QuadActionConfiguration)
├── FreelancedWidgetControl.swift    (Xcode-generated Control widget stub — unused, not in bundle; TimerControlIntent renamed to avoid conflict with AppIntent.swift)
└── Assets.xcassets/
```

---

## What's left to build

**Optional follow-ups (Quotes is now shipped — see Quotes / Estimates section):**
- **Quote widget/Shortcut entry point** — deliberately scoped out of the first cut. To add: a `WidgetQuickAction.createQuote` case (mirror in the widget extension's duplicated enum) + a `LogQuoteShortcut` App Intent routing `createQuote`.
- **Shared PDF layout** — `makeQuotePDF` currently duplicates the invoice PDF helpers rather than sharing a document-type-parameterized layout. Worth unifying if a third document type appears.
- **Promoted app data** — `GarbenApps.all` (CradleLight, Sipfolio) ships with placeholder taglines + TODO App Store URLs; fill in real URLs/icons before release.
- **Unified "Documents" grouping** — consider grouping Quotes + Invoices under each client if the two lists get long.

**Remaining / future:**
- **Lock screen widgets** — deferred until Firebase Blaze (or equivalent server) is justified by MRR. Full design in the Widgets section.
- **Package Tracking** — future, needs carrier API integration.
- **Pro tier (paid)** — scaffolded (see Monetization section). Remaining: implement a real `StoreProvider` (StoreKit 2 or RevenueCat), create the products in App Store Connect, add Terms/Privacy URLs to the paywall, and decide the final free-client cap. Then it's live.
- **macOS** — future. **iPad is now supported** (NavigationSplitView, see iPad section); remaining iPad polish (true 3-column drill-down, multi-window) is optional/future.

_(Shipped: Jack's full feedback batch — Reports PDF export, mileage deduction card, trip purpose presets, location favorites, multi-stop routes, mileage/expense presets, prominent timer-sheet presets button, Quarterly Tax widget, Settings→Profile redesign — plus Recently Deleted, Siri & Shortcuts, tax deadline reminders, and "Create Invoice" as a default Home quick action. See feature sections.)_

---

## ⚑ Pre-launch checklist & backlog

Consolidated list to work through before App Store submission. (Reviewed 2026-06-17.)

### 🔴 Must-do before App Store launch
- [ ] **Wire a real `StoreProvider`** (StoreKit 2 or RevenueCat) and create the products in App Store Connect (IDs `com.garbenTechnologies.BusinessTracker.pro.{monthly,annual,lifetime}`). Replaces `StubStoreProvider`. See Monetization section.
- [ ] **Flip `Entitlements.monetizationEnabled` → `true`** (only after the real store layer is in). It's the master switch in `Pro/Entitlements.swift`.
- [ ] **On-device pass of the gated flows** after flipping the switch — paywall → purchase → unlock never ran during dormant testing. Test in TestFlight with a sandbox Apple ID.
- [ ] **Real Terms of Use (EULA) + Privacy Policy URLs** — paywall footer has TODO placeholders, and the App Store listing requires both (camera/location/photos perms make a privacy policy mandatory).
- [ ] **App Store privacy nutrition labels** — declare camera, location, photos (and "Purchases" / third-party data if you choose RevenueCat).
- [ ] **Finish `GarbenApps.all`** (`Settings/MoreAppsView.swift`) — CradleLight is live (App Store URL + `cradleLightLogo` asset); still need Sipfolio's public `testFlightURL` (and later its App Store URL), plus confirmed taglines + the `cradleLightLogo` image actually added to Assets.
- [ ] **Paywall trial copy** — the subscribe button shows "Start Free Trial" for monthly too; only claim a trial on plans you actually configure one for in App Store Connect (currently only annual's subtitle promises one).
- [ ] **Lock the free-client cap** — `Entitlements.freeClientLimit` (currently 2). Loosening later is easy; tightening causes revolts.
- [ ] **Real app icon** — the in-app brand placeholders now use the **`freelancedLogo`** asset (2026-06-21): onboarding Welcome badge (`OnboardingBadge(imageName:)`) + Live Activity `TimerAppBadge` (the imageset was copied into **both** `BusinessTracker/Assets.xcassets` and `FreelancedWidget/Assets.xcassets` since the widget is a separate target). **Still TODO: the actual home-screen `AppIcon` set** — `freelancedLogo` is a single imageset, not the multi-size `AppIcon.appiconset` iOS requires; add the real icon (1024px master) to AppIcon in Xcode.
- [ ] **Verify CloudKit Production round-trip on a 2nd device** for the new `CD_Quote`/`CD_QuoteLineItem` types + `user_avatar` (schema deployed 2026-06-17).
- [ ] **Decide monetization model** — freemium (current scaffolding) vs. whole-app subscription. Either reuses the same `Entitlements`/`StoreProvider`/`PaywallView`; only gate *placement* changes (per-feature gates vs. one app-root `.fullScreenCover`). Cheap to flip even post-launch.

### 🟡 Highest-value features (post-scaffold, roughly in priority order)
1. ✅ **Logo on invoices/estimates** — done. Business logo upload in Settings → Business & Invoicing (`business_logo`, downscaled PNG via `UserAvatarImage.processedLogo`, synced through `CloudKeyValueSync`). `BusinessInfo.load` reads it; `DocumentPDFSpec.logoData` renders it at the top-left of the PDF header (above the business name, capped 200×52pt) for both document types.
2. ✅ **Overdue invoice tracking + reminders** — done. `Invoice.isOverdue`/`daysOverdue` (unpaid + `dueDate` before today). `InvoiceRow`/`InvoiceDetailView` show a 3-state badge (Paid green / Overdue red / Unpaid orange). Home shows a pinned **`OverdueInvoicesCard`** (count + total outstanding) → **`OverdueInvoicesView`** sheet listing them. Opt-in local notifications via **`InvoiceReminders`** (`Settings/InvoiceReminders.swift`, day-before + due-day at the configurable **Reminder Time**, rescheduled on launch/foreground, `invoice_remindersEnabled` toggle in Business & Invoicing → Reminders; device-local, NOT iCloud-synced). **Reminder Time** (`notify_hour`/`notify_minute`, default 9am, via `ReminderTime`) is a single global setting governing *all* the app's local notifications; a "Reminder Time" `DatePicker` appears in both reminder sections (invoice + quarterly tax) and reschedules both schedulers on change.
3. ✅ **"Pay now" link on invoices** — done (2026-06-20). `business_paymentLink` (Settings → Business & Invoicing → Invoicing Defaults, "Pay-Online Link"; synced via `CloudKeyValueSync`). `BusinessInfo.paymentLink` → `DocumentPDFSpec.paymentLink`, printed in the invoice PDF's PAYMENT block ("Pay online: …", blue). `InvoiceDetailView` shows a tappable **Pay Online** `Link` (URL normalized to `https://` if no scheme). Invoice only (quotes pass empty).
4. ✅ **Duplicate / clone** — done (2026-06-20). `InvoiceDetailView.duplicateInvoice()` + `QuoteDetailView.duplicateQuote()` (a "Duplicate" section button). Copies manual line items + discount/tax/terms/PO/notes with a fresh number (year-scoped when `doc_numberResetYearly`), `issueDate = .now`, due/valid date preserving the original day-gap; invoice → unpaid, quote → fresh Draft (not linked). **Billed time entries are NOT copied** (they're unique billing records). Opens the new document's detail via `.sheet(item:)`.
5. ✅ **Currency setting** — done (2026-06-20). `AppCurrency.code` now reads `UserDefaults` key **`app_currencyCode`** (default USD; synced). Settings → App → **Currency** picker (`AppCurrency.supported` list, `displayName` = "USD — US Dollar"). `asCurrency`/`AppCurrency.style` pick it up live on next render.
6. **Quote widget/Shortcut entry point** — deliberately scoped out of the first cut (see Monetization/Quotes notes for how to add).

### 🟢 Smaller polish
- ✅ **Quick-action dismiss wart** — fixed. `CreateInvoiceContent`/`CreateQuoteContent` take an `onComplete` closure; the quick-action picker passes its sheet `dismiss` so the flow closes fully instead of popping to the picker.
- ✅ **Free-tier usage hint** — done (2026-06-20), but **deliberately removable** (Tyler may cut it pre-launch): `FreeClientUsageHint` row in `ClientListView.swift` + one call site in `ClientsView.body`, both fenced in `===== REMOVABLE =====` comment blocks. Shows "X of N free clients used" only when `Entitlements.monetizationEnabled && !isProEffective` (so it's dormant until launch). Delete the two fenced blocks to drop it.
- ✅ **Accessibility labels** — added on the main icon-only controls (Home toolbar, Clients FAB + settings, client-detail section `+`s, share / mark-paid, avatar picker). Completed 2026-06-21 across Time/Mileage/Expenses: profile button ("Profile & Settings"), the toolbar `+` / FAB ("Log Time"/"Log Trip"/"Add Expense", Expenses FAB toggles "Close Menu" when the speed-dial is open), Time's Start-Timer play FAB and the inline pause/resume ("Pause/Resume Timer"); Time's billing-filter menu already had "Filter Entries". History buttons are text-labeled (no a11y label needed). Decorative row glyphs left unlabeled.
- ✅ **Auto-status on share** — sharing an estimate now bumps Draft → Sent, but **only on a real send**. Uses `ActivityShareSheet` (UIActivityViewController completion handler) + `ShareOutcome.wasSent` to exclude Save to Files / Photos / Copy / Print, so saving to device does NOT mark it Sent.
- ✅ **Document numbering** — configurable in Settings → Document Numbering: invoice/estimate prefix (`doc_invoicePrefix`/`doc_quotePrefix`) + per-year reset (`doc_numberResetYearly`, inserts the year and restarts at 001). `Invoice.formatted(number:issueDate:)` / `Quote.formatted(...)` statics read these; next-number logic is year-scoped when reset is on. Synced via `CloudKeyValueSync`.
- ✅ **Unified PDF** — `makeInvoicePDF` and `makeQuotePDF` now both build a `DocumentPDFSpec` and call the shared `makeDocumentPDF` in `Views/DocumentPDF.swift`. The ~400 lines of duplicated layout are gone. **⚠️ The invoice layout was preserved 1:1; verify one invoice + one estimate PDF render correctly on device since the renderer can't be eyeballed from a build.**

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
- **Design:** app-icon-style badge (`TimerAppBadge` — now renders the **`freelancedLogo`** asset clipped to a rounded square; was an indigo tile + `stopwatch.fill`), a red-dot "TRACKING TIME" label (`TrackingLabel`), rounded monospaced indigo timer (`liveTimer`), indigo-tinted gradient container background. Brand colors `brandIndigo`/`brandIndigoDark` defined at top of file (`brandGradient` is now unused but kept).
- Lock screen `TimerLockScreenView`: badge · tracking label + client/project · live timer + "Freelanced" wordmark.
- Dynamic Island: compact (stopwatch + timer), minimal (stopwatch). **Expanded uses ONLY the `.bottom` region** for the full banner (badge + tracking label/client/project on the left, timer + "Freelanced" on the right) — the narrow leading/trailing regions clip long text (they hand content its natural size then truncate, so `minimumScaleFactor` never engages), whereas `.bottom` spans the full island width.
- **Informational only** — no Stop button (deliberately reserved to the app to avoid accidental stops). Tapping the activity opens the app via `widgetURL(freelanced://startTimer)`, where the timer is stopped. (A Stop button was built then removed; if revisited it needs a shared App-Intent target + persisting the running client/project to the App Group.)
- Started by `TimerState.startLiveActivity()` in the **main app process only** — widget extensions cannot call `Activity.request()`
- Ended by `TimerState.endLiveActivity()` on timer stop
- `NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` must be `true` in `BusinessTracker/Info.plist`
- **⚠️ Live Activity badges are GLYPH-ONLY (2026-06-22) — the `freelancedLogo` image does NOT render in a Live Activity.** We tried: copied the asset into the widget catalog (loads, `UIImage(named:)` returns non-nil, no console error) and even downscaled it 1024px/1.1 MB → 256px/38 KB (ActivityKit drops oversized images) — it still rendered **blank**, and since the asset *is* present a `UIImage(named:)` fallback guard never triggers. **So `TimerAppBadge`/`TripAppBadge` were pivoted to a branded gradient tile + SF Symbol** (`stopwatch.fill` indigo / `car.fill` green) — no asset dependency, always renders. The widget no longer references `freelancedLogo` at all. (The onboarding Welcome badge in the MAIN app still uses the logo image fine — this limitation is specific to the Live Activity rendering context.) **Don't reintroduce an `Image("freelancedLogo")` into the widget Live Activities expecting it to show.**

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

- **`Settings/TaxReminders.swift`**: schedules local `UNCalendarNotificationTrigger`s a week before and the day before each quarterly IRS deadline, at the user's configurable **Reminder Time** (`ReminderTime.hour`/`minute`, default 9:00am — see `Settings/ReminderTime.swift`). Opt-in via `@AppStorage("tax_remindersEnabled")`, toggle in the Quarterly Tax Dates section.
- `handleToggle(enabled:)` requests authorization when turning on; `reschedule()` clears prior `tax-deadline-*` requests and re-adds upcoming ones. Called on app launch (`.task`) so deadlines roll forward each cycle.
- No push entitlement / no server — purely local notifications. `TaxReminders.dueDates()` duplicates the quarterly-date logic (same as SettingsView + the tax widget).

## Planned platform extensions

- **Lock screen widgets** — deferred (see Widgets section)

### CarPlay — future (2.0) idea & avenues (added 2026-06-21)

Jack/Tyler idea: drive the **mileage** feature into the car — start/stop a trip hands-free. CarPlay is heavily gated by Apple, so the realistic path is NOT "build a CarPlay screen first." Three avenues, cheapest/most-likely first:

1. **Siri + Shortcuts automation — no entitlement, basically already shipped.** The existing App Intents (`StartTimer`/`LogTime`/`LogTrip`/`LogExpense` in `Shortcuts/AppShortcuts.swift`) already give: (a) **voice** through the car mic ("Hey Siri, log a trip in Freelanced"), and (b) a user-created **Shortcuts personal automation** — *"When CarPlay connects → run Log Trip / Start Timer"* — so a trip auto-starts on entering the car. Zero Apple approval. Lowest effort: maybe add a dedicated "Start Mileage Trip" intent that begins an auto-tracked drive, plus docs/marketing telling users how to set the automation. **Recommended first step.**
2. **Automatic drive detection — no CarPlay framework at all, biggest payoff.** The "set-and-forget" MileIQ-style experience: background **Core Location** (significant-location / visit monitoring) + **Core Motion** (`CMMotionActivityManager` automotive detection) to auto-log drives with start/end addresses, then prompt to categorize (business/personal) later. Needs **Always** location permission + `location` background mode (new Info.plist usage string + entitlement). Bigger lift, but it's the real 2.0 mileage feature and is entirely in our control. Pairs naturally with the existing `MileageTrip` model (just an automated insert path).
3. **Native CarPlay app (template-based) — requires Apple's CarPlay entitlement; discretionary.** Third-party CarPlay can't render SwiftUI — you use the **CarPlay framework templates** (`CPListTemplate`, `CPInformationTemplate`, `CPGridTemplate`, action sheets) in a dedicated `CPTemplateApplicationScene`, gated behind a **CarPlay entitlement** that Apple grants per approved category. The only category Freelanced could plausibly request is **"Driving Task"** (apps that help accomplish a task related to the drive). **Approval is discretionary and a freelancer mileage logger is a stretch** — Apple rejects many non-core-driving apps. Highest effort + gatekept + template-only UI. Only worth chasing after #2 proves the driving use-case and we want the native in-dash surface.

**Recommendation:** #1 now (cheap, no approval), #2 as the headline 2.0 mileage feature, #3 only as a later stretch. Document any CarPlay entitlement request status here when pursued.

### Automatic Drive Detection (Auto-Mileage) — phased plan (2.0 target, added 2026-06-21)

The headline 2.0 mileage feature: auto-detect drives and log them so the user rarely opens the app. **Plan: ship Phase 1 as an opt-in BETA during 1.x, tune it on real roads, then un-beta for 2.0.** The code is moderate; the cost is background-lifecycle reliability + heuristic tuning (only real driving reveals the thresholds) + the "Always" location permission/App-Review/battery story. Manual entry always stays as the fallback.

**Difficulty:** medium code, high real-world-testing. Not a weekend feature. ~80% of the "it just logs my drives" value is reachable with the Phase 1 visit-based MVP; the last 20% (precise routes, bulletproof stop detection, low false-positives) is the long tail.

**What already helps:** `MileageTrip` model (auto-trips just insert into it), `CLGeocoder` reverse-geocoding, `calculateDrivingMiles`/MKDirections for endpoint distance, and the `LocationManager` pattern in `AddressSearcher.swift` (but that's When-In-Use + one-shot — auto-detect needs a SEPARATE dedicated manager).

#### Phase 0 — plumbing & permissions ✅ DONE (2026-06-21)
- **`Mileage/DriveDetector.swift`** — `@MainActor @Observable final class DriveDetector: NSObject` (singleton `DriveDetector.shared`) owning its OWN `CLLocationManager` (separate from the address-search `LocationManager`) + a `CMMotionActivityManager`. `refreshFromSettings()` (called from `BusinessTrackerApp` launch `.task` + foreground) starts/stops monitoring per the toggle; `setEnabled(_:)` (called from the Settings toggle) persists the flag + requests **Always** auth on first enable; `beginMonitoring()` arms `startMonitoringSignificantLocationChanges()` + `startMonitoringVisits()` once Always is granted. **The `didVisit` / `didUpdateLocations` delegate methods are intentionally empty `PHASE 1` / `PHASE 2` stubs** — no trip is logged yet. (`allowsBackgroundLocationUpdates` deliberately NOT set until Phase 2 — significant-change + visits deliver in background without it.)
- **Permissions:** `NSLocationAlwaysAndWhenInUseUsageDescription` + `NSMotionUsageDescription` (Phase 1) added to the **physical `BusinessTracker/Info.plist`** (not build settings — the physical plist already holds the other runtime keys), and **`location`** added to `UIBackgroundModes` alongside `remote-notification`.
- **Toggle:** `@AppStorage("mileage_autoDetectEnabled")` (default `false`), gates everything; device-specific (NOT in `CloudKeyValueSync`). Settings → **Automatic Mileage (BETA)** section: toggle + explainer footer + a "Set Location to Always" hint button (opens iOS Settings) shown via `DriveDetector.shared.needsAlwaysPermission` (read directly in `body` for @Observable tracking). `.onChange` calls `DriveDetector.shared.setEnabled(_:)`.
- **Schema (additive):** `MileageTrip` gained `var isAutoDetected: Bool = false` and `var needsReview: Bool = false` (defaults → lightweight-migration safe). Drives-to-review = `isAutoDetected && needsReview`. **⚠️ Needs CloudKit Dev→Production redeploy before shipping** (see the iCloud Sync row's pending list).

#### Phase 1 — visit-based MVP (the beta) ✅ DONE (2026-06-21) — ⚠️ SUPERSEDED by Phase 2's active GPS engine; the `CLVisit`/pending-origin detection described below was REMOVED. The review-UI parts (the "Drives to Review" section, `needsReview`/`isAutoDetected`, the Confirm/Delete swipes) all still apply.
- `DriveDetector.beginMonitoring()` runs `startMonitoringSignificantLocationChanges()` + `startMonitoringVisits()` (both wake the app from terminated; near-zero battery).
- **Pairing logic** (`handleVisit`): a `CLVisit` with a real `departureDate` (≠ `.distantFuture`) records the **pending origin** (coord + departureDate, **persisted to UserDefaults** so a departure before app-kill still pairs after relaunch); the next arrival-only visit (departureDate == `.distantFuture`) completes the trip origin→destination and clears the pending origin. So a trip logs on the second arrival after a departure (chains A→B, B→C, …).
- **`buildTrip`**: distance via `calculateDrivingMiles(from:.coordinate,to:.coordinate)` (MKDirections — approximate, no route yet); motion-confirm via `wasDriving(from:to:)` (`CMMotionActivityManager.queryActivityStarting`, returns `true`/`false`/`nil`); **skip if `wasDriving == false`**, require **≥0.3 mi** when driving-confirmed / **≥1.0 mi** when motion unknown (drops GPS noise + walks); reverse-geocode both endpoints (`CLGeocoder` → `addressLabels` builds short label + full export address); insert a `MileageTrip(isAutoDetected: true, needsReview: true)` into `modelContainer.mainContext` (container set from `BusinessTrackerApp` at launch); post a local "Drive logged" notification.
- **Review UI** (`MileageView`): a **"Drives to Review"** section (orange `car.circle.fill` header) shows `isAutoDetected && needsReview` trips via a dedicated `@Query`; the normal day-grouped list uses `listedTrips` (= `trips.filter { !$0.needsReview }`) so review drives don't double-show. Per row, **three VISIBLE `.borderless` buttons** (2026-06-22 — swipe was undiscoverable): **Confirm** (green → `markReviewed`, clears `needsReview`), **Categorize** (blue → opens `MileageTripEditView`), **Delete** (red trash → soft-delete). Tapping the row also opens the editor. Confirm is the explicit "keep it" action.
- **Tracked-trip editor + map** (2026-06-22): `MileageTripEditView` checks `isTracked` (`!trip.routeCoordinates.isEmpty`) — for GPS-tracked trips (manual live-track OR auto-detect) it shows the captured **From / To / Distance read-only** (no start/end entry, since they were tracked; `save()` leaves `startLocation`/`endLocation`/`miles`/`routePoints` untouched, `canSave` is always true). The **"Tracked Route" map** is a non-interactive thumbnail (`TrackedRouteMap`, `allowsHitTesting(false)` + a clear tap overlay) that **taps into a full-screen, pinch/zoom `FullRouteMapView`** (`.fullScreenCover`). Shared `routeRegion`/`routeContent` (`@MapContentBuilder`) helpers.
- **Beta** label on the Settings toggle while tuning.
- **NOT done / Phase-1 follow-ups:** launch-from-terminated re-arm relies on the normal launch `.task` (no explicit `UIApplication.LaunchOptionsKey.location` handling yet — significant-change still relaunches the app, and `refreshFromSettings()` re-arms on launch, so it works, but verify on device); auto-mileage doesn't request notification auth itself (piggybacks on whatever the user granted — the in-app review section is the reliable surface); no deep-link from the notification to the review section yet (tapping just opens the app).

#### Phase 2 — active route tracking (accuracy, still beta) ✅ DONE (2026-06-21)
- **Replaced the Phase 1 visit-based detection with an active GPS engine** (the visit/pending-origin code is gone). Passive `startMonitoringSignificantLocationChanges()` wakes the app; on a sig-change update `maybeStartDrive` starts a session if `location.speed ≥ ~13 mph` OR `wasDrivingRecently()` (motion `.automotive` in the last 3 min). `startActiveSession` raises accuracy to `kCLLocationAccuracyNearestTenMeters`, sets `allowsBackgroundLocationUpdates = true` + `pausesLocationUpdatesAutomatically = true` + `activityType = .automotiveNavigation`, and `startUpdatingLocation()`.
- **Stop:** `locationManagerDidPauseLocationUpdates` (the OS detecting the user stopped) is the primary finalize signal; a 4-min stationary timeout in the update stream is the backup. `finalizeDrive` tears the stream back down to significant-change only (battery rule: high accuracy ONLY during a confirmed drive).
- **`buildTrip(from fixes:)`** sums `CLLocation.distance` across the polyline for **true mileage** (no MKDirections estimate now), reverse-geocodes the first/last fix, inserts a needs-review `MileageTrip`, and stores the route in **`MileageTrip.routePoints: [Double] = []`** (flattened `[lat,lon,…]`, downsampled to ≤500 points for the CloudKit field). `MileageTrip.routeCoordinates` rebuilds `[CLLocationCoordinate2D]`. **Schema additive → redeploy.**
- **Delegate thread-safety:** `CLLocation`s are mapped to a Sendable `Fix` struct in the `nonisolated` delegate before hopping to the `@MainActor` `handle(_:)` (CLLocation isn't Sendable).
- **UI (the "see it" part):** `MileageTripEditView` shows a **"Tracked Route"** section — a non-interactive `Map` (`.allowsHitTesting(false)`) with a blue `MapPolyline` + green Start / red End `Marker`s, region auto-fit to the route — only when `routeCoordinates` is non-empty. `TripRow` shows an **AUTO** badge + "Uncategorized" fallback for auto-detected drives.
- **Known clip:** the first sig-change can fire up to ~500m into a drive, so the very start of the route may be missing (slight under-count). Acceptable for beta; Phase 3 can stitch the origin. Real-world road testing still required.

#### Phase 3 — polish & un-beta (2.0)
- Tune segmentation thresholds from real-world data; dedupe against manual entries; optional learned auto-categorization (home/office → personal/business); sensitivity setting. Drop the Beta label.

**Cross-cutting gotchas:** Always-auth lowers opt-in + triggers recurring iOS "using your location" nags (justify in App Review); stop/trip segmentation is the magic-vs-annoying line and needs days of real driving; never run continuous GPS when not driving (battery). Can't be validated at a desk — plan for on-device road testing each phase.

---

## Known patterns / gotchas

- **CloudKit model rules (all must be followed or CloudKit silently falls back to local-only):**
  1. Every stored attribute needs a default on the *property declaration* — `var name: String = ""` not just `var name: String` (CloudKit reads metadata, not `init`). **This same default-on-declaration rule is also what keeps app-update migrations safe — see "⚠️ Schema changes & data safety" above before changing any `@Model`.**
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
- **Currency formatting is centralized** in `Models/AppCurrency.swift`. Use `someDouble.asCurrency` (→ `"$1,234.56"`) for display strings, or `AppCurrency.style` as a `FormatStyle` (e.g. `Text(value, format: AppCurrency.style)`, or `value.formatted(AppCurrency.style)` when concatenating). The currency code lives only in `AppCurrency.code`, which reads the user-configurable `@AppStorage("app_currencyCode")` (default USD; Settings → App → Currency; synced via `CloudKeyValueSync`). Do **not** reintroduce inline `.currency(code: "USD")`.
- **New files in synchronized folder groups need a clean build:** adding a file mid-session (e.g. `AppCurrency.swift`) can make an *incremental* build emit spurious cascade errors in unrelated files (notably `@Model` types looking like they "don't conform to Identifiable") because a batch compiles before the new file's symbols are visible. Run `xcodebuild ... clean build` to confirm — the errors vanish.
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
- **`TimerActivityAttributes` is duplicated across two targets** — the main app (`BusinessTracker/Models/TimerActivityAttributes.swift`) and widget extension (`FreelancedWidget/FreelancedLiveActivity.swift`) are separate Swift modules and cannot share the type. The struct must be kept identical in both files; a comment in each file calls this out. **`TripActivityAttributes` follows the same rule** (`BusinessTracker/Models/TripActivityAttributes.swift` ↔ `FreelancedWidget/TripLiveActivity.swift`).
- **Multi-page document PDF uses multiple `ImageRenderer` renders into one `CGContext`** — call `ctx.beginPDFPage(nil)` / `draw(ctx)` / `ctx.endPDFPage()` per page, then `ctx.closePDF()`. Each page is a separate `ImageRenderer` with its own SwiftUI layout (`DocumentFirstPageLayout` max 6 rows, `DocumentContinuationPageLayout` max 10) in `Views/DocumentPDF.swift`. Do not try to render all pages in a single `ImageRenderer`. **Invoices and estimates now share this one renderer** via `DocumentPDFSpec`; `makeInvoicePDF`/`makeQuotePDF` just build a spec.
- **`CreateInvoiceView` wraps `CreateInvoiceContent`** — `CreateInvoiceContent` is a private struct holding all form state and the body. `CreateInvoiceView(client:)` just wraps it in a `NavigationStack`. `InvoiceQuickActionSheet` shows a client picker that pushes to `CreateInvoiceContent` directly, reusing the same form without duplication.
- **Soft-delete: any NEW `@Query` for TimeEntry/MileageTrip/Expense/IncomeEntry/Invoice/Quote/Client MUST filter `deletedDate == nil`** — there is no global query scope in SwiftData, so a forgotten filter makes trashed items reappear. Simple form: `@Query(filter: #Predicate<T> { $0.deletedDate == nil }, sort: ...)`. Predicate-`init` form: AND `&& $0.deletedDate == nil` into the predicate. Any code summing a **relationship array** (e.g. `client.timeEntries`) must `.filter { $0.deletedDate == nil }` too. To trash a record set `deletedDate = .now` (never `modelContext.delete`, except for the hard-delete exceptions: TimePreset, Project, and the AddEditClientView eager-insert cancel). See the Recently Deleted section.
