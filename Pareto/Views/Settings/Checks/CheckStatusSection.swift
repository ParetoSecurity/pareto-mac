//
//  CheckStatusSection.swift
//  Pareto Security
//
//  Shared "Current Status" section for the check detail views: status label,
//  failure details, a link to the fix and a button to re-run just this check.
//

import SwiftUI

struct CheckStatusSection: View {
    @ObservedObject var check: ParetoCheck
    /// Shown when the check can't run (prerequisite failures); loaded by the parent after render.
    var prerequisiteDetails: String?
    /// Overrides how details are derived (app checks show the app location instead).
    var statusDetails: String
    var shouldShowDetails: Bool

    @State private var isRechecking = false

    var body: some View {
        Section(header: Text("Current Status")) {
            if !check.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.gray)
                        Text("Check is disabled")
                            .font(.headline)
                        Spacer()
                    }
                    Text("This check has been manually disabled")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            } else if !check.isRunnable {
                cannotRunView
                actionRow(showFix: false)
            } else {
                HStack {
                    Text("Status:")
                    Spacer()
                    statusLabel
                }

                if shouldShowDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DetailsText(text: statusDetails)
                    }
                }

                actionRow(showFix: !check.checkPassed)
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusLabel: some View {
        if check.checkPassed {
            Label("Passing", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if check is TimeMachineCheck {
            Label("Time Machine is disabled or not configured", systemImage: "xmark.circle.fill")
                .foregroundColor(.orange)
        } else if check is TimeMachineHasBackupCheck || check is TimeMachineIsEncryptedCheck {
            if !TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable {
                Label(check.disabledReason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else if check is TimeMachineHasBackupCheck {
                Label("No recent backup found", systemImage: "xmark.circle.fill")
                    .foregroundColor(.orange)
            } else {
                Label("Backup disk is not encrypted", systemImage: "xmark.circle.fill")
                    .foregroundColor(.orange)
            }
        } else if let appCheck = check as? AppCheck {
            if !appCheck.isInstalled {
                Label("App not installed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.gray)
            } else if !appCheck.usedRecently {
                Label("App not used in the last week", systemImage: "clock.badge.xmark.fill")
                    .foregroundColor(.gray)
            } else {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .foregroundColor(.orange)
            }
        } else {
            Label("Failing", systemImage: "xmark.circle.fill")
                .foregroundColor(.orange)
        }
    }

    private var cannotRunView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Check cannot run")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Why:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                Text(check.disabledReason)
                    .font(.body)
            }

            if let details = prerequisiteDetails, !details.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    DetailsText(text: details)
                }
            }

            if check.teamEnforced {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Team Requirement:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    Text("This check is required by your team security policy. Please resolve the prerequisite issues to meet compliance requirements.")
                        .font(.body)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionRow(showFix: Bool) -> some View {
        HStack {
            if showFix {
                Button {
                    NSWorkspace.shared.open(check.infoURL)
                } label: {
                    Label("How to fix", systemImage: "wrench.and.screwdriver")
                }
            }
            Spacer()
            if isRechecking {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            Button("Check again", action: recheck)
                .disabled(isRechecking)
        }
    }

    private func recheck() {
        isRechecking = true
        let check = check
        DispatchQueue.global(qos: .userInitiated).async {
            _ = check.run()
            DispatchQueue.main.async {
                // run() skips non-runnable checks, so refresh the view either way
                check.objectWillChange.send()
                isRechecking = false
            }
        }
    }
}

/// Monospaced, selectable details that scroll in a fixed box once they get long.
private struct DetailsText: View {
    let text: String

    private var attributed: AttributedString {
        // Parse inline markdown only, so the one-item-per-line details keep their line breaks
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    private var content: some View {
        Text(attributed)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
            .frame(height: 180)
        }
        .frame(maxHeight: 180)
    }
}

// MARK: - Window vs. sheet presentation

extension View {
    /// In the standalone window the form takes its content height so the window fits it;
    /// the Preferences sheet keeps a fixed minimum and scrolls.
    @ViewBuilder
    func detailWindowSizing(showsHeader: Bool) -> some View {
        if showsHeader {
            frame(minHeight: 400)
        } else {
            // The window already fits the form, so its scroller (shown with "always show scroll bars") is just noise
            fixedSize(horizontal: false, vertical: true)
                .scrollIndicators(.never)
        }
    }

    /// Esc closes the standalone window, as Cancel does for the sheet.
    @ViewBuilder
    func closesWindowOnEscape(_ enabled: Bool) -> some View {
        if enabled {
            background(
                Button("") { NSApp.keyWindow?.performClose(nil) }
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                    .accessibilityHidden(true)
            )
        } else {
            self
        }
    }
}
