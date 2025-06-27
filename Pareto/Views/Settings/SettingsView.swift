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
        case general, about, teams, checks, permissions
    }

    var body: some View {
        TabView(selection: $selected) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised.square.fill")
                }
                .tag(Tabs.permissions)
            #if !SETAPP_ENABLED
                TeamSettingsView(teamSettings: AppInfo.TeamSettings)
                    .tabItem {
                        Label("Cloud", systemImage: "person.3.fill")
                    }
                    .tag(Tabs.teams)
            #endif
            ChecksSettingsView()
                .tabItem {
                    Label("Checks", systemImage: "checkmark.seal")
                }
                .tag(Tabs.checks)
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }.onAppear(perform: decideTab).padding(25)
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
