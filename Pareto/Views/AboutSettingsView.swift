//
//  AboutSettingsView.swift
//  AboutSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

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
                        if konami == 3 {
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
                     destination: URL(string: "https://paretosecurity.com")!).font(.title)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Version: \(AppInfo.appVersion) - \(AppInfo.buildVersion)")
                    #if !SETAPP_ENABLED
                        HStack(spacing: 10) {
                            if status == UpdateStates.Failed {
                                HStack(spacing: 0) {
                                    Text("Failed to update ")
                                    Link("download manualy",
                                         destination: URL(string: "https://github.com/ParetoSecurity/pareto-mac/releases/latest/download/ParetoSecurity.dmg")!)
                                }
                            } else {
                                Text(status.rawValue)
                            }

                            if self.isLoading {
                                ProgressView().frame(width: 5.0, height: 5.0)
                                    .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                            }
                        }
                    #endif
                }

                HStack(spacing: 0) {
                    Text("We’d love to ")
                    Link("hear from you!",
                         destination: URL(string: "https://paretosecurity.com/contact")!)
                }

                HStack(spacing: 0) {
                    Text("Made with ❤️ at ")
                    Link("Niteo",
                         destination: URL(string: "https://paretosecurity.com/about")!)
                }
            }

        }.frame(width: 350, height: 100).padding(5).onAppear(perform: fetch)
    }

    private func fetch() {
        #if !SETAPP_ENABLED
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
        #endif
    }
}

struct AboutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSettingsView()
    }
}
