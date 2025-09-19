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
            ChecksSettingsView()
                .tabItem {
                    Label("Checks", systemImage: "checkmark.seal.text.page")
                }
                .tag(Tabs.checks)
            #if !SETAPP_ENABLED
                TeamSettingsView(teamSettings: AppInfo.TeamSettings)
                    .tabItem {
                        Label("Cloud", systemImage: "icloud")
                    }
                    .tag(Tabs.teams)
            #endif

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tabs.about)
        }
        .scenePadding()
        .frame(width: 520)
        .onAppear {
            // Bring the app (and thus the Settings window) to the front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
