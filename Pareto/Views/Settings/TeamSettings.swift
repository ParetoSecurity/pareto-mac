//
//  TeamSettings.swift
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

    @State private var debugLinkURL: String = ""

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Team ID: \(teamID)\nMachine UUID: \(machineUUID)", forType: .string)
    }

    func copyApps() {
        var logs = [String]()
        logs.append("Name, Bundle, Version")
        for app in PublicApp.all {
            logs.append("\(app.name), \(app.bundle), \(app.version)")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs.joined(separator: "\n"), forType: .string)
        let alert = NSAlert()
        alert.messageText = "List of installed apps has been copied to the clipboard."
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func help() {
        NSWorkspace.shared.open(URL(string: "https://support.apple.com/en-ie/guide/mac-help/mchlp2322/mac#mchl8c79215b")!)
    }

    func processDebugLinkURL() {
        guard let url = URL(string: debugLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            let alert = NSAlert()
            alert.messageText = "Invalid URL"
            alert.informativeText = "Please enter a valid paretosecurity:// URL"
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        AppHandlers().processAction(url)
        debugLinkURL = ""
    }

    var body: some View {
        if !teamID.isEmpty {
            Form {
                Section(footer: Text("Device Name").font(.caption)) {
                    Text("\(AppInfo.machineName)")
                        .contextMenu(ContextMenu(menuItems: { Button("How to change", action: help) }))
                }
                Section(footer: Text("Device ID").font(.caption)) {
                    Text("\(machineUUID)")
                        .contextMenu(ContextMenu(menuItems: { Button("Copy", action: copy) }))
                }
                Section(footer: Text("When enabled, send model name and serial number.").font(.footnote)) {
                    if teamSettings.forceSerialPush {
                        Toggle("Send inventory info on update", isOn: $sendHWInfo)
                        Text("Sending is requested by the team policy.").font(.footnote)
                    } else {
                        Toggle("Send inventory info on update", isOn: $sendHWInfo)
                    }
                    Button("Copy App list") { copyApps() }
                }

                if showBeta {
                    Section(footer: Text("Cloud API Endpoint").font(.caption)) {
                        Text("\(Defaults[.teamAPI])")
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(Defaults[.teamAPI], forType: .string)
                                }
                            }))
                    }
                }

                Section {
                    HStack {
                        Button("Unlink this device") { Defaults.toOpenSource() }
                        Link("Cloud Dashboard »", destination: AppInfo.teamsURL())
                    }
                }
            }
            .padding(20)
            .onAppear { DispatchQueue.main.async { teamSettings.update {} } }
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
                        HStack {
                            Button("Process URL") { processDebugLinkURL() }
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
            }            .padding(20)
        }
    }
}
