//
//  StatusBarMenuView.swift
//  Pareto Security
//
//  Created by Claude on 20/06/2025.
//

import Defaults
import SwiftUI

struct StatusBarMenuView: View {
    @ObservedObject var statusBarModel: StatusBarModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appHandlers

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
            // Security checks
            ForEach(Claims.global.all, id: \.title) { claim in
                if !claim.checks.isEmpty {
                    ClaimMenuView(claim: claim)
                }
            }

            statusline()

            Divider()
            // Action buttons
            if !statusBarModel.isRunning {
                if snoozeTime == 0 {
                    Button("Run Checks") {
                        appHandlers.runChecks()
                    }
                    .keyboardShortcut("r")
                    .padding(.horizontal)
                    .padding(.vertical, 2)

                    Menu("Snooze") {
                        Button("for 1 hour") {
                            appHandlers.snoozeOneHour()
                        }
                        Button("for 1 day") {
                            appHandlers.snoozeOneDay()
                        }
                        Button("for 1 week") {
                            appHandlers.snoozeOneWeek()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                } else {
                    Button("Resume checks") {
                        appHandlers.unsnooze()
                    }
                    .keyboardShortcut("u")
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }
            // Settings with proper SwiftUI integration
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Preferences", systemImage: "gear")
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            } else {
                Button("Preferences") {
                    appHandlers.showPrefs()
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            }

            Button("Documentation") {
                appHandlers.docs()
            }
            .keyboardShortcut("d")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Button("Contact Support") {
                appHandlers.reportBug()
            }
            .keyboardShortcut("b")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Divider()

            Button("Quit Pareto") {
                appHandlers.quitApp()
            }
            .keyboardShortcut("q")
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
        .frame(minWidth: 200)
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
}

struct ClaimMenuView: View {
    let claim: Claim

    var body: some View {
        Menu {
            ForEach(claim.checksSorted, id: \.UUID) { check in
                CheckMenuItemView(check: check)
            }
        } label: {
            HStack {
                Group {
                    if claim.checksPassed {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                Text(claim.title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

struct CheckMenuItemView: View {
    let check: ParetoCheck

    var body: some View {
        Button(action: {
            // Open info URL
            NSWorkspace.shared.open(check.infoURL)
        }) {
            HStack {
                Group {
                    if check.isRunnable {
                        if check.checkPassed {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                Text(check.Title)
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
