import SwiftUI

struct CheckRowView: View {
    @ObservedObject var check: ParetoCheck
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon background with status-based color
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusColor(for: check))
                        .frame(width: 32, height: 32)

                    Image(systemName: iconName(for: check))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if check.teamEnforced {
                            Text("✴")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                        Text(check.TitleON)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    subtitleView(for: check)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subtitleView(for check: ParetoCheck) -> some View {
        // Show status details

        if !check.isActive {
            Text("Manually disabled")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else if check is TimeMachineHasBackupCheck && (!TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable) {
            // Special case for Time Machine backup check when Time Machine is disabled
            Text(check.disabledReason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else if !check.isRunnable {
            // For checks that can't run, show why (including dependency issues)
            Text(check.disabledReason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else if check.checkPassed {
            // For passing checks
            Text("Passing")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else if let appCheck = check as? AppCheck {
            // For app update checks
            if !appCheck.isInstalled {
                Text("\(appCheck.appMarketingName) not installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if !appCheck.usedRecently && appCheck.supportsRecentlyUsed {
                Text("Not used in the last week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("Update available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        } else {
            // Other failing checks
            let message: String = {
                if check.isRunnable,
                   !check.cachedDetails.isEmpty,
                   check.cachedDetails != "None"
                {
                    return check.cachedDetails
                } else {
                    return "Failing"
                }
            }()
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func statusColor(for check: ParetoCheck) -> Color {
        // Color based on cached check status - don't run the actual check
        if !check.isActive {
            return Color.gray // Disabled
        } else if !check.isRunnable {
            return Color.gray.opacity(0.7) // Cannot run (missing permissions)
        } else if check.checkPassed {
            return Color.green // Passing (cached)
        } else {
            return Color.orange // Failing (cached)
        }
    }

    private func iconName(for check: ParetoCheck) -> String {
        // Map checks to appropriate SF Symbols
        let titleLower = check.TitleON.lowercased()
        switch check {
        case is NoUnusedUsers:
            return "person.2.slash"
        default:
            if titleLower.contains("firewall") { return "flame" }
            if titleLower.contains("password") { return "key" }
            if titleLower.contains("update") { return "arrow.triangle.2.circlepath" }
            if titleLower.contains("encryption") || titleLower.contains("filevault") { return "lock.shield" }
            if titleLower.contains("screen") { return "rectangle.inset.filled" }
            if titleLower.contains("ssh") { return "terminal" }
            if titleLower.contains("sharing") { return "person.2" }
            if titleLower.contains("gatekeeper") { return "checkmark.shield" }
            if titleLower.contains("autologin") { return "person.badge.clock" }
            if titleLower.contains("time machine") { return "clock.arrow.circlepath" }
            return "shield"
        }
    }
}
