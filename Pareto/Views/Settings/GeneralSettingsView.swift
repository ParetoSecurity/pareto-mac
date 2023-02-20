//
//  GeneralSettingsView.swift
//  GeneralSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import LaunchAtLogin
import os.log
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable

    @Default(.betaChannel) var betaChannel
    @Default(.showBeta) var showBeta
    @Default(.showNotifications) var showNotifications
    @Default(.checkForUpdatesRecentOnly) var checkForUpdatesRecentOnly
    @Default(.disableChecksEvents) var disableChecksEvents
    @Default(.myChecks) var myChecks
    @Default(.myChecksURL) var myChecksURL
    @Default(.sendCrashReports) var sendCrashReports
    @Default(.hideWhenNoFailures) var hideWhenNoFailures

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

    var body: some View {
        VStack {
            Text("General").fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 5)
            Form {
                Section(
                    footer: Text("To enable continuous monitoring and reporting.").font(.footnote)) {
                        VStack(alignment: .leading) {
                            Toggle("Automatically launch on system startup", isOn: $atLogin.isEnabled)
                        }
                    }
                Section(
                    footer: Text("Only scan for updates for recently used apps.").font(.footnote)) {
                        VStack(alignment: .leading) {
                            Toggle("Update check only for apps used in the last week", isOn: $checkForUpdatesRecentOnly)
                        }
                    }
                Section(
                    footer: Text("App is running checks even when the icon is hidden. To show the menubar icon, lunch the app again.").font(.footnote)) {
                        VStack(alignment: .leading) {
                            Toggle("Only show in menu bar when the checks are failing", isOn: $hideWhenNoFailures)
                        }
                    }
                Section(
                    footer: Text("Enables custom checks, that are configured by YAML rules. [Learn more](https://paretosecurity.com/custom-check/)").font(.footnote)) {
                        VStack(alignment: .leading) {
                            HStack {
                                Toggle("Enable My Checks", isOn: $myChecks)
                                Button("Select folder") {
                                    selectFolder()
                                }.disabled(!myChecks)
                            }
                        }
                    }
                if showBeta {
                    Section(
                        footer: Text("When priority check fails show notification.").font(.footnote)) {
                            VStack(alignment: .leading) {
                                Toggle("Show priority check failures as notifications", isOn: $showNotifications).onChange(of: showNotifications) { isEnabled in
                                    if isEnabled {
                                        registerNotifications()
                                    }
                                }
                            }
                        }
                    Section(
                        footer: Text("Skip all processing after wakeup, network changes.").font(.footnote)) {
                            VStack(alignment: .leading) {
                                Toggle("Skip running checks on events", isOn: $disableChecksEvents)
                            }
                        }

                    Section(
                        footer: Text("Latest features but potentially bugs to report.").font(.footnote)) {
                            VStack(alignment: .leading) {
                                Toggle("Update app to pre-release builds", isOn: $betaChannel)
                            }
                        }
                    Section(
                        footer: Text("Helps us to spot issues with the app.").font(.footnote)) {
                            VStack(alignment: .leading) {
                                Toggle("Send crash reports", isOn: $sendCrashReports)
                            }
                        }
                    #if DEBUG
                        HStack {
                            Button("Reset Settings") {
                                NSApp.sendAction(#selector(AppDelegate.resetSettingsClick), to: nil, from: nil)
                            }
                            Button("Show Welcome") {
                                NSApp.sendAction(#selector(AppDelegate.showWelcome), to: nil, from: nil)
                            }
                            Button("Notify") {
                                registerNotifications()
                                showNotification(check: OpenWiFiCheck.sharedInstance)
                            }
                        }
                    #endif
                }
            }
            Text("Permissions").fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
            HStack {
                VStack(alignment: .leading) {
                    Text("System Events Access").font(.title2)
                    Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. [Learn more](https://help.paretosecurity.com/article/312-app-permissions)").font(.footnote)
                }

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
                }).disabled(checker.osaAuthorized)

            }.frame(width: 350, alignment: .leading)
            HStack {
                VStack(alignment: .leading) {
                    Text("Full Disk Access").font(.title2)
                    Text("App requires full disk access if you want to use the Time Machine checks. [Learn more](https://help.paretosecurity.com/article/312-app-permissions)").font(.footnote)
                }
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
                }).disabled(checker.fdaAuthorized)

            }.frame(width: 350, alignment: .leading)
        }.frame(width: 350).padding(25).onAppear {
            checker.start()
        }.onDisappear {
            checker.stop()
        }
    }

    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a folder to watch for custom checks"
        openPanel.message = "Location of the customs checks you wish to run"
        openPanel.showsResizeIndicator = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { result in
            if result == .OK {
                let path = openPanel.url
                os_log("selected folder is %{public}s", path!.absoluteString)
                myChecksURL = path
                Claims.global.refresh()
            }
        }
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
