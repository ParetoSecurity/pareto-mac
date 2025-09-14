//
//  AboutSettingsView.swift
//  AboutSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import ServiceManagement
import SwiftUI

struct AboutSettingsView: View {
    @State private var isLoading = false
    @State private var status = UpdateStates.Checking
    @State private var konami = 0
    @State private var hasCheckedForUpdates = false
    @State private var latestVersionFound = ""

    @Default(.showBeta) var showBeta

    enum UpdateStates: String {
        case Checking = "Checking for updates"
        case NewVersion = "New version found"
        case Installing = "Installing new update"
        case Updated = "App is up to date"
        case Failed = "Failed to update, download manually"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 64, idealWidth: 96, maxWidth: 96, minHeight: 64, idealHeight: 96, maxHeight: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .onTapGesture {
                        konami += 1
                        if konami >= 3 {
                            showBeta.toggle()
                            konami = 0
                            if showBeta {
                                let alert = NSAlert()
                                alert.messageText = "You are now part of a secret society seeing somewhat mysterious things."
                                alert.alertStyle = NSAlert.Style.informational
                                alert.addButton(withTitle: "Let me in")
                                alert.runModal()
                                fetch()
                            }
                        }
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pareto Security")
                        .font(.system(size: 22, weight: .semibold, design: .default))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Keep your Mac’s security settings in check")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // App details
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Version \(AppInfo.appVersion) • Build \(AppInfo.buildVersion)")
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    } icon: {
                        Image(systemName: "number.circle")
                    }

                    Label {
                        Text("Channel: \(AppInfo.utmSource)")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                // Keep label simple; padding handled by custom GroupBoxStyle below
                Text("Application")
            }

            // Updates
            #if !SETAPP_ENABLED
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Label {
                            Text(updateStatusText)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                        } icon: {
                            Image(systemName: updateStatusSymbol)
                                .foregroundStyle(updateStatusColor)
                        }

                        if self.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Spacer(minLength: 0)
                    }

                    ViewThatFits(in: .horizontal) {
                        // Horizontal button row if space allows
                        HStack(spacing: 8) {
                            updateButtons
                            Spacer(minLength: 0)
                        }

                        // Otherwise stack vertically
                        VStack(alignment: .leading, spacing: 6) {
                            updateButtons
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Updates")
            }
            #endif

            Divider()

            // Footer (Markdown, centered)
            VStack(spacing: 4) {
                Text("We'd love to [hear from you!](https://paretosecurity.com/contact)")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Made with ❤️ in 🇪🇺")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .padding(16)
        // Apply consistent, tighter header/content spacing for all GroupBoxes in this view
        .groupBoxStyle(AboutGroupBoxStyle(compact: true))
        .onAppear {
            // Clear the updates cache when About tab appears
            UpdateService.shared.clearCache()
            fetch()
        }
        .animation(.default, value: showBeta)
        .animation(.default, value: status)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var updateButtons: some View {
        if !hasCheckedForUpdates || status == UpdateStates.Updated {
            Button {
                UpdateService.shared.clearCache()
                fetch()
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(isLoading)
            .buttonStyle(.bordered)
        }

        if hasCheckedForUpdates && status == UpdateStates.NewVersion {
            Button {
                forceUpdate()
            } label: {
                Label("Install Update", systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(isLoading)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Update Status

    private var updateStatusText: String {
        switch status {
        case .Failed:
            return "Failed to update, download manually"
        case .NewVersion:
            if !latestVersionFound.isEmpty {
                return "New version found: \(latestVersionFound)"
            }
            return "New version found"
        default:
            return status.rawValue
        }
    }

    private var updateStatusSymbol: String {
        switch status {
        case .Checking:
            return "clock"
        case .NewVersion:
            return "arrow.down.circle.fill"
        case .Installing:
            return "square.and.arrow.down"
        case .Updated:
            return "checkmark.seal.fill"
        case .Failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var updateStatusColor: Color {
        switch status {
        case .Checking:
            return .secondary
        case .NewVersion:
            return .blue
        case .Installing:
            return .accentColor
        case .Updated:
            return .green
        case .Failed:
            return .orange
        }
    }

    // MARK: - Data Fetching

    private func fetch() {
        #if SETAPP_ENABLED
        DispatchQueue.main.async {
            isLoading = false
            status = UpdateStates.Failed
            let alert = NSAlert()
            alert.messageText = "Update is not available in SetApp version"
            alert.informativeText = "Please use SetApp to update the application"
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        return
        #endif

        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                isLoading = true
                status = UpdateStates.Checking
            }

            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
            let currentVersion = Bundle.main.version

            if let release = try? updater.getLatestRelease() {
                DispatchQueue.main.async {
                    hasCheckedForUpdates = true
                    isLoading = false

                    if currentVersion < release.version {
                        status = UpdateStates.NewVersion
                        latestVersionFound = release.tag_name
                    } else {
                        status = UpdateStates.Updated
                        latestVersionFound = ""
                        Defaults[.updateNag] = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    hasCheckedForUpdates = true
                    status = UpdateStates.Failed
                    isLoading = false
                }
            }
        }
    }

    private func forceUpdate() {
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                isLoading = true
                status = UpdateStates.Installing
            }

            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

            if let release = try? updater.getLatestRelease() {
                #if SETAPP_ENABLED
                DispatchQueue.main.async {
                    isLoading = false
                    status = UpdateStates.Failed
                    let alert = NSAlert()
                    alert.messageText = "Force update is not available in SetApp version"
                    alert.informativeText = "Please use SetApp to update the application"
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return
                #endif

                if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                    let done = updater.downloadAndUpdate(withAsset: zipURL)
                    if !done {
                        DispatchQueue.main.async {
                            status = UpdateStates.Failed
                            isLoading = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        status = UpdateStates.Failed
                        isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    status = UpdateStates.Failed
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Custom GroupBox Style

private struct AboutGroupBoxStyle: GroupBoxStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            // Header with tight baseline and no extra bottom padding
            HStack(spacing: 8) {
                configuration.label
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }

            // Content with compact inner padding and a subtle stroke
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                configuration.content
            }
            .padding(compact ? 8 : 10)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary.opacity(0.6), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

