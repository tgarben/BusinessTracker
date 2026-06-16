import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - Root

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("user_name") private var userName: String = ""
    @State private var page = 0

    private let total = 5

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            TabView(selection: $page) {
                WelcomePage(page: 0, total: total) { advance() }
                    .tag(0)
                AboutYouPage(page: 1, total: total) { advance() }
                    .tag(1)
                BusinessInfoPage(page: 2, total: total, onSkip: { advance() }) { advance() }
                    .tag(2)
                PermissionsPage(page: 3, total: total, onSkip: { advance() }) { advance() }
                    .tag(3)
                ReadyPage(page: 4, total: total, name: userName) { finish() }
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(duration: 0.4), value: page)
        }
    }

    private func advance() {
        withAnimation(.spring(duration: 0.4)) { page = min(page + 1, total - 1) }
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Shared building blocks

private let onboardingIndigo = Color.indigo

/// App-icon-style rounded badge with a white glyph.
private struct OnboardingBadge: View {
    let icon: String
    var color: Color = onboardingIndigo
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.3), radius: 14, x: 0, y: 8)
    }
}

private struct OnboardingProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? onboardingIndigo : Color.secondary.opacity(0.22))
                    .frame(width: i == current ? 24 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.4), value: current)
    }
}

/// Page scaffold: progress + optional skip on top, scrollable content, pinned buttons at bottom.
private struct OnboardingScaffold<Content: View>: View {
    let page: Int
    let total: Int
    var onSkip: (() -> Void)? = nil
    let primaryLabel: String
    var primaryColor: Color = onboardingIndigo
    var primaryDisabled: Bool = false
    let onPrimary: () -> Void
    var secondaryLabel: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingProgress(current: page, total: total)
                Spacer()
                if let onSkip {
                    Button("Skip", action: onSkip)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 6) {
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(primaryColor.gradient, in: RoundedRectangle(cornerRadius: 15))
                        .opacity(primaryDisabled ? 0.5 : 1)
                }
                .disabled(primaryDisabled)

