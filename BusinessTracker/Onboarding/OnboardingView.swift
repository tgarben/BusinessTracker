import SwiftUI
import CoreLocation
import UserNotifications

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onNext: { currentPage = 1 })
                .tag(0)
            LocationPage(onNext: { currentPage = 2 })
                .tag(1)
            NotificationsPage(onNext: { currentPage = 3 })
                .tag(2)
            ReadyPage(onDone: { hasCompletedOnboarding = true })
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(.easeInOut, value: currentPage)
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPageLayout(
            icon: "briefcase.fill",
            iconColor: .indigo,
            title: "Welcome to\nFreelance Tracker",
            subtitle: "Track your time, mileage, and expenses in one place — built for people who work for themselves.",
            buttonLabel: "Get Started",
            onNext: onNext
        )
    }
}

// MARK: - Location

private struct LocationPage: View {
    let onNext: () -> Void
    @State private var requested = false

    var body: some View {
        OnboardingPageLayout(
            icon: "location.fill",
            iconColor: .blue,
            title: "Mileage Tracking",
            subtitle: "Allow location access so the app can calculate driving distances automatically when you log a trip. You can always use manual entry instead.",
            buttonLabel: requested ? "Continue" : "Allow Location",
            onNext: {
                if requested {
                    onNext()
                } else {
                    requestLocation()
                }
            },
            secondaryLabel: requested ? nil : "Not Now",
            onSecondary: onNext
        )
    }

    private func requestLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        requested = true
    }
}

// MARK: - Notifications

private struct NotificationsPage: View {
    let onNext: () -> Void
    @State private var requested = false

    var body: some View {
        OnboardingPageLayout(
            icon: "bell.fill",
            iconColor: .orange,
            title: "Stay on Top of It",
            subtitle: "Get reminders for running timers, upcoming tax payment dates, and other helpful nudges. You control what you receive.",
            buttonLabel: requested ? "Continue" : "Allow Notifications",
            onNext: {
                if requested {
                    onNext()
                } else {
                    requestNotifications()
                }
            },
            secondaryLabel: requested ? nil : "Not Now",
            onSecondary: onNext
        )
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { requested = true }
        }
    }
}

// MARK: - Ready

private struct ReadyPage: View {
    let onDone: () -> Void

    var body: some View {
        OnboardingPageLayout(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "You're All Set",
            subtitle: "Start by logging your first time entry, trip, or expense. Everything you track flows into Reports automatically.",
            buttonLabel: "Start Tracking",
            onNext: onDone
        )
    }
}

// MARK: - Shared page layout

private struct OnboardingPageLayout: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonLabel: String
    let onNext: () -> Void
    var secondaryLabel: String? = nil
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 72))
                    .foregroundStyle(iconColor)
                    .padding(.bottom, 40)

                // Text
                VStack(spacing: 16) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onNext) {
                        Text(buttonLabel)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(iconColor, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let secondaryLabel, let onSecondary {
                        Button(secondaryLabel, action: onSecondary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
