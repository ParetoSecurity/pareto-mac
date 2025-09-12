//
//  ChecksSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

// Wrapper to avoid state modification during view updates
struct CheckWrapper: Identifiable {
    let id = UUID()
    let check: ParetoCheck
}

struct ChecksSettingsView: View {
    @State private var selectedCheckWrapper: CheckWrapper?
    @State private var refreshID = UUID()
    @Default(.teamID) var teamID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !teamID.isEmpty {
                    TeamEnforcementHeader()
                }

                // Security Check Sections
                ForEach(Claims.global.all, id: \.self) { claim in
                    CheckSectionView(
                        claimTitle: claim.title,
                        installedChecks: claim.checksSorted.filter { $0.isInstalled },
                        onSelect: { check in
                            selectedCheckWrapper = CheckWrapper(check: check)
                        }
                    )
                }

                Link("Learn more about security checks →", destination: URL(string: "https://paretosecurity.com/mac/checks?utm_source=\(AppInfo.utmSource)")!)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .id(refreshID)
        .frame(minHeight: 450)
        .onReceive(NotificationCenter.default.publisher(for: .runChecksFinished)) { _ in
            // Force refresh of the list after checks complete
            refreshID = UUID()
        }
        .sheet(item: $selectedCheckWrapper, onDismiss: {
            // Force refresh when sheet closes
            refreshID = UUID()
        }) { wrapper in
            if wrapper.check.UUID == NoUnusedUsers.sharedInstance.UUID {
                NoUnusedUsersDetailView(check: wrapper.check)
            } else {
                CheckDetailView(check: wrapper.check)
            }
        }
    }
}

private struct TeamEnforcementHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checks marked with ✴ are enforced by your team and cannot be disabled")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
        }
    }
}

private struct CheckSectionView: View {
    let claimTitle: String
    let installedChecks: [ParetoCheck]
    let onSelect: (ParetoCheck) -> Void

