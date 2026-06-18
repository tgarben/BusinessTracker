import SwiftUI
import SwiftData

/// The five top-level destinations. Drives the single `TabView` used on both
/// idioms (bottom tab bar on iPhone, floating top tab bar on iPad) from one source.
enum AppSection: String, CaseIterable, Identifiable {
    case home, mileage, time, expenses, clients

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .mileage:  return "Mileage"
        case .time:     return "Time"
        case .expenses: return "Expenses"
        case .clients:  return "Clients"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .mileage:  return "car"
        case .time:     return "clock"
        case .expenses: return "creditcard"
        case .clients:  return "person.2"
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .home:     HomeView()
        case .mileage:  MileageView()
        case .time:     TimeTrackingView()
        case .expenses: ExpensesView()
        case .clients:  ClientsView()
        }
    }
}

struct ContentView: View {
    @Environment(TimerState.self) private var timerState
    @Environment(Entitlements.self) private var pro

    @State private var showTimer = false
    @State private var showLogTime = false
    @State private var showLogTrip = false
    @State private var showAddExpense = false
    @State private var showCreateInvoice = false
    @State private var paywall: ProFeature?

    var body: some View {
        // A plain `TabView` renders the bottom tab bar on iPhone and the
        // floating App Store-style top tab bar on iPad automatically — no
        // size-class branching needed. (`.sidebarAdaptable` would force a
        // sidebar on iPad; we deliberately don't use it.)
        tabView
        .sheet(isPresented: $showTimer)         { TimerSheet() }
        .sheet(isPresented: $showLogTime)       { LogTimeView() }
        .sheet(isPresented: $showLogTrip)       { LogTripView() }
        .sheet(isPresented: $showAddExpense)    { AddExpenseView() }
        .sheet(isPresented: $showCreateInvoice) { InvoiceQuickActionSheet() }
        .proPaywall($paywall)
        .onChange(of: timerState.pendingWidgetAction) { _, action in
            guard let action else { return }
            timerState.pendingWidgetAction = nil
            switch action {
            case .startTimer:    showTimer = true
            case .logTime:       showLogTime = true
            case .logTrip:       showLogTrip = true
            case .addExpense:    showAddExpense = true
            case .createInvoice: if pro.isProEffective { showCreateInvoice = true } else { paywall = .invoicing }
            }
        }
    }

    // Bottom tab bar on iPhone, top tab bar on iPad — both from this one TabView.
    private var tabView: some View {
        TabView {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.icon) {
                    section.destination
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(TimerState())
        .environment(Entitlements())
        .modelContainer(for: [
            Expense.self, Client.self, Project.self,
            TimeEntry.self, MileageTrip.self, IncomeEntry.self
        ], inMemory: true)
}
