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
    @State private var isLoading = false
    @State private var fetched = false
    @State private var status = "Checking for updates"

    var body: some View {
        HStack {
            Image("Logo").resizable()
                .aspectRatio(contentMode: .fit)
            VStack(alignment: .leading) {
                Link("Pareto Security",
                     destination: URL(string: "https://paretosecurity.app")!)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Version: \(AppInfo.appVersion) - \(AppInfo.buildVersion)")
                    HStack {
                        Text(status)
                        if self.isLoading {
                            SemiCircleSpin().frame(width: 15, height: 15, alignment: .center)
                        } else {
                            SemiCircleSpin().frame(width: 15, height: 15, alignment: .center).hidden()
                        }
                    }
                }

                HStack(spacing: 0) {
                    Text("We’d love to ")
                    Link("hear from you!",
                         destination: URL(string: "https://paretosecurity.app/contact")!)
                }

                Text("Made with ❤️ at Niteo")
            }

        }.frame(width: 350, height: 100).padding(5).onAppear(perform: fetch)
    }

    private func fetch() {
        if fetched {
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            isLoading = true
            status = "Checking for update"
            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
            let currentVersion = Bundle.main.version
            if let release = try? updater.getLatestRelease() {
                fetched = true
                isLoading = false
                if currentVersion < release.version {
                    status = "New version found"
                    if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                        status = "Installing new update"
                        isLoading = true

                        let done = updater.downloadAndUpdate(withAsset: zipURL)
                        if !done {
                            status = "Failed to update, download manualy"
                            isLoading = false
                        }

                    } else {
                        status = "App is up to date"
                        isLoading = false
                    }
                } else {
                    status = "App is up to date"
                    isLoading = false
                }
            }
        }
    }
}

struct TeamSettingsView: View {
    @Default(.teamID) var teamID
    @Default(.userID) var userID

    var body: some View {
        VStack {
            Text("The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
            Link("Learn more »",
                 destination: URL(string: "https://paretosecurity.app/pricing?utm_source=app&utm_medium=teams-link")!)
        }.frame(width: 310, height: 100).padding(5)
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
                    Label("Teams", systemImage: "person.3.fill")
                }
                .tag(Tabs.team)
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
