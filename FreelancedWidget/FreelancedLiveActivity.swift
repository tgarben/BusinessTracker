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

// MARK: - Brand palette

private let brandIndigo = Color(red: 0.36, green: 0.30, blue: 0.92)
private let brandIndigoDark = Color(red: 0.27, green: 0.20, blue: 0.78)

private var brandGradient: LinearGradient {
    LinearGradient(colors: [brandIndigo, brandIndigoDark], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - App-icon-style stopwatch badge

private struct TimerAppBadge: View {
    var size: CGFloat = 50
    var corner: CGFloat = 13
    var iconSize: CGFloat = 25

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(brandGradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: brandIndigo.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Live "tracking" pill

private struct TrackingLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(.red).frame(width: 6, height: 6)
            Text("TRACKING TIME")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(brandIndigo)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private func liveTimer(from start: Date, size: CGFloat) -> some View {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
        .monospacedDigit()
        .font(.system(size: size, weight: .bold, design: .rounded))
        .foregroundStyle(brandIndigo)
}

// MARK: - Live Activity widget

struct FreelancedLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(context: context)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [brandIndigo.opacity(0.16), brandIndigo.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        } dynamicIsland: { context in
            DynamicIsland {
                // Full-width bottom region — the narrow leading/trailing regions truncate
                // long text, so the whole banner lives here where it has the island's width.
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        TimerAppBadge(size: 42, corner: 11, iconSize: 21)

                        VStack(alignment: .leading, spacing: 2) {
                            TrackingLabel()
                            Text(title(context))
                                .font(.headline)
                                .lineLimit(1)
                            if !context.attributes.projectName.isEmpty {
                                Text(context.attributes.projectName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            liveTimer(from: context.state.startDate, size: 26)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.trailing)
                            Text("Freelanced")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.trailing,4)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(brandIndigo)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(brandIndigo)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(brandIndigo)
            }
            .widgetURL(URL(string: "freelanced://startTimer"))
            .keylineTint(brandIndigo)
        }
    }

    private func title(_ context: ActivityViewContext<TimerActivityAttributes>) -> String {
        context.attributes.clientName.isEmpty ? "Uncategorized" : context.attributes.clientName
    }
}

// MARK: - Lock screen / StandBy / banner view

struct TimerLockScreenView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    private var title: String {
        context.attributes.clientName.isEmpty ? "Uncategorized" : context.attributes.clientName
    }

    var body: some View {
        HStack(spacing: 14) {
            TimerAppBadge()

            VStack(alignment: .leading, spacing: 3) {
                TrackingLabel()
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if !context.attributes.projectName.isEmpty {
                    Text(context.attributes.projectName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

//            Spacer(minLength: 8)
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                liveTimer(from: context.state.startDate, size: 28)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
                Text("Freelanced")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
