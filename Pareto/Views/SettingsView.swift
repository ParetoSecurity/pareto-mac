//
//  SettingsView.swift
//  Pareto
//
//  Created by Janez Troha on 14/07/2021.
//
import AppKit
import Defaults
import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable
    @Default(.betaChannel) var betaChannel

    var body: some View {
        Form {
            Section(
                footer: Text("Automatically opens the app when you start your Mac.")) {
                    VStack(alignment: .leading) {
                        Toggle("Start at Login", isOn: $atLogin.isEnabled)
                    }
            }
            Section(
                footer: Text("Latest features but potentially bugs to report.")) {
                    VStack(alignment: .leading) {
                        Toggle("Update app to pre-release builds", isOn: $betaChannel)
                    }
            }
        }

        .frame(width: 350, height: 100).padding(5)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        HStack {
            Image("Logo").resizable()
                .aspectRatio(contentMode: .fit)
            VStack(alignment: .leading) {
                Link("Pareto Security",
                     destination: URL(string: "https://paretosecurity.app")!)
                Text("Version: \(AppInfo.appVersion)")
                Text("Build: \(AppInfo.buildVersion)")
                HStack(spacing: 0) {
                    Text("We’d love to ")
                    Link("hear from you!",
                         destination: URL(string: "https://paretosecurity.app/contact")!)
                }

                Text("Made with ❤️ at Niteo")
            }

        }.frame(width: 350, height: 100).padding(5)
    }
}

struct TeamSettingsView: View {
    @Default(.teamID) var teamID
    @Default(.userID) var userID

    var body: some View {
        Text("Coming soon!")
    }
}

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, about, team, updater
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            TeamSettingsView()
                .tabItem {
                    Label("Team", systemImage: "person.3.fill")
                }
                .tag(Tabs.team)
                .disabled(true)
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }
        .padding(20)
        .frame(width: 375, height: 150)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView()
        }
    }
}
