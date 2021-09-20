//
//  LicenseView.swift
//  LicenseView
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

struct LicenseSettingsView: View {
    @Default(.userEmail) var userEmail
    @Default(.license) var license

    var body: some View {
        if AppInfo.Licensed {
            if !Defaults[.teamID].isEmpty {
                VStack(alignment: .leading) {
                    Spacer()
                    Text("The app is licensed under the Teams account.")
                    Spacer()
                }.frame(width: 350, height: 50).padding(5)
            } else {
                VStack(alignment: .leading) {
                    Text("Thanks for purchasing the Personal license. The app is licensed to \(userEmail).")
                    Spacer()
                    Text("To copy the license to your other devices, click the button below, and paste the URL into your address bar on the new device.")
                    Spacer()
                    Button("Copy license") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("paretosecurity://enrollSingle/?token=\(license)", forType: .string)
                    }

                }.frame(width: 350, height: 120).padding(5)
            }

        } else {
            VStack {
                Text("You are running the free version of the app. Please consider purchasing the Personal lifetime license for unlimited devices!")
                Link("Learn more »",
                     destination: URL(string: "https://paretosecurity.app/pricing?utm_source=app&utm_medium=license-link")!)
            }.frame(width: 350, height: 100).padding(5)
        }
    }
}

struct LicenseSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseSettingsView()
    }
}
