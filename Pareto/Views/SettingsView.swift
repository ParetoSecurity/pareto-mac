//
//  SettingsView.swift
//  Pareto
//
//  Created by Janez Troha on 14/07/2021.
//
import AppKit
import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable
    @ObservedObject var userSettings = UserSettings()

    var body: some View {
        Form {
            Section(
                footer: Text("Automatically opens the app when you start your Mac.")) {
                    VStack(alignment: .leading) {
                        Toggle("Start at Login", isOn: $atLogin.isEnabled)
                    }
            }
            Section(
                footer: Text("Run all checks some time after waking from sleep.")) {
                    VStack(alignment: .leading) {
                        Toggle("Run checks after sleep", isOn: $userSettings.runAfterSleep)
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
                .aspectRatio(contentMode: .fit).padding(5)
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

                Text("Made with ❤️ at Niteo.co")
            }

        }.frame(width: 350, height: 100).padding(5)
    }
}

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, about
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
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
