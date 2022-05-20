//
//  CheckSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct ChecksSettingsView: View {
    @State var updater: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Deselect the checks you don't want the app to run.")
                VStack(alignment: .leading, spacing: 0.0) {
                    ForEach(Claims.sorted, id: \.self) { claim in

                        // Hack to force update view
                        // see https://developer.apple.com/forums/thread/131577
                        let title = "\(claim.title) (\(claim.checks.count))"
                        if updater {
                            Text(title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        } else {
                            Text(title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        }
                        ForEach(claim.checksSorted, id: \.self) { check in
                            VStack(alignment: .leading) {
                                Toggle(check.TitleON, isOn: Binding<Bool>(
                                    get: { check.isActive },
                                    set: {
                                        check.isActive = $0
                                        updater.toggle()
                                    }
                                )).disabled(!check.showSettings)
                                if check.teamEnforced {
                                    Text("Check is required by your Team.").font(.footnote)
                                }
                                if check.showSettingsWarnDiskAccess && !check.isRunnable {
                                    Text("Requires full disk access permission.").font(.footnote)
                                    Button {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)

                                    } label: {
                                        Text("Authorize")
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
                }.padding(0)
            }.padding(.all, 20).frame(minWidth: 380, minHeight: 480)

        }.frame(width: 400, height: 400)
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
