import SwiftUI

// Inline team badge component
private struct TeamRequiredBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.fill")
                .font(.system(size: compact ? 10 : 11))
            if !compact {
                Text("REQUIRED BY TEAM")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(
            Capsule()
                .fill(Color.orange)
        )
    }
}

struct CheckDetailView: View {
    @ObservedObject var check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false
    @State private var prerequisiteDetails: String?

    init(check: ParetoCheck) {
        _check = ObservedObject(wrappedValue: check)
        _isActive = State(initialValue: check.isActive)
        _prerequisiteDetails = State(initialValue: nil)
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
                            TeamRequiredBadge(compact: false)
                            Spacer()
                        }
                        .padding(.bottom, 4)
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
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Check cannot run")
                                    .font(.headline)
                                Spacer()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Why:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)

                                Text(check.disabledReason)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }

                            if let details = prerequisiteDetails, !details.isEmpty {
                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Technical Details:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fontWeight(.medium)

                                    Text(details)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            }

                            if check.teamEnforced {
                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "shield.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("Team Requirement:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fontWeight(.medium)
                                    }

                                    Text("This check is required by your team security policy. Please resolve the prerequisite issues to meet compliance requirements.")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
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

                        if !check.cachedDetails.isEmpty && check.cachedDetails != "None" && !check.checkPassed {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Details:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Safely attempt to parse markdown; fall back to plain text if it fails
                                let attributed = (try? AttributedString(markdown: check.cachedDetails)) ?? AttributedString(check.cachedDetails)
                                Text(attributed)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minHeight: 400)
        .task {
            // Populate prerequisite details after view renders, outside the view update cycle
            if !check.isRunnable {
                prerequisiteDetails = check.prerequisiteFailureDetails
            }
        }
    }
}
