import SwiftUI
import SwiftData
import WidgetKit

@main
struct BusinessTrackerApp: App {
    @State private var timerState = TimerState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            Client.self,
            Project.self,
            TimeEntry.self,
            TimePreset.self,
            MileageTrip.self,
            IncomeEntry.self,
        ])
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.garbenTechnologies.BusinessTracker")
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // CloudKit unavailable (not signed in, simulator, etc.) — fall back to local store
            return try! ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            ])
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(timerState)
                    .onOpenURL { url in handleWidgetDeepLink(url) }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
            } else {
                OnboardingView()
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "freelanced" else { return }
        switch url.host {
        case "startTimer":  timerState.pendingWidgetAction = .startTimer
        case "logTime":     timerState.pendingWidgetAction = .logTime
        case "logTrip":     timerState.pendingWidgetAction = .logTrip
        case "addExpense":  timerState.pendingWidgetAction = .addExpense
        default: break
        }
    }
}
