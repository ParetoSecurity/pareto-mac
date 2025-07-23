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
            Group {
                Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices. [Learn more »](https://paretosecurity.com/product/device-monitoring)")
            }.frame(width: 380).padding(25)
        }
    }
}
