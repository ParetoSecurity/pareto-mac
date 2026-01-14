//
//  CloudSettings.swift
//  TeamSettings
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct TeamSettingsView: View {
    @StateObject var teamSettings: TeamSettingsUpdater

    @Default(.teamID) var teamID
    @Default(.machineUUID) var machineUUID
    @Default(.sendHWInfo) var sendHWInfo
    @Default(.showBeta) var showBeta
    @Default(.lastTeamReportSuccess) var lastTeamReportSuccess

    @State private var debugLinkURL: String = ""

    // SwiftUI-native alert handling
    @State private var alertData: InlineAlert?

    @Environment(\.openURL) private var openURL

    private struct InlineAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String?
    }

    private func copyIDsToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Team ID: \(teamID)\nMachine UUID: \(machineUUID)", forType: .string)
        alertData = InlineAlert(title: "Copied", message: "Team ID and Machine UUID have been copied to the clipboard.")
    }

    private func copyApps() {
        var logs = [String]()
        logs.append("Name, Bundle, Version")
        for app in PublicApp.all {
            logs.append("\(app.name), \(app.bundle), \(app.version)")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs.joined(separator: "\n"), forType: .string)
        alertData = InlineAlert(title: "Copied", message: "List of installed apps has been copied to the clipboard.")
    }

    private func help() {
        if let url = URL(string: "https://support.apple.com/en-ie/guide/mac-help/mchlp2322/mac#mchl8c79215b") {
            openURL(url)
        }
    }

    private var lastSyncTimeString: String {
        if lastTeamReportSuccess == 0 {
            return "Never"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(lastTeamReportSuccess) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func processDebugLinkURL() {
        let trimmed = debugLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            alertData = InlineAlert(title: "Invalid URL", message: "Please enter a valid paretosecurity:// URL.")
            return
        }

        AppHandlers().processAction(url)
        debugLinkURL = ""
    }

    var body: some View {
        Group {
            if !teamID.isEmpty {
                Form {
                    Section(footer: Text("Device Name").font(.caption)) {
                        Text(AppInfo.machineName)
                            .textSelection(.enabled)
                            .contextMenu {
                                Button("How to change", action: help)
                            }
                    }
                    Section(footer: Text("Device ID").font(.caption)) {
                        Text(machineUUID)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .contextMenu {
                                Button("Copy", action: copyIDsToPasteboard)
                            }
                    }
                    Section(footer: Text("Last Report Sent").font(.caption)) {
                        Text(lastSyncTimeString)
                    }
                    Section(footer: Text("When enabled, send model name and serial number.").font(.footnote)) {
                        if teamSettings.forceSerialPush {
                            Toggle("Send inventory info on update", isOn: $sendHWInfo)
                            Text("Sending is requested by the team policy.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Toggle("Send inventory info on update", isOn: $sendHWInfo)
                        }
                        Button("Copy App list") { copyApps() }
                    }

                    if showBeta {
                        Section(footer: Text("Cloud API Endpoint").font(.caption)) {
                            Text(Defaults[.teamAPI])
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(Defaults[.teamAPI], forType: .string)
                                        alertData = InlineAlert(title: "Copied", message: "Cloud API Endpoint copied to the clipboard.")
                                    }
                                }
                        }
                    }

                    Section {
                        HStack {
                            Button("Unlink this device") { Defaults.toOpenSource() }
                            Spacer()
                            Link("Cloud Dashboard »", destination: AppInfo.teamsURL())
                        }
                    }
                }
                .padding(20)
                .task {
                    // Refresh team settings when the view appears
                    teamSettings.update {}
                }
            } else {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pareto Cloud provides a web dashboard for an overview of your company's devices. [Learn more »](https://paretosecurity.com/product/device-monitoring)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                        }
                    }
                    if showBeta {
                        Section {
                            // Use inline placeholder to avoid wide left-side form label
                            TextField("Debug URL", text: $debugLinkURL, prompt: Text("paretosecurity://linkDevice/?invite_id=..."))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit { processDebugLinkURL() }

                            HStack {
                                Button("Process URL", action: processDebugLinkURL)
                                    .keyboardShortcut(.defaultAction)
                                    .disabled(debugLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Spacer()
                            }
                        } footer: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEBUG: Enter a paretosecurity:// URL to trigger device linking").font(.footnote)
                                Text("Host parameter options:").font(.footnote).fontWeight(.medium)
                                Text("• Default (cloud): paretosecurity://linkDevice/?invite_id=123").font(.footnote)
                                Text("• Complete URL: paretosecurity://linkDevice/?invite_id=123&host=https://api.example.com").font(.footnote)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .alert(item: $alertData) { data in
            Alert(title: Text(data.title), message: data.message.map(Text.init), dismissButton: .default(Text("OK")))
        }
    }
}
