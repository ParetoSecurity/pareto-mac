//
//  SettingsView.swift
//  Pareto
//
//  Created by Janez Troha on 14/07/2021.
//
import AppKit
import Defaults

import SwiftUI

struct SettingsView: View {
    @State var selected: Tabs
    @Default(.teamID) var teamID

    enum Tabs: Hashable {
        case general, about, teams, checks, license
    }

    var body: some View {
        TabView(selection: $selected) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            TeamSettingsView()
                .tabItem {
                    Label("Teams", systemImage: "person.3.fill")
                }
                .tag(Tabs.teams)
            ChecksSettingsView()
                .tabItem {
                    Label("Checks", systemImage: "checkmark.seal")
                }
                .tag(Tabs.checks)
            #if !SETAPP_ENABLED
                if teamID.isEmpty {
                    LicenseSettingsView()
                        .tabItem {
                            Label("License", systemImage: "rectangle.badge.person.crop")
                        }
                        .tag(Tabs.license)
                }
            #endif
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }.onAppear(perform: decideTab)
    }

    private func decideTab() {
        if Defaults[.updateNag] {
            selected = .about
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView(selected: SettingsView.Tabs.general)
        }
    }
}
