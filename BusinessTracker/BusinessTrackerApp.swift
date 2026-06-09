import SwiftUI
import SwiftData

@main
struct BusinessTrackerApp: App {
    @State private var timerState = TimerState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(timerState)
            } else {
                OnboardingView()
            }
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
