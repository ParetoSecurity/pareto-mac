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
                    Section {
                        LabeledContent("Device Name") {
                            Text(AppInfo.machineName)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("How to change", action: help)
                                }
                        }
                        LabeledContent("Device ID") {
                            Text(machineUUID)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy", action: copyIDsToPasteboard)
                                }
                        }
                        LabeledContent("Last Report") {
                            Text(lastSyncTimeString)
                                .foregroundStyle(.secondary)
                        }
                        Button("Copy App List") { copyApps() }
                    } header: {
                        Text("Device")
                    }

                    Section {
                        Toggle("Send inventory info", isOn: $sendHWInfo)
                        if teamSettings.forceSerialPush {
                            Text("Required by team policy")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Inventory")
                    } footer: {
                        Text("When enabled, model name and serial number are included in reports.")
                    }

                    if showBeta {
                        Section {
                            LabeledContent("API Endpoint") {
                                Text(Defaults[.teamAPI])
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .contextMenu {
                                        Button("Copy") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(Defaults[.teamAPI], forType: .string)
                                            alertData = InlineAlert(title: "Copied", message: "Cloud API Endpoint copied to the clipboard.")
                                        }
                                    }
                            }
                        } header: {
                            Text("Advanced")
                        }
                    }

                    Section {
                        HStack {
                            Button("Unlink Device") { Defaults.toOpenSource() }
                            Spacer()
                            Link("Open Dashboard", destination: AppInfo.teamsURL())
                        }
                    }
                }
                .formStyle(.grouped)
                .task {
                    // Refresh team settings when the view appears
                    teamSettings.update {}
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "cloud")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        Text("Connect to Pareto Cloud")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Get a web dashboard for an overview of your company's devices and centralized security monitoring.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    Link(destination: URL(string: "https://paretosecurity.com/product/device-monitoring")!) {
                        Text("Learn More")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    if showBeta {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("Debug URL", text: $debugLinkURL, prompt: Text("paretosecurity://linkDevice/?invite_id=..."))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit { processDebugLinkURL() }
                                Button("Process", action: processDebugLinkURL)
                                    .disabled(debugLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert(item: $alertData) { data in
            Alert(title: Text(data.title), message: data.message.map(Text.init), dismissButton: .default(Text("OK")))
        }
        .frame(minHeight: 450)
    }
}
