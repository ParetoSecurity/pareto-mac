import SwiftUI

/// Inline team badge component
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
    /// Sheets need their own Cancel/Done header; a standalone window has a title bar and close button instead.
    private let showsHeader: Bool
    @State private var prerequisiteDetails: String?

    init(check: ParetoCheck, showsHeader: Bool = true) {
        _check = ObservedObject(wrappedValue: check)
        self.showsHeader = showsHeader
        _isActive = State(initialValue: check.isActive)
        _prerequisiteDetails = State(initialValue: nil)
    }

    private var statusDetails: String {
        if let appCheck = check as? AppCheck {
            return appCheck.applicationLocation ?? "not found"
        }
        return check.cachedDetails.isEmpty ? check.details : check.cachedDetails
    }

    private var shouldShowDetails: Bool {
        if check is AppCheck {
            return true
        }
        if statusDetails.isEmpty || statusDetails == "None" {
            return false
        }
        return check.hasError || !check.checkPassed || check.showDetailsWhenPassing
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
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
            }

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

                    // infoURL embeds live check details (can mean re-reading files), so build it on click only
                    Button("Learn more about this check →") {
                        NSWorkspace.shared.open(check.infoURL)
                    }
                    .buttonStyle(.link)
                    .font(.footnote)
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

                if check is FirewallExceptionsCheck {
                    Section(header: Text("Apps Accepting Incoming Connections")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Allow apps that should keep accepting incoming connections, or remove the ones you don't need.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Divider()
                            IgnoredFirewallAppsSettingsView().padding(.vertical, 4)
                        }
                    }
                }

                if check.showSettingsWarnDiskAccess, !check.isRunnable {
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

                if check.showSettingsWarnEvents, !check.isRunnable {
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

                CheckStatusSection(
                    check: check,
                    prerequisiteDetails: prerequisiteDetails,
                    statusDetails: statusDetails,
                    shouldShowDetails: shouldShowDetails
                )
            }
            .formStyle(.grouped)
            .detailWindowSizing(showsHeader: showsHeader)
        }
        .closesWindowOnEscape(!showsHeader)
        .task {
            // Populate prerequisite details after view renders, outside the view update cycle
            if !check.isRunnable {
                prerequisiteDetails = check.prerequisiteFailureDetails
            }
        }
    }
}
