import WidgetKit
import SwiftUI

// MARK: - Timeline entries

struct SingleActionEntry: TimelineEntry {
    let date: Date
    let configuration: SingleActionConfiguration
}

struct QuadActionEntry: TimelineEntry {
    let date: Date
    let configuration: QuadActionConfiguration
}

// MARK: - Providers

struct SingleActionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleActionEntry {
        SingleActionEntry(date: .now, configuration: SingleActionConfiguration())
    }

    func snapshot(for configuration: SingleActionConfiguration, in context: Context) async -> SingleActionEntry {
        SingleActionEntry(date: .now, configuration: configuration)
    }

    func timeline(for configuration: SingleActionConfiguration, in context: Context) async -> Timeline<SingleActionEntry> {
        let entry = SingleActionEntry(date: .now, configuration: configuration)
        let reload = Calendar.current.date(byAdding: .hour, value: 24, to: .now)!
        return Timeline(entries: [entry], policy: .after(reload))
    }
}

struct QuadActionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuadActionEntry {
        QuadActionEntry(date: .now, configuration: QuadActionConfiguration())
    }

    func snapshot(for configuration: QuadActionConfiguration, in context: Context) async -> QuadActionEntry {
        QuadActionEntry(date: .now, configuration: configuration)
    }

    func timeline(for configuration: QuadActionConfiguration, in context: Context) async -> Timeline<QuadActionEntry> {
        let entry = QuadActionEntry(date: .now, configuration: configuration)
        let reload = Calendar.current.date(byAdding: .hour, value: 24, to: .now)!
        return Timeline(entries: [entry], policy: .after(reload))
    }
}

// MARK: - Small widget view (single action)

struct SingleActionWidgetView: View {
    let entry: SingleActionEntry

    private var action: WidgetQuickAction { entry.configuration.action }

    var body: some View {
        Link(destination: action.deepLink) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: action.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(action.color)
                }

                Text(action.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium widget view (quad actions)

struct QuadActionWidgetView: View {
    let entry: QuadActionEntry

    var body: some View {
        let actions = entry.configuration.actions
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(actions, id: \.rawValue) { action in
                Link(destination: action.deepLink) {
                    WidgetActionCell(action: action)
                }
                .buttonStyle(.plain)
            }
        }
//        .padding(4)
        .padding(0)
    }
}

struct WidgetActionCell: View {
    let action: WidgetQuickAction

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(action.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: action.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(action.color)
            }

            Text(action.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(action.color.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(action.color.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Widget definitions

struct FreelancedSmallWidget: Widget {
    let kind = "FreelancedSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleActionConfiguration.self,
            provider: SingleActionProvider()
        ) { entry in
            SingleActionWidgetView(entry: entry)
                .containerBackground(
                    entry.configuration.action.color.opacity(0.08),
                    for: .widget
                )
        }
        .configurationDisplayName("Quick Action")
        .description("One-tap shortcut to your most-used action.")
        .supportedFamilies([.systemSmall])
    }
}

struct FreelancedMediumWidget: Widget {
    let kind = "FreelancedMediumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuadActionConfiguration.self,
            provider: QuadActionProvider()
        ) { entry in
            QuadActionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Four one-tap shortcuts on your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FreelancedSmallWidget()
} timeline: {
    SingleActionEntry(date: .now, configuration: {
        let c = SingleActionConfiguration(); c.action = .startTimer; return c
    }())
}

#Preview("Medium", as: .systemMedium) {
    FreelancedMediumWidget()
} timeline: {
    QuadActionEntry(date: .now, configuration: QuadActionConfiguration())
}
