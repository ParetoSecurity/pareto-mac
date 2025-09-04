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
    var embedded: Bool = false
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
        }
        .onAppear(perform: decideTab)
        .padding(24)
        .frame(width: 480, height: targetHeight, alignment: .top)
        .id(selected) // Force layout refresh when tab changes so targetHeight applies
    }

    private func decideTab() {
        if Defaults[.updateNag] {
            selected = .about
        }
    }
}

private extension SettingsView {
    var targetHeight: CGFloat {
        // Tuned per-tab to balance space vs. scroll need
        switch selected {
        case .general:
            return 220
        case .permissions:
            return 280
        case .teams:
            return teamID.isEmpty ? 80 : 240
        case .checks:
            return 560
        case .about:
            return 200
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
