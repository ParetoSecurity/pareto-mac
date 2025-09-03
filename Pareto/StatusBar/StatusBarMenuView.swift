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
    @EnvironmentObject var appHandlers: AppHandlers
    @Default(.snoozeTime) var snoozeTime
    @Default(.lastCheck) var lastCheck
    @Default(.teamID) var teamID
    @Default(.isTeamOwner) var isTeamOwner

    private var claimsPassed: Bool {
        Claims.global.all.allSatisfy { claim in
            claim.checksSorted.allSatisfy { check in
                check.isRunnable ? check.isActive && check.checkPassed : true
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Check status
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

            Divider()

            // Security checks
            ForEach(Claims.global.all, id: \.title) { claim in
                if !claim.checks.isEmpty {
                    ClaimMenuView(claim: claim)
                }
            }

            // Action buttons
            if !statusBarModel.isRunning {
                if snoozeTime == 0 {
                    Button {
                        appHandlers.runChecks()
                    } label: {
                        Label("Run Checks", systemImage: "play.circle.fill")
                            .symbolRenderingMode(.multicolor)
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
                        Label("Snooze", systemImage: "zzz")
                            .symbolRenderingMode(.multicolor)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                } else {
                    Button {
                        appHandlers.unsnooze()
                    } label: {
                        Label("Resume checks", systemImage: "play.circle")
                            .symbolRenderingMode(.multicolor)
                    }
                    .keyboardShortcut("u")
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }

            #if !SETAPP_ENABLED
                if !teamID.isEmpty, isTeamOwner {
                    Divider()
                    Button("Team Dashboard") {
                        appHandlers.teamsDashboard()
                    }
                    .keyboardShortcut("t")
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            #endif

            Divider()

            // Settings with proper SwiftUI integration
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Preferences", systemImage: "gearshape.fill")
                        .symbolRenderingMode(.multicolor)
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            } else {
                Button {
                    appHandlers.showPrefs()
                } label: {
                    Label("Preferences", systemImage: "gearshape.fill")
                        .symbolRenderingMode(.multicolor)
                }
                .keyboardShortcut(",")
                .padding(.horizontal)
                .padding(.vertical, 2)
            }

            Button {
                appHandlers.docs()
            } label: {
                Label("Documentation", systemImage: "book.pages.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .keyboardShortcut("d")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Button {
                appHandlers.reportBug()
            } label: {
                Label("Contact Support", systemImage: "questionmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .keyboardShortcut("b")
            .padding(.horizontal)
            .padding(.vertical, 2)

            Divider()

            Button {
                appHandlers.quitApp()
            } label: {
                Label("Quit Pareto", systemImage: "power")
                    .symbolRenderingMode(.multicolor)
            }
            .keyboardShortcut("q")
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
        .frame(minWidth: 200)
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
                        Image(systemName: "checkmark.circle")
                            .symbolRenderingMode(.palette)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(nsColor: Defaults.OKColor()))
                    } else {
                        Image(systemName: "xmark.circle")
                            .symbolRenderingMode(.palette)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(nsColor: Defaults.FailColor()))
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
                            Image(systemName: "checkmark.circle")
                                .symbolRenderingMode(.palette)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(nsColor: Defaults.OKColor()))
                        } else {
                            Image(systemName: "xmark.circle")
                                .symbolRenderingMode(.palette)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(nsColor: Defaults.FailColor()))
                        }
                    } else {
                        Image(systemName: "questionmark.circle")
                            .symbolRenderingMode(.palette)
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                Text(check.Title)
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
