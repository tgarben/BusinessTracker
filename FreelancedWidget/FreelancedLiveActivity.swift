import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity attributes (must match BusinessTracker/Models/TimerActivityAttributes.swift)

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
    }
    var clientName: String
    var projectName: String
}

// MARK: - Live Activity widget

struct FreelancedLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(context: context)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.clientName.isEmpty
                                 ? "Timer Running"
                                 : context.attributes.clientName)
                                .font(.headline)
                                .lineLimit(1)
                            if !context.attributes.projectName.isEmpty {
                                Text(context.attributes.projectName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(
                        timerInterval: context.state.startDate...Date.distantFuture,
                        countsDown: false
                    )
                    .monospacedDigit()
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.indigo)
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap to open Freelanced")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                Text(
                    timerInterval: context.state.startDate...Date.distantFuture,
                    countsDown: false
                )
                .monospacedDigit()
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.indigo)
                .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
            .widgetURL(URL(string: "freelanced://startTimer"))
            .keylineTint(.indigo)
        }
    }
}

// MARK: - Lock screen / StandBy / banner view

struct TimerLockScreenView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "timer")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.clientName.isEmpty
                     ? "Timer Running"
                     : context.attributes.clientName)
                    .font(.headline)
                    .lineLimit(1)
                if !context.attributes.projectName.isEmpty {
                    Text(context.attributes.projectName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(
                timerInterval: context.state.startDate...Date.distantFuture,
                countsDown: false
            )
            .monospacedDigit()
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.indigo)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
