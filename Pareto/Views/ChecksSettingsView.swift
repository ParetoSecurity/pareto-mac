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
                    ForEach(claim.checks.sorted(by: { $0.TitleON < $1.TitleON }), id: \.self) { check in
                        Toggle(check.TitleON, isOn: Binding<Bool>(
                            get: { check.isActive },
                            set: {
                                check.isActive = $0
                                updater.toggle()
                            }
                        ))
                    }
                }
            }
            Spacer()
            HStack(spacing: 0) {
                Text("Learn more about the security checks on ")

                Link("our website",
                     destination: URL(string: "https://paretosecurity.app/security-checks?utm_source=app")!)
                Text(".")
            }
        }
        .frame(width: 350).padding(5)
    }
}

struct CheckSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChecksSettingsView()
    }
}
