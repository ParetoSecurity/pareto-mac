//
//  ChecksSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct ChecksSettingsView: View {
    @State var updater: Bool = false
    @Default(.teamID) var teamID

    var body: some View {
        baseList
            .listStyle(.inset)
            .centered()
    }

    private var baseList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deselect the checks you don't want the app to run.")
                    if !teamID.isEmpty {
                        Text("Checks with asterisk (✴) are required by your team.")
                    }
                    HStack(spacing: 0) {
                        Link("Learn more", destination: URL(string: "https://paretosecurity.com/security-checks?utm_source=\(AppInfo.utmSource)")!)
                        Text(" about checks on our website.")
                    }
                }
            }
            ForEach(Claims.global.all, id: \.self) { claim in
                if updater { EmptyView() }
                let filtered = claim.checksSorted.filter { check in
                    check.isInstalled
                }
                if !filtered.isEmpty {
                    Section(header: Text("\(claim.title) (\(claim.checks.count))").font(.headline)) {
                        ForEach(filtered, id: \.self) { check in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    if check.teamEnforced {
                                        Text("✴")
                                        Text(check.TitleON)
                                    } else {
                                        Toggle(check.TitleON, isOn: Binding<Bool>(
                                            get: { check.isActive },
                                            set: {
                                                check.isActive = $0
                                                updater.toggle()
                                            }
                                        ))
                                        .disabled(!check.showSettings)
                                    }
                                }
                                if check.showSettingsWarnDiskAccess && !check.isRunnable {
                                    HStack(spacing: 8) {
                                        Text("Requires full disk access permission.").font(.footnote)
                                        Button("Authorize") {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                                        }
                                        .font(.footnote)
                                        Link("?", destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    }
                                }
                                if check.showSettingsWarnEvents && !check.isRunnable {
                                    HStack(spacing: 8) {
                                        Text("Requires System Events access permission.").font(.footnote)
                                        Button("Authorize") {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                                        }
                                        .font(.footnote)
                                        Link("?", destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
