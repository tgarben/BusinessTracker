import SwiftData
import SwiftUI
import WidgetKit

@main
struct BusinessTrackerApp: App {
    @State private var timerState = TimerState()
    @State private var entitlements = Entitlements()
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
            Invoice.self,
            InvoiceLineItem.self,
            Quote.self,
            QuoteLineItem.self,
            MileagePreset.self,
            ExpensePreset.self,
        ])
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.garbenTechnologies.BusinessTracker")
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ CloudKit ModelContainer failed, falling back to local store: \(error)")
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
                    .environment(entitlements)
                    .onOpenURL { url in handleWidgetDeepLink(url) }
                    .task {
                        CloudKeyValueSync.start()
                        Self.purgeExpiredTrash()
                        consumePendingShortcutAction()
                        await entitlements.refresh()
                        await TaxReminders.reschedule()
                        await InvoiceReminders.reschedule(container: Self.sharedModelContainer)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        timerState.syncFromSharedStore()
                        consumePendingShortcutAction()
                        WidgetCenter.shared.reloadAllTimelines()
                        Self.purgeExpiredTrash()
                        Task { await entitlements.refresh() }
                        Task { await InvoiceReminders.reschedule(container: Self.sharedModelContainer) }
                    }
            } else {
                OnboardingView()
                    .environment(entitlements)
                    .task { CloudKeyValueSync.start() }
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    /// Permanently deletes any soft-deleted records whose 30-day Recently Deleted
    /// window has elapsed. Runs on launch and on foreground. For a Client, the real
    /// `modelContext.delete` here fires the normal cascade (projects + invoices).
    @MainActor
    static func purgeExpiredTrash() {
        let context = ModelContext(sharedModelContainer)
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        func purge<T: PersistentModel & SoftDeletable>(_ fetch: FetchDescriptor<T>) {
            guard let items = try? context.fetch(fetch) else { return }
            for item in items where (item.deletedDate ?? .now) < cutoff {
                context.delete(item)
            }
        }

        purge(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<MileageTrip>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<Expense>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<IncomeEntry>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<Invoice>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<Quote>(predicate: #Predicate { $0.deletedDate != nil }))
        purge(FetchDescriptor<Client>(predicate: #Predicate { $0.deletedDate != nil }))

        try? context.save()
    }

    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "freelanced" else { return }
        routeAction(url.host)
    }

    /// Reads an action queued by a Siri/Shortcuts App Intent and routes it to the right sheet.
    private func consumePendingShortcutAction() {
        guard let defaults = UserDefaults(suiteName: "group.com.garbenTechnologies.BusinessTracker"),
              let raw = defaults.string(forKey: "pendingShortcutAction") else { return }
        defaults.removeObject(forKey: "pendingShortcutAction")
        routeAction(raw)
    }

    private func routeAction(_ raw: String?) {
        switch raw {
        case "startTimer":    timerState.pendingWidgetAction = .startTimer
        case "logTime":       timerState.pendingWidgetAction = .logTime
        case "logTrip":       timerState.pendingWidgetAction = .logTrip
        case "addExpense":    timerState.pendingWidgetAction = .addExpense
        case "createInvoice": timerState.pendingWidgetAction = .createInvoice
        default: break
        }
    }
}
