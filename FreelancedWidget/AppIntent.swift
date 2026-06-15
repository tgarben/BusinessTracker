import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Quick Action enum (mirrored from the main app)

enum WidgetQuickAction: String, CaseIterable, AppEnum {
    case startTimer
    case logTime
    case logTrip
    case addExpense
    case createInvoice

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Quick Action")
    }

    // Stable identifier — must not change or saved configurations won't decode
    static var typeIdentifier: String { "com.garbenTechnologies.BusinessTracker.WidgetQuickAction" }

    static var caseDisplayRepresentations: [WidgetQuickAction: DisplayRepresentation] {
        [
            .startTimer:    DisplayRepresentation(title: "Start Timer",    image: .init(systemName: "play.fill")),
            .logTime:       DisplayRepresentation(title: "Log Time",       image: .init(systemName: "clock.fill")),
            .logTrip:       DisplayRepresentation(title: "Log Trip",       image: .init(systemName: "car.fill")),
            .addExpense:    DisplayRepresentation(title: "Add Expense",    image: .init(systemName: "creditcard.fill")),
            .createInvoice: DisplayRepresentation(title: "Create Invoice", image: .init(systemName: "doc.text.fill")),
        ]
    }

    var label: String {
        switch self {
        case .startTimer:    return "Start Timer"
        case .logTime:       return "Log Time"
        case .logTrip:       return "Log Trip"
        case .addExpense:    return "Add Expense"
        case .createInvoice: return "Create Invoice"
        }
    }

    var icon: String {
        switch self {
        case .startTimer:    return "play.fill"
        case .logTime:       return "clock.fill"
        case .logTrip:       return "car.fill"
        case .addExpense:    return "creditcard.fill"
        case .createInvoice: return "doc.text.fill"
        }
    }

    var deepLink: URL {
        URL(string: "freelanced://\(rawValue)")!
    }

    var color: Color {
        switch self {
        case .startTimer, .logTime: return .indigo
        case .logTrip:              return .blue
        case .addExpense:           return .red
        case .createInvoice:        return .purple
        }
    }
}

// MARK: - Single action configuration (small widget)

struct SingleActionConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Quick Action Widget" }
    static var description: IntentDescription { "Choose one action to show on your home screen." }

    @Parameter(title: "Action", default: .startTimer)
    var action: WidgetQuickAction
}

// MARK: - Quad action configuration (medium widget)

struct QuadActionConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Quick Actions Widget" }
    static var description: IntentDescription { "Choose up to four actions to show on your home screen." }

    @Parameter(title: "First Action", default: .startTimer)
    var action1: WidgetQuickAction

    @Parameter(title: "Second Action", default: .logTime)
    var action2: WidgetQuickAction

    @Parameter(title: "Third Action", default: .logTrip)
    var action3: WidgetQuickAction

    @Parameter(title: "Fourth Action", default: .addExpense)
    var action4: WidgetQuickAction

    var actions: [WidgetQuickAction] { [action1, action2, action3, action4] }
}

