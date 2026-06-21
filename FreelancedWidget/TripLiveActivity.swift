import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity attributes (must match BusinessTracker/Models/TripActivityAttributes.swift)

struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var miles: Double
        var pauseTime: Date? = nil
    }
}

// MARK: - Brand palette (live trip tracking = green, matching the in-app card/FAB)

private let tripGreen = Color.green

// MARK: - App-icon-style badge

private struct TripAppBadge: View {
    var size: CGFloat = 50
    var corner: CGFloat = 13

    var body: some View {
        Image("freelancedLogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: tripGreen.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}

private struct TrackingTripLabel: View {
    var paused: Bool = false
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(paused ? Color.orange : Color.red).frame(width: 6, height: 6)
            Text(paused ? "PAUSED" : "TRACKING TRIP")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(paused ? Color.orange : tripGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private func milesText(_ miles: Double, size: CGFloat) -> some View {
    Text(String(format: "%.1f mi", miles))
        .monospacedDigit()
        .font(.system(size: size, weight: .bold, design: .rounded))
        .foregroundStyle(tripGreen)
}

private func elapsed(from start: Date, pauseTime: Date?, size: CGFloat) -> some View {
    Text(timerInterval: start...Date.distantFuture, pauseTime: pauseTime, countsDown: false)
        .monospacedDigit()
        .font(.system(size: size, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
}

// MARK: - Live Activity widget

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripLockScreenView(context: context)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [tripGreen.opacity(0.16), tripGreen.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        TripAppBadge(size: 42, corner: 11)
                        VStack(alignment: .leading, spacing: 2) {
                            TrackingTripLabel(paused: context.state.pauseTime != nil)
                            milesText(context.state.miles, size: 22).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            elapsed(from: context.state.startDate, pauseTime: context.state.pauseTime, size: 18)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .multilineTextAlignment(.trailing)
                            Text("Freelanced")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.trailing, 4)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tripGreen)
            } compactTrailing: {
                Text(String(format: "%.1f mi", context.state.miles))
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tripGreen)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                Image(systemName: "car.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tripGreen)
            }
            // No widgetURL — a trip is already tracking, so tapping should just
            // open the app (not deep-link to the Log Trip sheet).
            .keylineTint(tripGreen)
        }
    }
}

// MARK: - Lock screen / banner view

struct TripLockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            TripAppBadge()
            VStack(alignment: .leading, spacing: 3) {
                TrackingTripLabel(paused: context.state.pauseTime != nil)
                milesText(context.state.miles, size: 26).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                elapsed(from: context.state.startDate, pauseTime: context.state.pauseTime, size: 20)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("Freelanced")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
