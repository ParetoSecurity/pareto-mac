//
//  PermissionsSettingsView.swift
//  GeneralSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import LaunchAtLogin
import os.log
import SwiftUI

struct PermissionsSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable

    @Default(.showBeta) var betaChannel
    @Default(.showBeta) var showBeta
    @Default(.checkForUpdatesRecentOnly) var checkForUpdatesRecentOnly
    @Default(.disableChecksEvents) var disableChecksEvents
    @Default(.myChecks) var myChecks
    @Default(.myChecksURL) var myChecksURL
    @Default(.hideWhenNoFailures) var hideWhenNoFailures
    @StateObject private var helperToolManager = HelperToolManager()
    @ObservedObject fileprivate var checker = PermissionsChecker()

    func authorizeOSAClick() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func authorizeFDAClick() {
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDisk")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func authorizeFWClick() async {
        if checker.firewallAuthorized {
            await helperToolManager.manageHelperTool(action: .uninstall)
            return
        }
        await helperToolManager.manageHelperTool(action: .install)
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Firewall Access").font(.headline)
                    Text("App requires read-only access to firewall to perform checks. [Learn more](https://paretosecurity.com/docs/mac/privileged-helper-authorization)").font(.footnote).padding([.top], 1)
                }
                Spacer()
                Button(action: { Task { await authorizeFWClick() } }, label: {
                    if checker.ran {
                        if checker.firewallAuthorized {
                            Text("Remove").frame(width: 70)
                        } else {
                            Text("Authorize").frame(width: 70)
                        }
                    } else {
                        Text("Verifying").frame(width: 70)
                    }
                }).disabled(!checker.ran)

            }.frame(width: 380, alignment: .leading)
            HStack {
                VStack(alignment: .leading) {
                    Text("System Events Access").font(.headline)
                    Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote).padding([.top], 1)
                }
                Spacer()
                Button(action: authorizeOSAClick, label: {
                    if checker.ran {
                        if checker.osaAuthorized {
                            Text("Authorized").frame(width: 70)
                        } else {
                            Text("Authorize").frame(width: 70)
                        }
                    } else {
                        Text("Verifying").frame(width: 70)
                    }
                }).disabled(checker.osaAuthorized || !checker.ran)

            }.frame(width: 380, alignment: .leading)
            HStack {
                VStack(alignment: .leading) {
                    Text("Full Disk Access").font(.headline)
                    Text("App requires full disk access if you want to use the Time Machine checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote).padding([.top], 1)
                }
                Spacer()
                Button(action: authorizeFDAClick, label: {
                    if checker.ran {
                        if checker.fdaAuthorized {
                            Text("Authorized").frame(width: 70)
                        } else {
                            Text("Authorize").frame(width: 70)
                        }
                    } else {
                        Text("Verifying").frame(width: 70)
                    }
                }).disabled(checker.fdaAuthorized || !checker.ran)

            }.frame(width: 380, alignment: .leading)
        }.frame(maxWidth: 380, minHeight: 120).padding(25).onAppear {
            checker.start()
        }.onDisappear {
            checker.stop()
        }
    }
}

struct PermissionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSettingsView()
    }
}
