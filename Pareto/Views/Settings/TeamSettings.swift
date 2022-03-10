//
//  TeamSettings.swift
//  TeamSettings
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct TeamSettingsView: View {
    @Default(.teamID) var teamID
    @Default(.machineUUID) var machineUUID
    @Default(.sendHWInfo) var sendHWInfo

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Team ID: \(teamID)\nMachine UUID: \(machineUUID)", forType: .string)
    }

    func help() {
        NSWorkspace.shared.open(URL(string: "https://support.apple.com/en-ie/guide/mac-help/mchlp2322/mac#mchl8c79215b")!)
    }

    var body: some View {
        if !teamID.isEmpty {
            Form {
                Section(
                    footer: Text("Device Name")) {
                        VStack(alignment: .leading) {
                            Text("\(AppInfo.machineName)").contextMenu(ContextMenu(menuItems: {
                                Button("How to change", action: help)
                            }))
                        }
                    }
                Section(
                    footer: Text("Device ID")) {
                        VStack(alignment: .leading) {
                            Text("\(machineUUID)").contextMenu(ContextMenu(menuItems: {
                                Button("Copy", action: copy)
                            }))
                        }
                    }
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
            }.frame(width: 350).padding(25)
        } else {
            Form {
                Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
                Link("Learn more »",
                     destination: URL(string: "https://paretosecurity.com/pricing?utm_source=\(AppInfo.utmSource)&utm_medium=teams-link")!)
            }.frame(width: 350).padding(25)
        }
    }
}

struct TeamSettings_Previews: PreviewProvider {
    static var previews: some View {
        TeamSettingsView()
    }
}
