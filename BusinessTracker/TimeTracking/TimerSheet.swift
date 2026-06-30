import SwiftUI
import SwiftData

struct TimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerState.self) private var timerState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Client> { $0.deletedDate == nil }, sort: \Client.name) private var clients: [Client]
    @Query(sort: \TimePreset.sortOrder) private var presets: [TimePreset]

    @AppStorage("default_hourlyRate") private var defaultHourlyRate: Double = 0

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var activePreset: TimePreset?   // preset used to start this session
    @State private var showPresets = false
    @State private var sheetDetent: PresentationDetent = .medium

    // Post-save confirmation state
    @State private var savedHours: Double?
    @State private var savedClient: Client?
    @State private var savedProject: Project?

    private var availableProjects: [Project] {
        (selectedClient?.projects ?? []).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let hours = savedHours {
                    centered { savedConfirmation(hours: hours) }
                } else if timerState.isActive {
                    activeLayout
                } else {
                    idleLayout
                }
            }
            .navigationTitle("Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPresets) {
                PresetsView()
            }
        }
        // iPhone: medium/large drag detents (defaults to medium — the idle layout is
        // designed to fit there without scrolling). iPad: NO detents, so it presents
        // as the standard centered form sheet like every other sheet.
        // NOTE: key off the device idiom, NOT horizontalSizeClass — content inside a
        // presented sheet on iPad reports `.compact`, which would defeat a size check.
        .modifier(PhoneSheetDetents(selection: $sheetDetent))
    }

    // MARK: - Idle layout (configure + start) — fits at .medium without scrolling

    private var idleLayout: some View {
        VStack(spacing: 18) {
            clock(size: 46, idle: true)
                .padding(.top, 4)

            pickerCard

            presetSection

            Spacer(minLength: 8)

            Button {
                timerState.start(client: selectedClient, project: selectedProject)
            } label: {
                Label("Start Timer", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Active layout (running / paused)

    private var activeLayout: some View {
        VStack(spacing: 28) {
            Spacer()

            clock(size: 64, idle: false)

            VStack(spacing: 4) {
                Text(selectedClient?.name ?? timerState.client?.name ?? "Uncategorized")
                    .font(.headline)
                if let project = selectedProject ?? timerState.project {
                    Text(project.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    if timerState.isRunning { timerState.pause() } else { timerState.resume() }
                } label: {
                    Label(timerState.isRunning ? "Pause" : "Resume",
                          systemImage: timerState.isRunning ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(timerState.isRunning ? Color.orange : Color.green,
                                    in: RoundedRectangle(cornerRadius: 16))
                }
                Button { stopAndSave() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Clock

    private func clock(size: CGFloat, idle: Bool) -> some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(timerState.isActive ? timerState.elapsed.timerFormatted : "0:00:00")
                    .font(.system(size: size, weight: .thin, design: .monospaced))
                    .foregroundStyle(idle ? AnyShapeStyle(.secondary)
                                          : AnyShapeStyle(timerState.isRunning ? .red
                                                          : (timerState.isPaused ? .orange : .primary)))
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            if idle {
                Text("Ready to track")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if timerState.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Label("Tracking", systemImage: "record.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Client / Project picker card

    private var pickerCard: some View {
        VStack(spacing: 0) {
            pickerRow(icon: "person.crop.circle.fill", iconColor: .indigo, label: "Client") {
                Picker("Client", selection: $selectedClient) {
                    Text("Uncategorized").tag(Optional<Client>.none)
                    ForEach(clients) { client in
                        Text(client.name).tag(Optional(client))
                    }
                }
            } value: {
                selectedClient?.name ?? "Uncategorized"
            }
            .onChange(of: selectedClient) { _, newClient in
                if selectedProject?.client?.persistentModelID != newClient?.persistentModelID {
                    selectedProject = nil
                }
                activePreset = nil // manual change overrides preset
            }

            if !availableProjects.isEmpty {
                Divider().padding(.leading, 52)
                pickerRow(icon: "folder.fill", iconColor: .indigo, label: "Project") {
                    Picker("Project", selection: $selectedProject) {
                        Text("No project").tag(Optional<Project>.none)
                        ForEach(availableProjects) { project in
                            Text(project.name).tag(Optional(project))
                        }
                    }
                } value: {
                    selectedProject?.name ?? "No project"
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// A single tappable row in the picker card: icon + label on the left, the
    /// selected value + a menu chevron on the right. The `Menu`/`Picker` gives a
    /// native checkmarked dropdown without the heavy stacked-card look.
    private func pickerRow<P: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder picker: () -> P,
        value: () -> String
    ) -> some View {
        Menu {
            picker().pickerStyle(.inline)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Preset quick-start

    @ViewBuilder
    private var presetSection: some View {
        if presets.isEmpty {
            Button { showPresets = true } label: {
                Label("Create a Preset", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.indigo)
            }
        } else {
            VStack(spacing: 8) {
                HStack {
                    Text("Quick Start")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Manage") { showPresets = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presets) { preset in
                            let isActive = activePreset?.persistentModelID == preset.persistentModelID
                            Button {
                                selectedClient = preset.client
                                selectedProject = preset.project
                                activePreset = preset
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill").font(.footnote)
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isActive
                                            ? AnyShapeStyle(.indigo.opacity(0.2))
                                            : AnyShapeStyle(.regularMaterial), in: Capsule())
                                .overlay(Capsule().strokeBorder(isActive ? Color.indigo.opacity(0.5) : .clear, lineWidth: 1.5))
                            }
                            .foregroundStyle(isActive ? .indigo : .primary)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Layout helper

    /// Vertically + horizontally centers content (used for the saved confirmation).
    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Saved confirmation view

    @ViewBuilder
    private func savedConfirmation(hours: Double) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Saved")
                .font(.title.bold())

            VStack(spacing: 4) {
                Text(String(format: "%.2f hrs", hours))
                    .font(.title3)
                if let client = savedClient {
                    Text(client.name)
                        .foregroundStyle(.secondary)
                }
                if let project = savedProject {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Stop and auto-save

    private func stopAndSave() {
        // Capture before stop() clears them
        let client  = timerState.client
        let project = timerState.project
        let hours   = timerState.stop()

        // Preset overrides take priority; fall back to project rate, then global default
        let rate  = activePreset?.effectiveRate ?? project?.hourlyRate ?? defaultHourlyRate
        let notes = activePreset?.notesTemplate ?? ""

        let entry = TimeEntry(
            date: .now,
            client: client,
            project: project,
            hours: hours,
            hourlyRate: rate,
            notes: notes
        )
        modelContext.insert(entry)
        activePreset = nil

        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            savedHours   = hours
            savedClient  = client
            savedProject = project
        }

        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run { dismiss() }
        }
    }
}

/// Applies medium/large sheet detents on iPhone only. On iPad it applies nothing,
/// letting the sheet use the standard centered form-sheet presentation.
/// Uses the device idiom (not `horizontalSizeClass`) because sheet content on
/// iPad reports a `.compact` size class, which would defeat a size-class check.
private struct PhoneSheetDetents: ViewModifier {
    @Binding var selection: PresentationDetent
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    func body(content: Content) -> some View {
        if isPhone {
            content.presentationDetents([.medium, .large], selection: $selection)
        } else {
            content
        }
    }
}
