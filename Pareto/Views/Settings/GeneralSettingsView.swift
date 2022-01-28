//
//  GeneralSettingsView.swift
//  GeneralSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable
    @Default(.betaChannel) var betaChannel
    @Default(.showBeta) var showBeta
    @Default(.showNotifications) var showNotifications
    @Default(.checkForUpdatesRecentOnly) var checkForUpdatesRecentOnly
    var body: some View {
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
            if showBeta {
                Section(
                    footer: Text("When priority check fails show notification.").font(.footnote)) {
                        VStack(alignment: .leading) {
                            Toggle("Show priority check failures as notifications", isOn: $showNotifications)
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
        #if DEBUG
            .frame(width: 350, height: 180).padding(25)
        #else
            .frame(width: 350, height: 130).padding(25)
        #endif
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
