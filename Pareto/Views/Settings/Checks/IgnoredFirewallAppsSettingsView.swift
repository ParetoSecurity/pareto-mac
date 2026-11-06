//
//  IgnoredFirewallAppsSettingsView.swift
//  Pareto Security
//
//  Created by ArchitektApx on 06/11/2026.
//

import Defaults
import Foundation
import SwiftUI

@MainActor
final class IgnoredFirewallAppsViewModel: ObservableObject {
    @Published var availableApps: [String] = []
    @Published var selectedApp: String?
    @Published var isLoading = false
    @Published var showRerunNotice = false

    func loadAvailableApps() async {
        if isLoading {
            return
        }
        isLoading = true

        let apps: [String] = await Task.detached(priority: .userInitiated) { () -> [String] in
            let allowed = FirewallExceptionsCheck.parseListApps(FirewallExceptionsCheck.listApps())?
                .filter(\.allowsIncoming)
                .map(\.path) ?? []
            return Array(Set(allowed)).sorted()
        }.value

        availableApps = apps
        isLoading = false
    }

    func addIgnoredApp(_ app: String) {
        var list = Defaults[.ignoredFirewallApps]
        if !list.contains(app) {
            list.append(app)
            Defaults[.ignoredFirewallApps] = list.sorted()
            showRerunNotice = true
        }
    }

    func removeIgnoredApp(_ app: String) {
        let updated = Defaults[.ignoredFirewallApps].filter { $0 != app }
        Defaults[.ignoredFirewallApps] = updated
        showRerunNotice = true
    }
}

struct IgnoredFirewallAppsSettingsView: View {
    @StateObject private var model = IgnoredFirewallAppsViewModel()
    @Default(.ignoredFirewallApps) private var ignoredFirewallApps

    private var availableAppsNotIgnored: [String] {
        model.availableApps.filter { !ignoredFirewallApps.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.showRerunNotice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.orange)
                    Text("Ignored firewall apps updated. Rerun checks to refresh the report.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") { model.showRerunNotice = false }.buttonStyle(.link)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }

            if !ignoredFirewallApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currently Ignored:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    ForEach(ignoredFirewallApps, id: \.self) { app in
                        HStack {
                            Text(app)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                model.removeIgnoredApp(app)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }.buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
                Divider()
            }

            HStack {
                Picker("Add app to ignore:", selection: $model.selectedApp) {
                    Text("Select app...").tag(String?.none)
                    ForEach(availableAppsNotIgnored, id: \.self) { app in
                        Text(app).tag(String?.some(app))
                    }
                }
                .pickerStyle(.menu)

                Button("Add") {
                    if let app = model.selectedApp {
                        model.addIgnoredApp(app)
                        model.selectedApp = nil
                    }
                }
                .disabled(model.selectedApp == nil)
            }

            if availableAppsNotIgnored.isEmpty, !model.isLoading {
                Text("No additional allowed apps available to ignore")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text("Lists apps set to \"Allow incoming connections\" in System Settings > Network > Firewall > Options.")
                .font(.footnote)
        }
        .task {
            await model.loadAvailableApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: .runChecksFinished)) { _ in
            Task { await model.loadAvailableApps() }
        }
    }
}

struct IgnoredFirewallAppsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredFirewallAppsSettingsView()
    }
}
