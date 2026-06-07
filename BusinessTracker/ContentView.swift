import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Time", systemImage: "clock") {
                TimeTrackingView()
            }
            Tab("Mileage", systemImage: "car") {
                MileageView()
            }
            Tab("Expenses", systemImage: "creditcard") {
                ExpensesView()
            }
            Tab("Reports", systemImage: "chart.bar") {
                ReportsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
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
