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

    var body: some View {
        Form {
            Section(
                footer: Text("Automatically opens the app when you start your Mac.")) {
                    VStack(alignment: .leading) {
                        Toggle("Start at Login", isOn: $atLogin.isEnabled)
                    }
                }

            if showBeta {
                Section(
                    footer: Text("Latest features but potentially bugs to report.")) {
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
                        Button("Update Flags") {
                            AppInfo.Flags.update()
                        }
                    }
                #endif
            }
        }

        .frame(width: 350, height: 100).padding(5)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
