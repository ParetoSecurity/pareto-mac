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
    @State private var helperVersion = "Checking..."
    @State private var hasCheckedForUpdates = false

    @StateObject private var helperManager = HelperToolManager()
    @Default(.showBeta) var showBeta

    enum UpdateStates: String {
        case Checking = "Checking for updates"
        case NewVersion = "New version found"
        case Installing = "Installing new update"
        case Updated = "App is up to date"
        case Failed = "Failed to update, download manually"
    }

    var body: some View {
        HStack(spacing: 20) {
            Image("Icon").resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120)
                .onTapGesture {
                    konami += 1
                    if konami >= 3 {
                        showBeta.toggle()
                        konami = 0
                        if showBeta {
                            let alert = NSAlert()
                            alert.messageText = "You are now part of a secret society seeing somewhat mysterious things."
                            alert.alertStyle = NSAlert.Style.informational
                            alert.addButton(withTitle: "Let me in")
                            alert.runModal()
                            fetch()
                        }
                    }
                }
            VStack(alignment: .leading, spacing: 8) {
                Text("Pareto Security").font(.title)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Version: \(AppInfo.appVersion) - \(AppInfo.buildVersion)")
                    Text("Helper: \(helperVersion)")
                    Text("Channel: \(AppInfo.utmSource)")

                    #if SETAPP_ENABLED
                        HStack(spacing: 10) {
                            if !hasCheckedForUpdates || status == UpdateStates.Updated {
                                Button("Check") {
                                    UpdateService.shared.clearCache()
                                    fetch()
                                }
                                .disabled(isLoading)
                            }

                            if hasCheckedForUpdates && status == UpdateStates.NewVersion {
                                Button("Update") {
                                    forceUpdate()
                                }
                                .disabled(isLoading)
                            }
                            if status == UpdateStates.Failed {
                                Text("Failed to update, [download update](https://github.com/ParetoSecurity/pareto-mac/releases/latest/download/ParetoSecurity.dmg)")

                            } else {
                                Text(status.rawValue)
                            }

                            if self.isLoading {
                                ProgressView()
                            }
                        }
                    #endif
                }

                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("We'd love to [hear from you!](https://paretosecurity.com/contact)")
                    Text("Made with ❤️ in 🇪🇺")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            fetchHelperVersion()
            #if SETAPP_ENABLED
                fetch()
            #endif
        }
    }

    private func fetchHelperVersion() {
        Task {
            await helperManager.getHelperVersion { version in
                DispatchQueue.main.async {
                    self.helperVersion = HelperToolUtilities.isHelperInstalled() ? version : "Not installed"
                }
            }
        }
    }

    private func fetch() {
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                isLoading = true
                status = UpdateStates.Checking
            }

            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
            let currentVersion = Bundle.main.version

            if let release = try? updater.getLatestRelease() {
                DispatchQueue.main.async {
                    hasCheckedForUpdates = true
                    isLoading = false

                    if currentVersion < release.version {
                        status = UpdateStates.NewVersion
                        #if SETAPP_ENABLED
                            Defaults[.updateNag] = true
                        #endif
                    } else {
                        status = UpdateStates.Updated
                        Defaults[.updateNag] = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    hasCheckedForUpdates = true
                    status = UpdateStates.Failed
                    isLoading = false
                }
            }
        }
    }

    private func forceUpdate() {
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                isLoading = true
                status = UpdateStates.Installing
            }

            let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

            if let release = try? updater.getLatestRelease() {
                #if SETAPP_ENABLED
                    DispatchQueue.main.async {
                        isLoading = false
                        status = UpdateStates.Failed
                        let alert = NSAlert()
                        alert.messageText = "Force update is not available in SetApp version"
                        alert.informativeText = "Please use SetApp to update the application"
                        alert.alertStyle = NSAlert.Style.informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return
                #endif

                if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                    let done = updater.downloadAndUpdate(withAsset: zipURL)
                    if !done {
                        DispatchQueue.main.async {
                            status = UpdateStates.Failed
                            isLoading = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        status = UpdateStates.Failed
                        isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    status = UpdateStates.Failed
                    isLoading = false
                }
            }
        }
    }
}

struct AboutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSettingsView()
    }
}
