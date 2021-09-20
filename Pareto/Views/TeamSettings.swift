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
    @Default(.deviceID) var deviceID
    @Default(.machineUUID) var machineUUID

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Team ID: \(teamID)\nDevice ID: \(deviceID)\nMachine UUID: \(machineUUID)", forType: .string)
    }

    var body: some View {
        VStack {
            if !teamID.isEmpty {
                Text("\(teamID)").contextMenu(ContextMenu(menuItems: {
                    Button("Copy", action: copy)
                }))
                Text("\(deviceID)").contextMenu(ContextMenu(menuItems: {
                    Button("Copy", action: copy)
                }))
                Text("\(machineUUID)").contextMenu(ContextMenu(menuItems: {
                    Button("Copy", action: copy)
                }))
                Button("Unlink this device from the Teams account") {
                    _ = try? Team.unlink(withDevice: ReportingDevice.current())
                    Defaults.toFree()
                }
            } else {
                Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
                Link("Learn more »",
                     destination: URL(string: "https://paretosecurity.app/pricing?utm_source=app&utm_medium=teams-link")!)
            }
        }.frame(width: 350, height: 100).padding(5)
    }
}

struct TeamSettings_Previews: PreviewProvider {
    static var previews: some View {
        TeamSettingsView()
    }
}
