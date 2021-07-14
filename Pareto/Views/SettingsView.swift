//
//  SettingsView.swift
//  Pareto
//
//  Created by Janez Troha on 14/07/2021.
//
import SwiftUI
import AppKit
import LaunchAtLogin

struct GeneralSettingsView: View {
    @ObservedObject private var atLogin = LaunchAtLogin.observable
    
    var body: some View {
        Form {
            Section(
                footer: Text("Automaticly opens the app when you start your Mac.")) {
                VStack(alignment: .leading) {
                    Toggle("Start at Login", isOn: $atLogin.isEnabled)
                }
            }
        }
        
        .frame(width: 350, height: 80).padding(5)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        HStack{
            Image("Icon").resizable()
                .aspectRatio(contentMode: .fit)
            Text("Made with ❤️ at Niteo.")
        }.frame(width: 350, height: 80).padding(5)
    }
}

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, about
    }
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info")
                }
                .tag(Tabs.about)
        }
        .padding(20)
        .frame(width: 375, height: 150)
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
