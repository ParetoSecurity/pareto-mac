//
//  StatusBarMenuView.swift
//  Pareto Security
//
//  Created by Claude on 20/06/2025.
//

import AppKit
import Defaults
import SettingsAccess
import SwiftUI

struct StatusBarMenuView: View {
    @ObservedObject var statusBarModel: StatusBarModel
    // Observe claims so menu refreshes when checks finish
    @ObservedObject private var claims = Claims.global
    @EnvironmentObject var appHandlers: AppHandlers

    @Default(.snoozeTime) var snoozeTime
    @Default(.lastCheck) var lastCheck

    private var claimsPassed: Bool {
        Claims.global.all.allSatisfy { claim in
            claim.checksSorted.allSatisfy { check in
                check.isRunnable ? check.isActive && check.checkPassed : true
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Security checks (hidden while running)
            if !statusBarModel.isRunning {
                ForEach(claims.all, id: \.title) { claim in
                    if !claim.checks.isEmpty {
                        ClaimMenuView(claim: claim)
                    }
                }
                // Force re-render of list when checks or running state changes
                .id(statusBarModel.refreshNonce)
            }

            statusline().id(statusBarModel.refreshNonce ^ (statusBarModel.isRunning ? 1 : 0))

            Divider()
            // Action buttons
            if !statusBarModel.isRunning {
                if snoozeTime == 0 {
                    Button {
                        appHandlers.runChecks()
                    } label: {
                        Text("Run Checks")
                    }
                    .keyboardShortcut("r")
                    .padding(.horizontal)
                    .padding(.vertical, 2)

                    Menu {
                        Button("for 1 hour") {
                            appHandlers.snoozeOneHour()
                        }
                        Button("for 1 day") {
                            appHandlers.snoozeOneDay()
                        }
                        Button("for 1 week") {
                            appHandlers.snoozeOneWeek()
                        }
                    } label: {
                        Text("Snooze")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                } else {
                    Button {
                        appHandlers.unsnooze()
                    } label: {
                        Text("Resume checks")
                    }
                    .keyboardShortcut("u")
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Preferences")
                } preAction: {
                    NSApp.activate(ignoringOtherApps: true)
                } postAction: {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            } else {
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("Preferences")
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            }

            Button {
                appHandlers.docs()
            } label: {
                Text("Documentation")
            }
            .keyboardShortcut("d")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Button {
                appHandlers.reportBug()
            } label: {
                Text("Contact Support")
            }
            .keyboardShortcut("b")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Divider()

            Button {
                appHandlers.quitApp()
            } label: {
                Text("Quit Pareto")
            }
            .keyboardShortcut("q")
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
        .frame(minWidth: 200)
        .onAppear {
            // Cancel auto-hide while menu is open
            appHandlers.cancelAutoHide()
        }
        .onDisappear {
            // Resume auto-hide timer when menu closes
            appHandlers.scheduleAutoHide()
        }
    }

    // Extracted status line
    @ViewBuilder
    private func statusline() -> some View {
        if !statusBarModel.isRunning {
            if snoozeTime == 0 {
                let title = lastCheck == 0 ? "Not checked yet" : "Last check \(Date.fromTimeStamp(timeStamp: lastCheck).timeAgoDisplay())"
                Text(title)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            } else {
                Text("Resumes \(Date.fromTimeStamp(timeStamp: snoozeTime).timeAgoDisplay())")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        } else {
            Text("Running checks ...")
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 4)
        }
    }

    // Ensure the status bar icon reflects the latest state when the menu opens
    private func updateStateForCurrentStatus() {
        // Don’t override the “running” state
        guard !statusBarModel.isRunning else {
            statusBarModel.state = .idle
            statusBarModel.refreshNonce &+= 1
            return
        }

        if snoozeTime > 0 {
            statusBarModel.state = .idle
        } else {
            statusBarModel.state = claimsPassed ? .allOk : .warning
        }
        // Force a small refresh to ensure views re-evaluate ids
        statusBarModel.refreshNonce &+= 1
    }
}

struct ClaimMenuView: View {
    let claim: Claim

    @Default(.alternativeColor) private var alternativeColor

    private var statusSymbol: String {
        claim.checksPassed ? "✓" : "✕"
    }

    private var statusColor: Color {
        _ = alternativeColor
        return Color(nsColor: claim.checksPassed ? Defaults.OKColor() : Defaults.FailColor())
    }

    private var title: Text {
        Text(statusSymbol)
            .foregroundColor(statusColor) + Text(" \(claim.title)")
    }

    var body: some View {
        Menu {
            ForEach(claim.checksSorted.filter { $0.showInMenu }, id: \.id) { check in
                CheckMenuItemView(check: check)
            }
        } label: {
            title
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

struct CheckMenuItemView: View {
    // Observe individual check for live updates
    @ObservedObject var check: ParetoCheck

    @Default(.alternativeColor) private var alternativeColor

    private var statusSymbol: String {
        if check.isRunnable {
            check.checkPassed ? "✓" : "✕"
        } else {
            "–"
        }
    }

    private var statusColor: Color {
        _ = alternativeColor
        if check.isRunnable {
            return Color(nsColor: check.checkPassed ? Defaults.OKColor() : Defaults.FailColor())
        }
        return Color.secondary
    }

    private var title: Text {
        Text(statusSymbol)
            .foregroundColor(statusColor) + Text(" \(check.Title)")
    }

    var body: some View {
        Button(action: {
            // Open info URL
            NSWorkspace.shared.open(check.infoURL)
        }) {
            title
        }
        .buttonStyle(PlainButtonStyle())
    }
}