    var body: some View {
        if !installedChecks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(claimTitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 1) {
                    ForEach(installedChecks, id: \.UUID) { check in
                        CheckRowView(check: check) {
                            onSelect(check)
                        }

                        if check.UUID != installedChecks.last?.UUID {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
}

private struct CheckRowView: View {
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

struct CheckDetailView: View {
    @ObservedObject var check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false

    init(check: ParetoCheck) {
        _check = ObservedObject(wrappedValue: check)
        _isActive = State(initialValue: check.isActive)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    // Revert changes if any
                    if hasChanges {
                        check.isActive = !isActive
                    }
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Text(check.TitleON)
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section {
                    if check.teamEnforced {
                        HStack {
                            Text("✴")
                                .foregroundColor(.orange)
                            Text("This check is required by your team")
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Enable this check", isOn: $isActive)
                        .disabled(!check.showSettings || check.teamEnforced)
                        .onChange(of: isActive) { newValue in
                            check.isActive = newValue
                            hasChanges = true
                        }
                }

                Section(header: Text("Description")) {
                    Text(check.TitleON)
                        .font(.body)

                    if !check.TitleOFF.isEmpty {
                        Text("When failing: \(check.TitleOFF)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Link("Learn more about this check →", destination: check.infoURL)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                }

                // SSH-specific: allow ignoring selected SSH keys
                if check is SSHKeysCheck || check is SSHKeysStrengthCheck {
                    Section(header: Text("Ignored SSH Keys")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose SSH keys to exclude from SSH-related checks (e.g., keys without passphrases or with weak strength).").font(.caption).foregroundColor(.secondary)
                            Divider()
                            IgnoredSSHKeysSettingsView().padding(.vertical, 4)
                        }
                    }
                }

                if check.showSettingsWarnDiskAccess && !check.isRunnable {
                    Section(header: Text("Permissions Required")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This check requires full disk access permission.")
                                .font(.body)

                            HStack {
                                Button("Authorize") {
                                    if #available(macOS 13.0, *) {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDisk")!)
                                    } else {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                                    }
                                    NSApp.activate(ignoringOtherApps: true)
                                }

                                Link("Learn More", destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    .font(.footnote)
                            }
                        }
                    }
                }

                if check.showSettingsWarnEvents && !check.isRunnable {
                    Section(header: Text("Permissions Required")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This check requires System Events access permission.")
                                .font(.body)

                            HStack {
                                Button("Authorize") {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                                }

                                Link("Learn More", destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    .font(.footnote)
                            }
                        }
                    }
                }

                Section(header: Text("Current Status")) {
                    if !check.isActive {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.gray)
                                Text("Check is disabled")
                                    .font(.headline)
                                Spacer()
                            }
                            Text("This check has been manually disabled")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else if !check.isRunnable {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Check cannot run")
                                    .font(.headline)
                                Spacer()
                            }
                            Text(check.disabledReason)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Status:")
                            Spacer()
                            if check.checkPassed {
                                Label("Passing", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                // Show specific failure reason
                                if check is TimeMachineCheck {
                                    Label("Time Machine is disabled or not configured", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                } else if check is TimeMachineHasBackupCheck {
                                    // Check if it's actually failing or just can't run
                                    if !TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable {
                                        Label(check.disabledReason, systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("No recent backup found", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else if check is TimeMachineIsEncryptedCheck {
                                    // Check if it's actually failing or just can't run
                                    if !TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable {
                                        Label(check.disabledReason, systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("Backup disk is not encrypted", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else if let appCheck = check as? AppCheck {
                                    // For app update checks
                                    if !appCheck.isInstalled {
                                        Label("App not installed", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    } else if !appCheck.usedRecently {
                                        Label("App not used in the last week", systemImage: "clock.badge.xmark.fill")
                                            .foregroundColor(.gray)
                                    } else {
                                        Label("Update available", systemImage: "arrow.down.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else {
                                    Label("Failing", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        if !check.cachedDetails.isEmpty && check.cachedDetails != "None" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Details:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(check.cachedDetails)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(height: 400)
    }
}

struct NoUnusedUsersDetailView: View {
    @ObservedObject var check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false
    @Default(.ignoredUserAccounts) var ignoredUserAccounts

    init(check: ParetoCheck) {
        _check = ObservedObject(wrappedValue: check)
        _isActive = State(initialValue: check.isActive)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    // Revert changes if any
                    if hasChanges {
                        check.isActive = !isActive
                    }
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Text(check.TitleON)
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section {
                    if check.teamEnforced {
                        HStack {
                            Text("✴")
                                .foregroundColor(.orange)
                            Text("This check is required by your team")
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Enable this check", isOn: $isActive)
                        .disabled(!check.showSettings || check.teamEnforced)
                        .onChange(of: isActive) { newValue in
                            check.isActive = newValue
                            hasChanges = true
                        }
                }

                Section(header: Text("Description")) {
                    Text("This check ensures that unused user accounts (non-admin accounts) are either removed or have logged in recently.")
                        .font(.body)

                    Text("When failing: \(check.TitleOFF)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("Learn more about this check →", destination: check.infoURL)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                }

                Section(header: Text("Ignored User Accounts")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configure which user accounts to exclude from this check. This is useful for service accounts that don't log in regularly.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        IgnoredUsersSettingsView()
                            .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Current Status")) {
                    if !check.isActive {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.gray)
                                Text("Check is disabled")
                                    .font(.headline)
                                Spacer()
                            }
                            Text("This check has been manually disabled")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else if !check.isRunnable {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Check cannot run")
                                    .font(.headline)
                                Spacer()
                            }
                            Text(check.disabledReason)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Status:")
                            Spacer()
                            if check.checkPassed {
                                Label("Passing", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                // Show specific failure reason
                                if check is TimeMachineCheck {
                                    Label("Time Machine is disabled or not configured", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                } else if check is TimeMachineHasBackupCheck {
                                    // Check if it's actually failing or just can't run
                                    if !TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable {
                                        Label(check.disabledReason, systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("No recent backup found", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else if check is TimeMachineIsEncryptedCheck {
                                    // Check if it's actually failing or just can't run
                                    if !TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable {
                                        Label(check.disabledReason, systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("Backup disk is not encrypted", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else if let appCheck = check as? AppCheck {
                                    // For app update checks
                                    if !appCheck.isInstalled {
                                        Label("App not installed", systemImage: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    } else if !appCheck.usedRecently {
                                        Label("App not used in the last week", systemImage: "clock.badge.xmark.fill")
                                            .foregroundColor(.gray)
                                    } else {
                                        Label("Update available", systemImage: "arrow.down.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                } else {
                                    Label("Failing", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        if !check.cachedDetails.isEmpty && check.cachedDetails != "None" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Details:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(check.cachedDetails)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: 500)
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
