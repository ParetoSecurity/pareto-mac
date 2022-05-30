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

    func copyMail() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(teamSettings.admin, forType: .string)
    }

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Team ID: \(teamID)\nMachine UUID: \(machineUUID)", forType: .string)
    }

    func help() {
        NSWorkspace.shared.open(URL(string: "https://support.apple.com/en-ie/guide/mac-help/mchlp2322/mac#mchl8c79215b")!)
    }

    var body: some View {
        if !teamID.isEmpty {
            VStack(alignment: .leading) {
                Section(
                    footer: Text("Team Name").font(.caption)) {
                        VStack(alignment: .leading) {
                            Text("\(teamSettings.name)")
                        }
                    }
                Spacer(minLength: 1)
                Section(
                    footer: Text("Team Admin").font(.caption)) {
                        VStack(alignment: .leading) {
                            Link(teamSettings.admin, destination: URL(string: "mailto:\(teamSettings.admin)")!).contextMenu(ContextMenu(menuItems: {
                                Button("Copy", action: copyMail)
                            }))
                        }
                    }
                Spacer(minLength: 1)
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
                            Toggle("Send inventory info on update", isOn: $sendHWInfo)
                        }
                    }

                HStack {
                    Button("Unlink this device") {
                        Defaults.toFree()
                    }
                    Link("Team Dashboard »",
                         destination: AppInfo.teamsURL())
                }
            }.frame(minWidth: 350, minHeight: 150).padding(25).onAppear {
                DispatchQueue.main.async {
                    teamSettings.update {}
                }
            }
        } else {
            Form {
                Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
                Link("Learn more »",
                     destination: URL(string: "https://paretosecurity.com/pricing?utm_source=\(AppInfo.utmSource)&utm_medium=teams-link")!)
            }.frame(width: 350).padding(25)
        }
    }
}
