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

    /// The configuration form is tall enough to clip at `.medium` once the project
    /// picker appears (a client with projects, e.g. filled in by a preset), so we
    /// open at `.large` in that case. (iPhone only — iPad has no detents.)
    private var prefersLargeDetent: Bool {
        !timerState.isActive && !availableProjects.isEmpty
    }

    private func syncDetent() {
        sheetDetent = prefersLargeDetent ? .large : .medium
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if let hours = savedHours {
                    // Brief confirmation — auto-dismisses
                    savedConfirmation(hours: hours)
                } else {
                    // Clock
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(timerState.isActive ? timerState.elapsed.timerFormatted : "0:00:00")
                            .font(.system(size: 64, weight: .thin, design: .monospaced))
                            .foregroundStyle(timerState.isRunning ? .red : (timerState.isPaused ? .orange : .primary))
                            .contentTransition(reduceMotion ? .identity : .numericText())
                    }

                    if !timerState.isActive {
                        // Pickers + optional preset shortcuts
                        VStack(spacing: 12) {
                            Picker("Client", selection: $selectedClient) {
                                Text("Uncategorized").tag(Optional<Client>.none)
                                ForEach(clients) { client in
                                    Text(client.name).tag(Optional(client))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: selectedClient) { _, newClient in
                                if selectedProject?.client?.persistentModelID != newClient?.persistentModelID {
                                    selectedProject = nil
                                }
                                activePreset = nil // manual change overrides preset
                            }

                            if !availableProjects.isEmpty {
                                Picker("Project", selection: $selectedProject) {
                                    Text("No project").tag(Optional<Project>.none)
                                    ForEach(availableProjects) { project in
                                        Text(project.name).tag(Optional(project))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }

                            // Preset quick-start buttons
                            if !presets.isEmpty {
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
                                                    Image(systemName: "bolt.fill")
                                                        .font(.footnote)
                                                    Text(preset.name)
                                                        .font(.body.weight(.semibold))
                                                        .lineLimit(1)
                                                }
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 12)
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

                            // Prominent manage-presets button
                            Button { showPresets = true } label: {
                                Label(presets.isEmpty ? "Create a Preset" : "Manage Presets",
                                      systemImage: "slider.horizontal.3")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Show what we're tracking
                        VStack(spacing: 4) {
                            Text(selectedClient?.name ?? "Uncategorized")
                                .font(.headline)
                            if let project = selectedProject {
                                Text(project.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Controls — Start when idle; Pause/Resume + Stop while a session is active
                    if timerState.isActive {
                        HStack(spacing: 14) {
                            Button {
                                if timerState.isRunning { timerState.pause() } else { timerState.resume() }
                            } label: {
                                Label(
                                    timerState.isRunning ? "Pause" : "Resume",
                                    systemImage: timerState.isRunning ? "pause.circle.fill" : "play.circle.fill"
                                )
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .frame(width: 145, height: 56)
                                .background(timerState.isRunning ? Color.orange : Color.green,
                                            in: RoundedRectangle(cornerRadius: 16))
                            }
                            Button { stopAndSave() } label: {
                                Label("Stop", systemImage: "stop.circle.fill")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 145, height: 56)
                                    .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    } else {
                        Button {
                            timerState.start(client: selectedClient, project: selectedProject)
                        } label: {
                            Label("Start", systemImage: "play.circle.fill")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 180, height: 56)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }

                Spacer()
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
        // iPhone: medium/large drag detents, auto-opening at .large when the form
        // is tall (project picker shown). iPad: apply NO detents so it presents as
        // the standard centered form sheet like every other sheet.
        // NOTE: we key off the device idiom, NOT horizontalSizeClass — content
        // inside a presented sheet on iPad reports `.compact`, so a size-class
        // check would wrongly apply phone detents on iPad.
        .modifier(PhoneSheetDetents(selection: $sheetDetent))
        .onAppear { syncDetent() }
        .onChange(of: selectedClient) { _, _ in syncDetent() }
        .onChange(of: selectedProject) { _, _ in syncDetent() }
        .onChange(of: timerState.isActive) { _, _ in syncDetent() }
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
