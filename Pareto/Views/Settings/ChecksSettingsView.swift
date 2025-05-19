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
        ScrollView(.vertical) {
            Group {
                Text("Deselect the checks you don't want the app to run.")
                if !teamID.isEmpty {
                    Text("Checks with asterisk (✴) are required by your team.")
                }
                VStack(alignment: .leading, spacing: 0.0) {
                    ForEach(Claims.global.all, id: \.self) { claim in

                        // Hack to force update view
                        // see https://developer.apple.com/forums/thread/131577
                        let title = "\(claim.title) (\(claim.checks.count))"
                        if updater {
                            Text(title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        } else {
                            Text(title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        }
                        ForEach(claim.checksSorted.filter { check in
                            check.isInstalled
                        }, id: \.self) { check in
                            VStack(alignment: .leading) {
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
                                        )).disabled(!check.showSettings)
                                    }
                                }
                                if check.showSettingsWarnDiskAccess && !check.isRunnable {
                                    HStack {
                                        Text("Requires full disk access permission.").font(.footnote)
                                        Button {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)

                                        } label: {
                                            Text("Authorize").font(.footnote)
                                        }
                                        Link("?",
                                             destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    }
                                }
                                if check.showSettingsWarnEvents && !check.isRunnable {
                                    HStack {
                                        Text("Requires System Events access permission.").font(.footnote)
                                        Button {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)

                                        } label: {
                                            Text("Authorize").font(.footnote)
                                        }
                                        Link("?",
                                             destination: URL(string: "https://paretosecurity.com/docs/mac/permissions?utm_source=\(AppInfo.utmSource)")!)
                                    }
                                }
                            }.padding(.vertical, 5.0)
                        }
                    }
                }
                HStack(spacing: 0) {
                    Link("Learn more",
                         destination: URL(string: "https://paretosecurity.com/security-checks?utm_source=\(AppInfo.utmSource)")!)
                    Text(" about checks on our website.")
                }
            }.frame(maxWidth: .infinity).padding(25)

        }.frame(width: 480, height: 400)
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
