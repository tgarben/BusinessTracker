import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(TimerState.self) private var timerState

    @State private var showTimer = false
    @State private var showLogTime = false
    @State private var showLogTrip = false
    @State private var showAddExpense = false
    @State private var showCreateInvoice = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Mileage", systemImage: "car") {
                MileageView()
            }
            Tab("Time", systemImage: "clock") {
                TimeTrackingView()
            }
            Tab("Expenses", systemImage: "creditcard") {
                ExpensesView()
            }
            Tab("Clients", systemImage: "person.2") {
                ClientsView()
            }
        }
        .sheet(isPresented: $showTimer)         { TimerSheet().presentationDetents([.medium,.large]) }
        .sheet(isPresented: $showLogTime)       { LogTimeView() }
        .sheet(isPresented: $showLogTrip)       { LogTripView() }
        .sheet(isPresented: $showAddExpense)    { AddExpenseView() }
        .sheet(isPresented: $showCreateInvoice) { InvoiceQuickActionSheet() }
.onChange(of: timerState.pendingWidgetAction) { _, action in
            guard let action else { return }
            timerState.pendingWidgetAction = nil
            switch action {
            case .startTimer:    showTimer = true
            case .logTime:       showLogTime = true
            case .logTrip:       showLogTrip = true
            case .addExpense:    showAddExpense = true
            case .createInvoice: showCreateInvoice = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(TimerState())
        .modelContainer(for: [
            Expense.self, Client.self, Project.self,
            TimeEntry.self, MileageTrip.self, IncomeEntry.self
        ], inMemory: true)
}
