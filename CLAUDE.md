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
| Time Tracking | ✅ Done |
| Mileage Tracking | ✅ Done |
| Expense Tracking | ⬜ Not started |
| Income & Tax Projection | ⬜ Not started |
| Reports & Analytics | ⬜ Not started |
| Package Tracking | ⬜ Future (API integration) |
| Pro tier (paid) | ⬜ Future |

---

## Data models

- **`Client`** — `name`. Container only; rate lives on Project.
- **`Project`** — `name`, `hourlyRate`, belongs to `Client`
- **`TimeEntry`** — `date`, `client?`, `project?`, `hours`, `hourlyRate` (snapshot), `notes`
- **`TimePreset`** — `name`, `client?`, `project?`, `sortOrder`, `hourlyRateOverride?`, `notesTemplate`
- **`MileageTrip`** — `date`, `startLocation`, `endLocation`, `miles`, `purpose`, `notes`. Computed `reimbursementAmount` using `ratePerMile` (IRS rate, currently 0.70)
- **`Expense`** — `date`, `amount`, `category`, `notes`, `receiptImageData?` (placeholder model, view not built)
- **`IncomeEntry`** — `date`, `source`, `amount`, `notes` (placeholder model, view not built)
- **`TimerState`** — `@Observable` class (not SwiftData). Persists active timer start date to `UserDefaults` so timer survives backgrounding.

---

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
├── TimeTracking/
│   ├── TimerState.swift
│   ├── TimeTrackingView.swift
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
│   ├── MileageView.swift
│   ├── MileageHistoryView.swift
│   └── MileageMonthDetailView.swift
└── Views/
    ├── ExpensesView.swift      (placeholder)
    ├── IncomeView.swift        (placeholder)
    ├── ReportsView.swift       (placeholder)
    └── PlaceholderView.swift
```

---

## Design conventions used throughout

- Segmented mode toggle lives **inside** the relevant form section (not above the form)
- Summary cards at top of each main list view
- `ContentUnavailableView` for all empty states
- Entries grouped by date, swipe-to-delete on all lists
- All sheets use `NavigationStack` with Cancel/Save (or Done) toolbar items
- Shared reusable components: `MileageSummaryCard`, `TripRow` (both in `MileageView.swift`)

## Known patterns / gotchas

- `onChange(of: selectedClient)` only clears `selectedProject` if the project doesn't belong to the new client — prevents presets from requiring two taps
- SwiftData filtered `@Query` in detail views uses custom `init` with `#Predicate`
- `TimerState.stop()` clears client/project — always capture them into locals before calling it
- `Text +` concatenation is deprecated in iOS 26 — use string interpolation instead
