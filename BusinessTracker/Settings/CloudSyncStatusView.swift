import SwiftUI
import CloudKit

/// A single Settings row showing whether the user's data is backed up to iCloud,
/// so a silent local-only fallback or a signed-out account becomes visible.
/// Read-only; checks the CloudKit account status on appear. Embedded in the
/// "Backup & Sync" section alongside the manual export/import buttons.
struct CloudSyncRow: View {
    @State private var account: CKAccountStatus?

    private enum SyncState { case on, checking, signedOut, localOnly }

    private var state: SyncState {
        guard BusinessTrackerApp.cloudKitEnabled else { return .localOnly }
        switch account {
        case .available: return .on
        case .none:      return .checking
        default:         return .signedOut
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(symbol: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Sync")
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .task {
            account = try? await CKContainer(identifier: "iCloud.com.garbenTechnologies.BusinessTracker")
                .accountStatus()
        }
    }

    private var label: String {
        switch state {
        case .on:        return "On"
        case .checking:  return "Checking…"
        case .signedOut: return "Paused"
        case .localOnly: return "This Device"
        }
    }

    private var detail: String {
        switch state {
        case .on:        return "Backed up & syncing across your devices"
        case .checking:  return "Checking status…"
        case .signedOut: return "Saved here — sign in to iCloud to back up"
        case .localOnly: return "Saved on this device only"
        }
    }

    private var icon: String {
        switch state {
        case .on:        return "checkmark.icloud.fill"
        case .checking:  return "icloud"
        case .signedOut: return "exclamationmark.icloud.fill"
        case .localOnly: return "icloud.slash.fill"
        }
    }

    private var color: Color {
        switch state {
        case .on:        return .green
        case .checking:  return .gray
        case .signedOut, .localOnly: return .orange
        }
    }
}
