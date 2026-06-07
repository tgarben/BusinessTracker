import SwiftUI
import SwiftData

struct TimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerState.self) private var timerState
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var showQuickSave = false
    @State private var showFullForm = false
    @State private var stoppedHours: Double = 0

    private var availableProjects: [Project] {
        selectedClient?.projects.sorted { $0.name < $1.name } ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Clock display
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(timerState.isRunning ? timerState.elapsed.timerFormatted : "0:00:00")
                        .font(.system(size: 64, weight: .thin, design: .monospaced))
                        .foregroundStyle(timerState.isRunning ? .red : .primary)
                        .contentTransition(.numericText())
                }

                // Client / project pickers (only when not yet running)
                if !timerState.isRunning {
                    VStack(spacing: 12) {
                        Picker("Client", selection: $selectedClient) {
                            Text("Select a client").tag(Optional<Client>.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(Optional(client))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: selectedClient) { _, _ in selectedProject = nil }

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
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 4) {
                        if let client = timerState.client {
                            Text(client.name).font(.headline)
                        }
                        if let project = timerState.project {
                            Text(project.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Start / Stop button
                Button {
                    if timerState.isRunning {
                        stoppedHours = timerState.stop()
                        showQuickSave = true
                    } else {
                        timerState.start(client: selectedClient, project: selectedProject)
                    }
                } label: {
                    Label(
                        timerState.isRunning ? "Stop" : "Start",
                        systemImage: timerState.isRunning ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 180, height: 56)
                    .background(
                        timerState.isRunning ? Color.red : Color.green,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
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
            // Quick-save half sheet after stopping
            .sheet(isPresented: $showQuickSave, onDismiss: {
                if !showFullForm { dismiss() }
            }) {
                QuickSaveSheet(hours: stoppedHours) {
                    showFullForm = true
                }
            }
            // Full form — opened from "Log with details…" in QuickSaveSheet
            .sheet(isPresented: $showFullForm, onDismiss: { dismiss() }) {
                LogTimeView(
                    prefillHours: stoppedHours,
                    prefillClient: selectedClient,
                    prefillProject: selectedProject
                )
            }
        }
    }
}
