import Defaults
import SwiftUI

struct NoUnusedUsersDetailView: View {
    @ObservedObject var check: ParetoCheck
    @Environment(\.dismiss) var dismiss
    @State private var isActive: Bool
    @State private var hasChanges: Bool = false
    /// Sheets need their own Cancel/Done header; a standalone window has a title bar and close button instead.
    private let showsHeader: Bool
    @Default(.ignoredUserAccounts) var ignoredUserAccounts

    init(check: ParetoCheck, showsHeader: Bool = true) {
        _check = ObservedObject(wrappedValue: check)
        self.showsHeader = showsHeader
        _isActive = State(initialValue: check.isActive)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                // Header
                HStack {
                    Button("Cancel") {
                        // Revert changes if any
                        if hasChanges {
                            check.isActive = !isActive
                        }
                        dismiss()
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Text(check.TitleON)
                        .font(.headline)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding()

                Divider()
            }

            // Content
            Form {
                Section {
                    if check.teamEnforced {
                        HStack {
                            Text("✴")
                                .foregroundColor(.orange)
                            Text("This check is required by your team")
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Enable this check", isOn: $isActive)
                        .disabled(!check.showSettings || check.teamEnforced)
                        .onChange(of: isActive) { newValue in
                            check.isActive = newValue
                            hasChanges = true
                        }
                }

                Section(header: Text("Description")) {
                    Text("This check ensures that unused user accounts (non-admin accounts) are either removed or have logged in recently.")
                        .font(.body)

                    Text("When failing: \(check.TitleOFF)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // infoURL embeds live check details (can mean re-reading files), so build it on click only
                    Button("Learn more about this check →") {
                        NSWorkspace.shared.open(check.infoURL)
                    }
                    .buttonStyle(.link)
                    .font(.footnote)
                    .padding(.top, 4)
                }

                Section(header: Text("Ignored User Accounts")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configure which user accounts to exclude from this check. This is useful for service accounts that don't log in regularly.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        IgnoredUsersSettingsView()
                            .padding(.vertical, 4)
                    }
                }

                CheckStatusSection(
                    check: check,
                    statusDetails: check.cachedDetails,
                    shouldShowDetails: !check.cachedDetails.isEmpty && check.cachedDetails != "None"
                )
            }
            .formStyle(.grouped)
            .detailWindowSizing(showsHeader: showsHeader)
        }
        .frame(width: 550)
        .closesWindowOnEscape(!showsHeader)
    }
}
