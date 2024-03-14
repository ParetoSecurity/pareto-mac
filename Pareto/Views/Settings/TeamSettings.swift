//
//  TeamSettings.swift
//  TeamSettings
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct PublicApp: Codable {
    let name: String
    let bundle: String
    let version: String

    static var all: [PublicApp] {
        var detectedApps: [PublicApp] = []
        let allApps = try! FileManager.default.contentsOfDirectory(at: URL(string: "/Applications")!, includingPropertiesForKeys: [.isApplicationKey])
        for app in allApps {
            let plist = PublicApp.readPlistFile(fileURL: app.appendingPathComponent("Contents/Info.plist"))
            if let appName = plist?["CFBundleName"] as? String,
               let appBundle = plist?["CFBundleIdentifier"] as? String {
                let bundleApp = PublicApp(
                    name: appName,
                    bundle: appBundle,
                    version: plist?["CFBundleShortVersionString"] as? String ?? "Unknown"
                )
                detectedApps.append(bundleApp)
            }
        }

        // user apps
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let localPath = URL(fileURLWithPath: "\(homeDirURL.path)/Applications/")
        if (try? localPath.checkResourceIsReachable()) ?? false {
            let userApps = try! FileManager.default.contentsOfDirectory(at: localPath, includingPropertiesForKeys: [.isApplicationKey])
            for app in userApps {
                let plist = PublicApp.readPlistFile(fileURL: app.appendingPathComponent("Contents/Info.plist"))
                if let appName = plist?["CFBundleName"] as? String,
                   let appBundle = plist?["CFBundleIdentifier"] as? String {
                    let bundleApp = PublicApp(
                        name: appName,
                        bundle: appBundle,
                        version: plist?["CFBundleShortVersionString"] as? String ?? "Unknown"
                    )
                    detectedApps.append(bundleApp)
                }
            }
        }

        return detectedApps
    }

    static func readPlistFile(fileURL: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        guard let result = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return result
    }

    static func asJSON() -> String? {
        var export: [PublicApp] = []

        for app in PublicApp.all.sorted(by: { lha, rha in
            lha.name.lowercased() < rha.name.lowercased()
        }) {
            export.append(app)
        }

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let jsonData = try! jsonEncoder.encode(export)
        guard let json = String(data: jsonData, encoding: String.Encoding.utf8) else { return nil }

        return json
    }
}

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
                        Defaults.toFree()
                    }
                    Link("Team Dashboard »",
                         destination: AppInfo.teamsURL())
                }
                Spacer(minLength: 2)
            }.frame(width: 380, height: 290).padding(25).onAppear {
                DispatchQueue.main.async {
                    teamSettings.update {}
                }
            }
        } else {
            Form {
                Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
                Link("Learn more »",
                     destination: URL(string: "https://paretosecurity.com/pricing?utm_source=\(AppInfo.utmSource)&utm_medium=teams-link")!)
            }.frame(width: 380).padding(25)
        }
    }
}
