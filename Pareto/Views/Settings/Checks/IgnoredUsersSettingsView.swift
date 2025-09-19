//
//  IgnoredUsersSettingsView.swift
//  Pareto Security
//
//  Created by Claude on 2025-09-08.
//

import Defaults
import Foundation
import SwiftUI

@MainActor
final class IgnoredUsersViewModel: ObservableObject {
    @Published var availableUsers: [String] = []
    @Published var isLoadingUsers = false
    @Published var selectedUser: String?
    @Published var showRerunNotice = false

    func loadAvailableUsers() async {
        if isLoadingUsers { return }
        isLoadingUsers = true

        // Run command off the main actor
        let output = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let out = runCMD(app: "/usr/bin/dscl", args: [".", "-list", "/Users"])
                continuation.resume(returning: out)
            }
        }

        let lines = output.components(separatedBy: "\n")
        let local = lines.filter { u in
            !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
        }

        // Back on main actor via @MainActor class
        availableUsers = local.sorted()
        isLoadingUsers = false
    }

    func addIgnoredUser(_ user: String) {
        var users = Defaults[.ignoredUserAccounts]
        if !users.contains(user) {
            users.append(user)
            Defaults[.ignoredUserAccounts] = users.sorted()
            showRerunNotice = true
        }
    }

    func removeIgnoredUser(_ user: String) {
        let updated = Defaults[.ignoredUserAccounts].filter { $0 != user }
        Defaults[.ignoredUserAccounts] = updated
        showRerunNotice = true
    }
}

struct IgnoredUsersSettingsView: View {
    @StateObject private var model = IgnoredUsersViewModel()
    @Default(.ignoredUserAccounts) private var ignoredUserAccounts

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                if model.showRerunNotice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Ignored users updated. Rerun checks to refresh the report.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") { model.showRerunNotice = false }
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
                                Button {
                                    model.removeIgnoredUser(user)
                                } label: {
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
                    Picker("Add user to ignore:", selection: $model.selectedUser) {
                        Text("Select user...").tag(String?.none)
                        ForEach(availableUsersNotIgnored, id: \.self) { user in
                            Text(user).tag(String?.some(user))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Add") {
                        if let user = model.selectedUser {
                            model.addIgnoredUser(user)
                            model.selectedUser = nil
                        }
                    }
                    .disabled(model.selectedUser == nil)
                }

                if availableUsersNotIgnored.isEmpty && !model.isLoadingUsers {
                    Text("No additional users available to ignore")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Text("These user accounts will be excluded from the unused user accounts check. This is useful for service accounts that don't log in regularly.")
                    .font(.footnote)
            }
        }
        .task {
            await model.loadAvailableUsers()
        }
        // Also refresh the available list after checks complete (keeps parity with other views)
        .onReceive(NotificationCenter.default.publisher(for: .runChecksFinished)) { _ in
            Task { await model.loadAvailableUsers() }
        }
    }

    private var availableUsersNotIgnored: [String] {
        model.availableUsers.filter { !ignoredUserAccounts.contains($0) }
    }
}

struct IgnoredUsersSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredUsersSettingsView()
    }
}
