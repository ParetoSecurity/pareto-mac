//
//  IgnoredSSHKeysSettingsView.swift
//  Pareto Security
//
//  Created by Codex on 2025-09-09.
//

import Defaults
import Foundation
import SwiftUI

@MainActor
final class IgnoredSSHKeysViewModel: ObservableObject {
    // Base filenames for private keys (e.g., id_rsa, id_ed25519)
    @Published var availableKeys: [String] = []
    @Published var selectedKey: String?
    @Published var isLoading = false
    @Published var showRerunNotice = false

    func loadAvailableKeys() async {
        if isLoading { return }
        isLoading = true

        // Do file system work off the main actor
        let keys: [String] = await Task.detached(priority: .userInitiated) { () -> [String] in
            let sshDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ssh")
                .resolvingSymlinksInPath()
            var results: [String] = []
            if let contents = try? FileManager.default.contentsOfDirectory(at: sshDir, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "pub" {
                    let base = url.deletingPathExtension().lastPathComponent
                    results.append(base)
                }
            }
            return Array(Set(results)).sorted()
        }.value

        // Back on main actor via @MainActor class
        availableKeys = keys
        isLoading = false
    }

    func addIgnoredKey(_ key: String) {
        var list = Defaults[.ignoredSSHKeys]
        if !list.contains(key) {
            list.append(key)
            Defaults[.ignoredSSHKeys] = list.sorted()
            showRerunNotice = true
        }
    }

    func removeIgnoredKey(_ key: String) {
        let updated = Defaults[.ignoredSSHKeys].filter { $0 != key }
        Defaults[.ignoredSSHKeys] = updated
        showRerunNotice = true
    }
}

struct IgnoredSSHKeysSettingsView: View {
    @StateObject private var model = IgnoredSSHKeysViewModel()
    @Default(.ignoredSSHKeys) private var ignoredSSHKeys

    private var availableKeysNotIgnored: [String] {
        model.availableKeys.filter { !ignoredSSHKeys.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.showRerunNotice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.orange)
                    Text("Ignored SSH keys updated. Rerun checks to refresh the report.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") { model.showRerunNotice = false }.buttonStyle(.link)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }

            if !ignoredSSHKeys.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currently Ignored:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    ForEach(ignoredSSHKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(action: { model.removeIgnoredKey(key) }) {
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
                Picker("Add SSH key to ignore:", selection: $model.selectedKey) {
                    Text("Select key...").tag(String?.none)
                    ForEach(availableKeysNotIgnored, id: \.self) { key in
                        Text(key).tag(String?.some(key))
                    }
                }
                .pickerStyle(.menu)

                Button("Add") {
                    if let key = model.selectedKey {
                        model.addIgnoredKey(key)
                        model.selectedKey = nil
                    }
                }
                .disabled(model.selectedKey == nil)
            }

            if availableKeysNotIgnored.isEmpty && !model.isLoading {
                Text("No additional SSH keys available to ignore")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text("Ignored key names are based on files in ~/.ssh (e.g., id_rsa, id_ed25519).")
                .font(.footnote)
        }
        .task {
            await model.loadAvailableKeys()
        }
        // Refresh list when checks finish running (e.g., user triggered from menu)
        .onReceive(NotificationCenter.default.publisher(for: .runChecksFinished)) { _ in
            Task { await model.loadAvailableKeys() }
        }
    }
}

struct IgnoredSSHKeysSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredSSHKeysSettingsView()
    }
}
