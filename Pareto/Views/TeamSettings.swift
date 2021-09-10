//
//  TeamSettings.swift
//  TeamSettings
//
//  Created by Janez Troha on 10/09/2021.
//

import Defaults
import SwiftUI

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

struct TeamSettings_Previews: PreviewProvider {
    static var previews: some View {
        TeamSettingsView()
    }
}
