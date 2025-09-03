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
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Firewall Access").font(.headline)
                    Text("App requires read-only access to firewall to perform checks. [Learn more](https://paretosecurity.com/docs/mac/privileged-helper-authorization)").font(.footnote)
                    HStack {
                        Button(action: { Task { await authorizeFWClick() } }, label: {
                            if checker.ran {
                                if checker.firewallAuthorized {
                                    Text("Remove")
                                } else {
                                    Text("Authorize")
                                }
                            } else {
                                Text("Verifying")
                            }
                        })
                        .disabled(!checker.ran)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("System Events Access").font(.headline)
                    Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote)
                    HStack {
                        Button(action: authorizeOSAClick, label: {
                            if checker.ran {
                                if checker.osaAuthorized {
                                    Text("Authorized")
                                } else {
                                    Text("Authorize")
                                }
                            } else {
                                Text("Verifying")
                            }
                        })
                        .disabled(checker.osaAuthorized || !checker.ran)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Full Disk Access").font(.headline)
                    Text("App requires full disk access if you want to use the Time Machine checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote)
                    HStack {
                        Button(action: authorizeFDAClick, label: {
                            if checker.ran {
                                if checker.fdaAuthorized {
                                    Text("Authorized")
                                } else {
                                    Text("Authorize")
                                }
                            } else {
                                Text("Verifying")
                            }
                        })
                        .disabled(checker.fdaAuthorized || !checker.ran)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
        .onAppear { checker.start() }
        .onDisappear { checker.stop() }
    }
}

struct PermissionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSettingsView()
    }
}
