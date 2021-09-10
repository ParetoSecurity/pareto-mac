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
    @Default(.showBeta) var showBeta

    private enum Tabs: Hashable {
        case general, about, team, checks, license
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            TeamSettingsView()
                .tabItem {
                    Label("Teams", systemImage: "person.3.fill")
                }
                .tag(Tabs.team)
            ChecksSettingsView()
                .tabItem {
                    Label("Checks", systemImage: "checkmark.seal")
                }
                .tag(Tabs.checks)
            ChecksSettingsView()
                .tabItem {
                    Label("License", systemImage: "person.text.rectangle")
                }
                .tag(Tabs.license)
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }
        .padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView()
        }
    }
}
