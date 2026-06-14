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
            AboutYouPage(onNext: { currentPage = 2 })
                .tag(1)
            LocationPage(onNext: { currentPage = 3 })
                .tag(2)
            NotificationsPage(onNext: { currentPage = 4 })
                .tag(3)
            ReadyPage(onDone: { hasCompletedOnboarding = true })
                .tag(4)
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

// MARK: - About You

private struct AboutYouPage: View {
    let onNext: () -> Void

    @AppStorage("user_name") private var storedName: String = ""
    @AppStorage("home_sectionOrder") private var sectionOrder: String = HomeSection.defaultOrderString
    @AppStorage("user_primaryUse") private var primaryUse: String = "Mixed"

    @State private var name: String = ""
    @State private var selectedUse: String = "Mixed"

    private let useOptions: [(label: String, icon: String, color: Color)] = [
        ("Time & Billing", "clock.fill", .indigo),
        ("Mileage",        "car.fill",   .blue),
        ("Expenses",       "creditcard.fill", .red),
        ("Mixed",          "square.grid.2x2.fill", .purple),
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "person.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)
                    .padding(.bottom, 32)

                VStack(spacing: 8) {
                    Text("Let's personalize\nyour experience")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("You can change these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should we call you?")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)
                        TextField("First name", text: $name)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Use case picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you primarily track?")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(useOptions, id: \.label) { option in
                                Button {
                                    selectedUse = option.label
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: option.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(option.color)
                                            .frame(width: 22)
                                        Text(option.label)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedUse == option.label {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.indigo)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }

                                if option.label != useOptions.last?.label {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: save) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            name = storedName
            selectedUse = primaryUse
        }
    }

    private func save() {
        storedName = name.trimmingCharacters(in: .whitespaces)
        primaryUse = selectedUse
        sectionOrder = HomeSection.orderString(forUse: selectedUse)
        onNext()
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
