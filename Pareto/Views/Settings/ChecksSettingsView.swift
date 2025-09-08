//
//  ChecksSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct ChecksSettingsView: View {
    @State private var selectedCheck: ParetoCheck?
    @Default(.teamID) var teamID

    var body: some View {
        List {
            if !teamID.isEmpty {
                Section {
                    Text("Checks with asterisk (✴) are required by your team.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            // Security Check Sections
            ForEach(Claims.global.all, id: \.self) { claim in
                let installedChecks = claim.checksSorted.filter { $0.isInstalled }
                if !installedChecks.isEmpty {
                    Section(header: Text(claim.title)) {
                        ForEach(installedChecks, id: \.self) { check in
                            Button(action: { selectedCheck = check }) {
                                HStack {
                                    if check.teamEnforced {
                                        Text("✴")
                                            .foregroundColor(.orange)
                                    }

                                    Text(check.TitleON)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if !check.showSettings {
                                        Text("Not Configurable")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if check.isActive {
                                        Text("On")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Off")
                                            .foregroundColor(.secondary)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!check.showSettings && !check.teamEnforced)
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Learn More")
                        .font(.headline)
                    Link("About security checks on our website", destination: URL(string: "https://paretosecurity.com/security-checks?utm_source=\(AppInfo.utmSource)")!)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .listStyle(.inset)
        .frame(minHeight: 450)
        .sheet(item: $selectedCheck) { check in
            if check.UUID == NoUnusedUsers.sharedInstance.UUID {
                NoUnusedUsersDetailView(check: check)
            } else {
                CheckDetailView(check: check)
            }
        }
    }
}

struct CheckDetailView: View {
    let check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false

    init(check: ParetoCheck) {
        self.check = check
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
                }

                if check.showSettingsWarnDiskAccess && !check.isRunnable {
                    Section(header: Text("Permissions Required")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This check requires full disk access permission.")
                                .font(.body)

                            HStack {
                                Button("Authorize") {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
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
                    HStack {
                        Text("Status:")
                        Spacer()
                        if check.checkPasses() {
                            Label("Passing", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Failing", systemImage: "xmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    if !check.details.isEmpty && check.details != "None" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Details:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(check.details)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
    }
}

struct NoUnusedUsersDetailView: View {
    let check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false
    @Default(.ignoredUserAccounts) var ignoredUserAccounts

    init(check: ParetoCheck) {
        self.check = check
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
                    HStack {
                        Text("Status:")
                        Spacer()
                        if check.checkPasses() {
                            Label("Passing", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Failing", systemImage: "xmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    if !check.details.isEmpty && check.details != "None" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Details:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(check.details)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
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
