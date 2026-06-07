import SwiftUI
import SwiftData

@main
struct BusinessTrackerApp: App {
    @State private var timerState = TimerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerState)
        }
        .modelContainer(for: [
            Expense.self,
            Client.self,
            Project.self,
            TimeEntry.self,
            TimePreset.self,
            MileageTrip.self,
            IncomeEntry.self,
        ])
    }
}
