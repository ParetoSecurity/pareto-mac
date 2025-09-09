//
//  IgnoredUsersSettingsView.swift
//  Pareto Security
//
//  Created by Claude on 2025-09-08.
//

import Defaults
import Foundation
import SwiftUI

struct IgnoredUsersSettingsView: View {
    @Default(.ignoredUserAccounts) var ignoredUserAccounts
    @State private var selectedUser: String?
    @State private var availableUsers: [String] = []
    @State private var isLoadingUsers = false
    @State private var showRerunNotice = false

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                if showRerunNotice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Ignored users updated. Rerun checks to refresh the report.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") { showRerunNotice = false }
                            .buttonStyle(.link)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                if !ignoredUserAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Currently Ignored:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        ForEach(ignoredUserAccounts, id: \.self) { user in
                            HStack {
                                Text(user)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: {
                                    removeIgnoredUser(user)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
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
                    Picker("Add user to ignore:", selection: $selectedUser) {
                        Text("Select user...").tag(String?.none)
                        ForEach(availableUsersNotIgnored, id: \.self) { user in
                            Text(user).tag(String?.some(user))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isLoadingUsers || availableUsersNotIgnored.isEmpty)

                    Button("Add") {
                        if let user = selectedUser {
                            addIgnoredUser(user)
                            selectedUser = nil
                        }
                    }
                    .disabled(selectedUser == nil)
                }

                if availableUsersNotIgnored.isEmpty && !isLoadingUsers {
                    Text("No additional users available to ignore")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Text("These user accounts will be excluded from the unused user accounts check. This is useful for service accounts that don't log in regularly.").font(.footnote)
            }
        }
        .onAppear {
            loadAvailableUsers()
        }
        .onChange(of: ignoredUserAccounts) { _ in
            // Show notice whenever ignored users list changes
            showRerunNotice = true
        }
    }

    private var availableUsersNotIgnored: [String] {
        availableUsers.filter { !ignoredUserAccounts.contains($0) }
    }

    private func loadAvailableUsers() {
        isLoadingUsers = true

        DispatchQueue.global(qos: .background).async {
            // List all local users
            let output = runCMD(app: "/usr/bin/dscl", args: [".", "-list", "/Users"])
                .components(separatedBy: "\n")

            // Keep human/local accounts; hide obvious system accounts
            let local = output.filter { u in
                !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
            }

            DispatchQueue.main.async {
                self.availableUsers = local.sorted()
                self.isLoadingUsers = false
            }
        }
    }

    private func addIgnoredUser(_ user: String) {
        var users = ignoredUserAccounts
        if !users.contains(user) {
            users.append(user)
            ignoredUserAccounts = users.sorted()
            showRerunNotice = true
        }
    }

    private func removeIgnoredUser(_ user: String) {
        ignoredUserAccounts = ignoredUserAccounts.filter { $0 != user }
        showRerunNotice = true
    }
}

struct IgnoredUsersSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredUsersSettingsView()
    }
}
