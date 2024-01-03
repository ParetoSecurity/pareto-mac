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
    @Default(.alternativeColor) var alternativeColor
    @ObservedObject fileprivate var checker = PermissionsChecker()

    var body: some View {
        VStack {

            
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
                    footer: Text("To show the menu bar icon, launch the app again.").font(.footnote) ){
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
                Section(
                    footer: Text("Improve default colors for accessibility.").font(.footnote) ){
                        VStack(alignment: .leading) {
                            Toggle("Use alternative color scheme", isOn: $alternativeColor)
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
        }.frame(maxWidth: 380, minHeight: 210).padding(25)
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
