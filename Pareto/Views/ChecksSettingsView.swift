//
//  CheckSettingsView.swift
//  CheckSettingsView
//
//  Created by Janez Troha on 10/09/2021.
//

import SwiftUI

struct ChecksSettingsView: View {
    @State var updater: Bool = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Deselect the checks you don't want the app to run.")
                VStack(alignment: .leading, spacing: 0.0) {
                    ForEach(AppInfo.claims.sorted(by: { $0.title < $1.title }), id: \.self) { claim in

                        // Hack to force update view
                        // see https://developer.apple.com/forums/thread/131577
                        if updater {
                            Text(claim.title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        } else {
                            Text(claim.title).fontWeight(.bold).font(.system(size: 15)).padding([.top, .bottom], 10)
                        }
                        ForEach(claim.checks.sorted(by: { $0.TitleON < $1.TitleON }), id: \.self) { check in
                            Toggle(check.TitleON, isOn: Binding<Bool>(
                                get: { check.isActive },
                                set: {
                                    check.isActive = $0
                                    updater.toggle()
                                }
                            )).disabled(!check.showSettings)
                                .padding(.vertical, 5.0)
                        }
                    }
                }
                HStack(spacing: 0) {
                    Link("Learn more",
                         destination: URL(string: "https://paretosecurity.com/security-checks?utm_source=app")!)
                    Text(" about checks on our website.")
                }.padding(0)
            }.padding(.all, 20).frame(minWidth: 380, minHeight: 380)

        }.frame(width: 400, height: 300)
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
