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
            }
        }

        .frame(width: 350, height: 100).padding(5)
    }
}

struct ChecksSettingsView: View {
    @State var updater: Bool = false
    var body: some View {
        VStack(alignment: .leading) {
            Text("Deselect the checks you don't want the app to run.")

            Form {
                ForEach(AppInfo.claims.sorted(by: { $0.title < $1.title }), id: \.self) { claim in
                    // Hack to force update view
                    // see https://developer.apple.com/forums/thread/131577
                    if updater {
                        Text(claim.title).fontWeight(.bold).font(.system(size: 15)).padding(.top)
                    } else {
                        Text(claim.title).fontWeight(.bold).font(.system(size: 15)).padding(.top)
                    }
                    ForEach(claim.checks.sorted(by: { $0.Title < $1.Title }), id: \.self) { check in
                        Toggle(check.Title, isOn: Binding<Bool>(
                            get: { check.isActive },
                            set: {
                                check.isActive = $0
                                updater.toggle()
                            }
                        ))
                    }
                }
            }
        }
        .frame(width: 350, height: 450).padding(5)
    }
}

struct AboutSettingsView: View {
    @State private var isLoading = false
    @State private var status = UpdateStates.Checking
    @State private var konami = 0
    @Default(.showBeta) var showBeta

    enum UpdateStates: String {
        case Checking = "Checking for updates"
        case NewVersion = "New version found"
        case Installing = "Installing new update"
        case Updated = "App is up to date"
        case Failed = "Failed to update, download manualy"
    }

    var body: some View {
        HStack {
            Image("Logo").resizable()
                .aspectRatio(contentMode: .fit).onTapGesture {
                    if !showBeta {
                        konami += 1
                        if konami >= 7 {
                            showBeta = true
                            konami = 0
                            let alert = NSAlert()
                            alert.messageText = "You are now part of a secret society seeing somewhat mysterious things."
                            alert.alertStyle = NSAlert.Style.informational
                            alert.addButton(withTitle: "Let me in")
                            alert.runModal()
                        }
                    } else {
                        konami += 1
                        if konami >= 3 {
                            showBeta = false
                            konami = 0
                        }
                    }
                }
            VStack(alignment: .leading) {
                Link("Pareto Security",
                     destination: URL(string: "https://paretosecurity.app")!)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Version: \(AppInfo.appVersion) - \(AppInfo.buildVersion)")
                    HStack {
                        Text(status.rawValue)
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
        DispatchQueue.global(qos: .userInitiated).async {
            isLoading = true
            status = UpdateStates.Checking
            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
            let currentVersion = Bundle.main.version
            if let release = try? updater.getLatestRelease() {
                isLoading = false
                if currentVersion < release.version {
                    status = UpdateStates.NewVersion
                    if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                        status = UpdateStates.Installing
                        isLoading = true

                        let done = updater.downloadAndUpdate(withAsset: zipURL)
                        if !done {
                            status = UpdateStates.Failed
                            isLoading = false
                        }

                    } else {
                        status = UpdateStates.Updated
                        isLoading = false
                    }
                } else {
                    status = UpdateStates.Updated
                    isLoading = false
                }
            } else {
                status = UpdateStates.Updated
                isLoading = false
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
        }.frame(width: 350, height: 100).padding(5)
    }
}

struct SettingsView: View {
    @Default(.showBeta) var showBeta

    private enum Tabs: Hashable {
        case general, about, team, checks
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
            if showBeta {
                ChecksSettingsView()
                    .tabItem {
                        Label("Checks", systemImage: "pencil")
                    }
                    .tag(Tabs.checks)
            }
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }
        .padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView()
        }
    }
}
