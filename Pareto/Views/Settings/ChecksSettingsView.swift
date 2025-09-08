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
    @Default(.teamID) var teamID
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !teamID.isEmpty {
                    Text("Checks with asterisk (✴) are required by your team.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Security Check Sections
                ForEach(Claims.global.all, id: \.self) { claim in
                    let installedChecks = claim.checksSorted.filter { $0.isInstalled }
                    if !installedChecks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(claim.title)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 1) {
                                ForEach(installedChecks, id: \.UUID) { check in
                                    Button(action: { 
                                        selectedCheckWrapper = CheckWrapper(check: check)
                                    }) {
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
                                                            .foregroundColor(.orange)
                                                    }
                                                    Text(check.TitleON)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                }
                                                
                                                if !check.showSettings {
                                                    Text("Not Configurable")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                } else if !check.isActive {
                                                    Text("Disabled")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
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
                                    
                                    if check != installedChecks.last {
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
                
                Link("Learn more about security checks →", destination: URL(string: "https://paretosecurity.com/security-checks?utm_source=\(AppInfo.utmSource)")!)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .frame(minHeight: 450)
        .sheet(item: $selectedCheckWrapper) { wrapper in
            if wrapper.check.UUID == NoUnusedUsers.sharedInstance.UUID {
                NoUnusedUsersDetailView(check: wrapper.check)
            } else {
                CheckDetailView(check: wrapper.check)
            }
        }
    }
    
    private func statusColor(for check: ParetoCheck) -> Color {
        // Color based on check status
        if !check.isActive {
            return Color.gray  // Disabled
        } else if !check.isRunnable {
            return Color.gray.opacity(0.7)  // Cannot run (missing permissions)
        } else if check.checkPasses() {
            return Color.green  // Passing
        } else {
            return Color.orange  // Failing
        }
    }
    
    private func iconName(for check: ParetoCheck) -> String {
        // Map checks to appropriate SF Symbols
        switch check {
        case is NoUnusedUsers:
            return "person.2.slash"
        case _ where check.TitleON.lowercased().contains("firewall"):
            return "flame"
        case _ where check.TitleON.lowercased().contains("password"):
            return "key"
        case _ where check.TitleON.lowercased().contains("update"):
            return "arrow.triangle.2.circlepath"
        case _ where check.TitleON.lowercased().contains("encryption") || check.TitleON.lowercased().contains("filevault"):
            return "lock.shield"
        case _ where check.TitleON.lowercased().contains("screen"):
            return "rectangle.inset.filled"
        case _ where check.TitleON.lowercased().contains("ssh"):
            return "terminal"
        case _ where check.TitleON.lowercased().contains("sharing"):
            return "person.2"
        case _ where check.TitleON.lowercased().contains("gatekeeper"):
            return "checkmark.shield"
        case _ where check.TitleON.lowercased().contains("autologin"):
            return "person.badge.clock"
        case _ where check.TitleON.lowercased().contains("time machine"):
            return "clock.arrow.circlepath"
        default:
            return "shield"
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
        self._isActive = State(initialValue: check.isActive)
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
        self._isActive = State(initialValue: check.isActive)
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
