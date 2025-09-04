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

    @Default(.showBeta) var showBeta
    @Default(.checkForUpdatesRecentOnly) var checkForUpdatesRecentOnly
    @Default(.disableChecksEvents) var disableChecksEvents
    @Default(.myChecks) var myChecks
    @Default(.myChecksURL) var myChecksURL
    @Default(.hideWhenNoFailures) var hideWhenNoFailures
    @Default(.alternativeColor) var alternativeColor
    @ObservedObject fileprivate var checker = PermissionsChecker()

    var body: some View {
        Form {
            Section(
                footer: Text("To enable continuous monitoring and reporting.").font(.footnote))
            {
                VStack(alignment: .leading) {
                    Toggle("Automatically launch on system startup", isOn: $atLogin.isEnabled)
                }
            }
            Section(
                footer: Text("Only scan for updates for recently used apps.").font(.footnote))
            {
                VStack(alignment: .leading) {
                    Toggle("Update check only for apps used in the last week", isOn: $checkForUpdatesRecentOnly)
                }
            }
            Section(
                footer: Text("To show the menu bar icon, launch the app again.").font(.footnote))
            {
                VStack(alignment: .leading) {
                    Toggle("Only show in menu bar when the checks are failing", isOn: $hideWhenNoFailures)
                }
            }
            Section(
                footer: Text("Improve default colors for accessibility.").font(.footnote))
            {
                VStack(alignment: .leading) {
                    Toggle("Use alternative color scheme", isOn: $alternativeColor)
                }
            }
            if showBeta {
                Section(
                    footer: Text("Skip all processing after wakeup, network changes.").font(.footnote))
                {
                    VStack(alignment: .leading) {
                        Toggle("Skip running checks on events", isOn: $disableChecksEvents)
                    }
                }

                Section(
                    footer: Text("Latest features but potentially bugs to report.").font(.footnote))
                {
                    VStack(alignment: .leading) {
                        Toggle("Update app to pre-release builds", isOn: .constant(showBeta))
                            .disabled(showBeta)
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
                    }
                #endif
            }
        }
        .centered()
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
