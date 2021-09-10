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

    var body: some View {
        if AppInfo.Licensed {
            VStack {
                Text("Thanks for purchasing the Personal license!")
                Spacer()
                Text("Licensed to: \(userEmail)")

            }.frame(width: 350, height: 50).padding(5)
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
