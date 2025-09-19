import Defaults
import SwiftUI

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
