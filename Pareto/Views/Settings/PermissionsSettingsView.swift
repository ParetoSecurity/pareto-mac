//
//  PermissionsSettingsView.swift
//  GeneralSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import os.log
import SwiftUI

struct PermissionsSettingsView: View {
    @StateObject private var helperToolManager = HelperToolManager()
    @StateObject private var checker = PermissionsChecker()

    // MARK: - System Settings deep links

    private enum PrivacyPane {
        case automation
        case fullDisk

        var url: URL? {
            switch self {
            case .automation:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
            case .fullDisk:
                if #available(macOS 13.0, *) {
                    return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDisk")
                } else {
                    return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
                }
            }
        }

        var learnMoreURL: URL {
            switch self {
            case .automation:
                return URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!
            case .fullDisk:
                return URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!
            }
        }
    }

    @MainActor
    private func openSystemSettingsPane(_ pane: PrivacyPane) {
        guard let url = pane.url else {
            os_log("Failed to construct System Settings URL for %{public}s", String(describing: pane))
            return
        }
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            os_log("Failed to open System Settings URL: %{public}s", url.absoluteString)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @MainActor
    private func authorizeOSAClick() {
        openSystemSettingsPane(.automation)
    }

    @MainActor
    private func authorizeFDAClick() {
        openSystemSettingsPane(.fullDisk)
    }

    @MainActor
    private func authorizeFWClick() async {
        if checker.firewallAuthorized {
            await helperToolManager.manageHelperTool(action: .uninstall)
        } else {
            await helperToolManager.manageHelperTool(action: .install)
        }
    }

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow the app read-only access to the system. These permissions do not allow changing or running any of the system settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
            .padding(.bottom, 4)

            // Firewall (macOS 15+)
            if #available(macOS 15, *) {
                PermissionCard(
                    icon: "shield.lefthalf.filled",
                    iconTint: .blue,
                    title: "Firewall Access",
                    message: "App requires read-only access to firewall to perform checks.",
                    learnMoreURL: URL(string: "https://paretosecurity.com/docs/mac/privileged-helper-authorization?utm_source=\(AppInfo.utmSource)"),
                    status: status(for: checker.firewallAuthorized),
                    isVerifying: !checker.ran,
                    primaryActionTitle: checker.firewallAuthorized ? "Authorized" : "Authorize",
                    primaryActionRole: checker.firewallAuthorized ? .none : .none,
                    primaryActionEnabled: checker.ran && !checker.firewallAuthorized,
                    primaryAction: {
                        Task { await authorizeFWClick() }
                    },
                    secondaryActionTitle: checker.firewallAuthorized ? "Remove" : nil,
                    secondaryActionRole: .destructive,
                    secondaryActionEnabled: checker.ran && checker.firewallAuthorized,
                    secondaryAction: {
                        Task { await authorizeFWClick() }
                    }
                )
            }

            // System Events (OSA)
            PermissionCard(
                icon: "gearshape.2.fill",
                iconTint: .indigo,
                title: "System Events Access",
                message: "App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks.",
                learnMoreURL: PrivacyPane.automation.learnMoreURL,
                status: status(for: checker.osaAuthorized),
                isVerifying: !checker.ran,
                primaryActionTitle: checker.osaAuthorized ? "Authorized" : "Authorize",
                primaryActionRole: .none,
                primaryActionEnabled: checker.ran && !checker.osaAuthorized,
                primaryAction: { authorizeOSAClick() }
            )

            // Full Disk Access
            PermissionCard(
                icon: "externaldrive.fill",
                iconTint: .orange,
                title: "Full Disk Access",
                message: "App requires full disk access if you want to use the Time Machine checks.",
                learnMoreURL: PrivacyPane.fullDisk.learnMoreURL,
                status: status(for: checker.fdaAuthorized),
                isVerifying: !checker.ran,
                primaryActionTitle: checker.fdaAuthorized ? "Authorized" : "Authorize",
                primaryActionRole: .none,
                primaryActionEnabled: checker.ran && !checker.fdaAuthorized,
                primaryAction: { authorizeFDAClick() }
            )
        }
        .padding(20)
        .onAppear { checker.start() }
        .onDisappear { checker.stop() }
    }

    private func status(for authorized: Bool) -> PermissionStatus {
        authorized ? .authorized : .needsAuthorization
    }
}

// MARK: - Components

private enum PermissionStatus {
    case authorized
    case needsAuthorization
    case verifying
}

private struct StatusPill: View {
    let status: PermissionStatus
    let isVerifying: Bool

    // Match the SF Symbol size for .small to keep height consistent
    private let iconSquare: CGFloat = 12

    var body: some View {
        HStack(spacing: 6) {
            if isVerifying {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.mini)
                    .frame(width: iconSquare, height: iconSquare, alignment: .center)
            } else {
                Image(systemName: iconName)
                    .imageScale(.small)
                    .frame(width: iconSquare, height: iconSquare, alignment: .center)
            }
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundColor.opacity(0.15))
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
        .animation(.default, value: isVerifying)
        .animation(.default, value: status)
    }

    private var label: String {
        if isVerifying { return "Verifying" }
        switch status {
        case .authorized: return "Authorized"
        case .needsAuthorization: return "Authorize"
        case .verifying: return "Verifying"
        }
    }

    private var iconName: String {
        switch status {
        case .authorized: return "checkmark.seal.fill"
        case .needsAuthorization: return "exclamationmark.triangle.fill"
        case .verifying: return "hourglass"
        }
    }

    private var backgroundColor: Color {
        if isVerifying { return .gray }
        switch status {
        case .authorized: return .green
        case .needsAuthorization: return .orange
        case .verifying: return .gray
        }
    }

    private var foregroundColor: Color {
        if isVerifying { return .secondary }
        switch status {
        case .authorized: return .green
        case .needsAuthorization: return .orange
        case .verifying: return .secondary
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    let learnMoreURL: URL?
    let status: PermissionStatus
    let isVerifying: Bool

    // Primary action
    var primaryActionTitle: String
    var primaryActionRole: ButtonRole? = nil
    var primaryActionEnabled: Bool = true
    var primaryAction: () -> Void

    // Optional secondary action (e.g., Remove)
    var secondaryActionTitle: String? = nil
    var secondaryActionRole: ButtonRole? = nil
    var secondaryActionEnabled: Bool = true
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Header moved into content so it shares the same inset as the description
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(iconTint)
                        .imageScale(.large)
                        .frame(width: 22)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    StatusPill(status: status, isVerifying: isVerifying)
                }
                .padding(.bottom, 6)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                HStack(spacing: 8) {
                    if primaryActionEnabled {
                        Button(role: primaryActionRole, action: primaryAction) {
                            Text(primaryActionTitle)
                                .frame(minWidth: 90)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }

                    if let secondaryTitle = secondaryActionTitle, let secondary = secondaryAction {
                        Button(role: secondaryActionRole, action: secondary) {
                            Text(secondaryTitle)
                                .frame(minWidth: 90)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!secondaryActionEnabled)
                    }

                    Spacer()

                    if let url = learnMoreURL {
                        Link("Learn more", destination: url)
                            .font(.footnote)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.top, 6)
        } label: {
            // Empty label so the GroupBox keeps its style but header is inside content
            EmptyView()
        }
    }
}

// MARK: - Preview

struct PermissionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSettingsView()
            .frame(height: 560)
    }
}
