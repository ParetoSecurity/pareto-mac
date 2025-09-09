//
//  IgnoredSSHKeysSettingsView.swift
//  Pareto Security
//
//  Created by Codex on 2025-09-09.
//

import Defaults
import Foundation
import SwiftUI

struct IgnoredSSHKeysSettingsView: View {
    @Default(.ignoredSSHKeys) var ignoredSSHKeys
    @State private var availableKeys: [String] = [] // base filenames for private keys
    @State private var selectedKey: String?
    @State private var isLoading = false
    @State private var showRerunNotice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showRerunNotice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.orange)
                    Text("Ignored SSH keys updated. Rerun checks to refresh the report.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") { showRerunNotice = false }.buttonStyle(.link)
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
                            Button(action: { removeIgnoredKey(key) }) {
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
                Picker("Add SSH key to ignore:", selection: $selectedKey) {
                    Text("Select key...").tag(String?.none)
                    ForEach(availableKeysNotIgnored, id: \.self) { key in
                        Text(key).tag(String?.some(key))
                    }
                }
                .pickerStyle(.menu)
                .disabled(isLoading)

                Button("Add") {
                    if let key = selectedKey { addIgnoredKey(key); selectedKey = nil }
                }
                .disabled(selectedKey == nil)
            }

            // Dropdown-only input, no manual text field per request

            if availableKeysNotIgnored.isEmpty && !isLoading {
                Text("No additional SSH keys available to ignore")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text("Ignored key names are based on files in ~/.ssh (e.g., id_rsa, id_ed25519).")
                .font(.footnote)
        }
        .onAppear { loadAvailableKeys() }
        .onChange(of: ignoredSSHKeys) { _ in
            // Defer to next runloop to avoid state change during update
            DispatchQueue.main.async { self.showRerunNotice = true }
        }
    }

    private var availableKeysNotIgnored: [String] {
        availableKeys.filter { !ignoredSSHKeys.contains($0) }
    }

    private func loadAvailableKeys() {
        isLoading = true
        DispatchQueue.global(qos: .background).async {
            let sshDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ssh")
                .resolvingSymlinksInPath()
            var keys: [String] = []
            if let contents = try? FileManager.default.contentsOfDirectory(at: sshDir, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "pub" {
                    let base = url.deletingPathExtension().lastPathComponent
                    keys.append(base)
                }
            }
            DispatchQueue.main.async {
                self.availableKeys = Array(Set(keys)).sorted()
                self.isLoading = false
            }
        }
    }

    private func addIgnoredKey(_ key: String) {
        var list = ignoredSSHKeys
        if !list.contains(key) {
            list.append(key)
            let sorted = list.sorted()
            DispatchQueue.main.async {
                self.ignoredSSHKeys = sorted
                self.showRerunNotice = true
            }
        }
    }

    private func removeIgnoredKey(_ key: String) {
        let updated = ignoredSSHKeys.filter { $0 != key }
        DispatchQueue.main.async {
            self.ignoredSSHKeys = updated
            self.showRerunNotice = true
        }
    }
}

struct IgnoredSSHKeysSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredSSHKeysSettingsView()
    }
}