                if let secondaryLabel, let onSecondary {
                    Button(secondaryLabel, action: onSecondary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    let page: Int
    let total: Int
    let onNext: () -> Void

    private let features: [(icon: String, color: Color, title: String, subtitle: String)] = [
        ("clock.fill", .indigo, "Time tracking", "Live timer or manual entry, billed per project"),
        ("car.fill", .blue, "Mileage", "Auto driving distance with IRS deductions"),
        ("creditcard.fill", .red, "Expenses", "Categorize and attach receipts"),
        ("doc.text.fill", .purple, "Invoices", "Professional PDFs from your tracked work"),
    ]

    var body: some View {
        OnboardingScaffold(page: page, total: total, primaryLabel: "Get Started", onPrimary: onNext) {
            VStack(spacing: 0) {
                OnboardingBadge(icon: "stopwatch.fill", size: 92)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Text("Welcome to Freelanced")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .multilineTextAlignment(.center)

                Text("Everything you need to run your freelance business — in one place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                VStack(spacing: 14) {
                    ForEach(features, id: \.title) { f in
                        FeatureRow(icon: f.icon, color: f.color, title: f.title, subtitle: f.subtitle)
                    }
                }
                .padding(.top, 32)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - About You

private struct AboutYouPage: View {
    let page: Int
    let total: Int
    let onNext: () -> Void

    @AppStorage("user_name") private var storedName: String = ""
    @AppStorage("user_lastName") private var storedLastName: String = ""
    @AppStorage("home_sectionOrder") private var sectionOrder: String = HomeSection.defaultOrderString
    @AppStorage("user_primaryUse") private var primaryUse: String = ""

    @State private var name: String = ""
    @State private var lastName: String = ""
    @State private var focuses: Set<String> = []
    @FocusState private var focusedField: NameField?

    private enum NameField { case first, last }
    private let focusOptions = ["Time Tracking", "Mileage", "Expenses", "Invoicing"]

    var body: some View {
        OnboardingScaffold(
            page: page, total: total,
            primaryLabel: "Continue",
            primaryDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty,
            onPrimary: save
        ) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingBadge(icon: "person.fill", size: 76)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 22)

                Text("A little about you")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text("We'll personalize your home screen. Change it anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 32)

                Text("YOUR NAME")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.bottom, 8)

                VStack(spacing: 10) {
                    TextField("First name", text: $name)
                        .font(.body)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .first)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .last }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    TextField("Last name", text: $lastName)
                        .font(.body)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .last)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                Text("Your last name appears on invoices and data exports.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 4)

                Text("WHAT DO YOU FOCUS ON?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 26)
                    .padding(.bottom, 10)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(focusOptions, id: \.self) { option in
                        focusChip(option)
                    }
                }

                Text("Pick any that apply — this orders your home screen.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
                    .padding(.leading, 4)
            }
        }
        .onAppear {
            name = storedName
            lastName = storedLastName
            focuses = Set(primaryUse.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
    }

    private func focusChip(_ option: String) -> some View {
        let selected = focuses.contains(option)
        return Button {
            if selected { focuses.remove(option) } else { focuses.insert(option) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? AnyShapeStyle(onboardingIndigo) : AnyShapeStyle(.tertiary))
                Text(option)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? onboardingIndigo.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? onboardingIndigo.opacity(0.45) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        storedName = name.trimmingCharacters(in: .whitespaces)
        storedLastName = lastName.trimmingCharacters(in: .whitespaces)
        let ordered = focusOptions.filter { focuses.contains($0) }
        primaryUse = ordered.joined(separator: ",")
        sectionOrder = HomeSection.orderString(forFocuses: primaryUse)
        focusedField = nil
        onNext()
    }
}

// MARK: - Business info

private struct BusinessInfoPage: View {
    let page: Int
    let total: Int
    let onSkip: () -> Void
    let onNext: () -> Void

    @AppStorage("business_name") private var businessName: String = ""
    @AppStorage("business_address") private var businessAddress: String = ""
    @AppStorage("business_address2") private var businessAddress2: String = ""
    @AppStorage("business_phone") private var businessPhone: String = ""
    @AppStorage("business_email") private var businessEmail: String = ""
    @AppStorage("business_website") private var businessWebsite: String = ""
    @AppStorage("business_taxID") private var businessTaxID: String = ""

    var body: some View {
        OnboardingScaffold(
            page: page, total: total,
            onSkip: onSkip,
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingBadge(icon: "building.2.fill", size: 76)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 22)

                Text("Your business")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Text("This appears on the invoices you send. Add it now or anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                VStack(spacing: 10) {
                    field("Business name", text: $businessName, keyboard: .default)

                    AddressEntryField(label: "", line1: $businessAddress, line2: $businessAddress2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    field("Phone", text: $businessPhone, keyboard: .phonePad, isPhone: true)
                    field("Email", text: $businessEmail, keyboard: .emailAddress)
                    field("Website", text: $businessWebsite, keyboard: .URL)
                    field("Tax ID / EIN", text: $businessTaxID, keyboard: .default)
                }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, isPhone: Bool = false) -> some View {
        let lower = keyboard == .emailAddress || keyboard == .URL
        return TextField(placeholder, text: text)
            .font(.body)
            .keyboardType(keyboard)
            .textInputAutocapitalization(lower ? .never : .words)
            .autocorrectionDisabled(lower)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .onChange(of: text.wrappedValue) { _, new in
                guard isPhone else { return }
                let formatted = formatPhoneNumber(new)
                if formatted != new { text.wrappedValue = formatted }
            }
    }
}

// MARK: - Permissions

private struct PermissionsPage: View {
    let page: Int
    let total: Int
    let onSkip: () -> Void
    let onNext: () -> Void

    @State private var locationDone = false
    @State private var notificationsDone = false

    var body: some View {
        OnboardingScaffold(
            page: page, total: total,
            onSkip: onSkip,
            primaryLabel: "Continue",
            onPrimary: onNext
        ) {
            VStack(spacing: 0) {
                OnboardingBadge(icon: "checkmark.shield.fill", size: 76)
                    .padding(.bottom, 22)

                Text("Enable the essentials")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .multilineTextAlignment(.center)

                Text("Optional, but they make tracking effortless. You stay in control.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.bottom, 32)

                VStack(spacing: 14) {
                    PermissionCard(
                        icon: "location.fill", color: .blue,
                        title: "Location",
                        description: "Auto-calculate driving distance when you log a trip.",
                        done: locationDone,
                        action: requestLocation
                    )
                    PermissionCard(
                        icon: "bell.fill", color: .orange,
                        title: "Notifications",
                        description: "Reminders before quarterly tax deadlines.",
                        done: notificationsDone,
                        action: requestNotifications
                    )
                }
            }
        }
    }

    private func requestLocation() {
        CLLocationManager().requestWhenInUseAuthorization()
        withAnimation { locationDone = true }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { withAnimation { notificationsDone = true } }
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button("Enable", action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(color.opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Ready

private struct ReadyPage: View {
    let page: Int
    let total: Int
    let name: String
    let onDone: () -> Void

    private var greeting: String {
        let n = name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "You're all set" : "You're all set, \(n)"
    }

    var body: some View {
        OnboardingScaffold(page: page, total: total, primaryLabel: "Start Tracking", primaryColor: .green, onPrimary: onDone) {
            VStack(spacing: 0) {
                OnboardingBadge(icon: "checkmark", color: .green, size: 96)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                Text(greeting)
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .multilineTextAlignment(.center)

                Text("Log your first time entry, trip, or expense — it all flows into Reports automatically.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
