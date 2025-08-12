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
            VStack(alignment: .leading) {
                Section(
                    footer: Text("Device Name").font(.caption)) {
                    VStack(alignment: .leading) {
                        Text("\(AppInfo.machineName)").contextMenu(ContextMenu(menuItems: {
                            Button("How to change", action: help)
                        }))
                    }
                }
                Spacer(minLength: 1)
                Section(
                    footer: Text("Device ID").font(.caption)) {
                    VStack(alignment: .leading) {
                        Text("\(machineUUID)").contextMenu(ContextMenu(menuItems: {
                            Button("Copy", action: copy)
                        }))
                    }
                }
                Spacer(minLength: 2)

                Section(
                    footer: Text("When enabled, send model name and serial number.").font(.footnote)) {
                    VStack(alignment: .leading) {
                        if teamSettings.forceSerialPush {
                            Toggle("Send inventory info on update", isOn: $sendHWInfo)
                            Text("Sending is requested by the team policy.").font(.footnote)
                        } else {
                            Toggle("Send inventory info on update", isOn: $sendHWInfo)
                        }
                        HStack {
                            Button("Copy App list") {
                                copyApps()
                            }
                        }
                    }
                }

                if showBeta {
                    Spacer(minLength: 2)
                    Section(
                        footer: Text("Team API Endpoint").font(.caption)) {
                        VStack(alignment: .leading) {
                            Text("\(Defaults[.teamAPI])").contextMenu(ContextMenu(menuItems: {
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(Defaults[.teamAPI], forType: .string)
                                }
                            }))
                        }
                    }
                }

                HStack {
                    Button("Unlink this device") {
                        Defaults.toOpenSource()
                    }
                    Link("Cloud Dashboard »",
                         destination: AppInfo.teamsURL())
                }
                Spacer(minLength: 2)
            }.frame(width: 380, height: 180).padding(25).onAppear {
                DispatchQueue.main.async {
                    teamSettings.update {}
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("The Teams subscription will give you a web dashboard for an overview of the company's devices. [Learn more »](https://paretosecurity.com/product/device-monitoring)")

                if showBeta {
                    Section(
                        footer: VStack(alignment: .leading, spacing: 4) {
                            Text("DEBUG: Enter a paretosecurity:// URL to trigger device linking").font(.footnote)
                            Text("Host parameter options:").font(.footnote).fontWeight(.medium)
                            Text("• Default (cloud): paretosecurity://linkDevice/?invite_id=123").font(.footnote)
                            Text("• Complete URL: paretosecurity://linkDevice/?invite_id=123&host=https://api.example.com").font(.footnote)
                        }) {
                            VStack(alignment: .leading) {
                                TextField("paretosecurity://linkDevice/?invite_id=...", text: $debugLinkURL)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                HStack {
                                    Button("Process URL") {
                                        processDebugLinkURL()
                                    }
                                    .disabled(debugLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    Spacer()
                                }
                            }
                        }
                }
            }.frame(width: 380).padding(25)
        }
    }
}
