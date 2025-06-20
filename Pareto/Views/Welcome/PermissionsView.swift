//
//  PermissionsView.swift
//  Pareto Security
//
//  Created by Janez Troha on 09/11/2021.
//

import Foundation
import SwiftUI

class PermissionsChecker: ObservableObject {
    /// The timer
    private var timer: Timer?
    @Published var osaAuthorized = false
    @Published var fdaAuthorized = false
    @Published var firewallAuthorized = false
    @Published var ran = false

    private func osaIsAuthorized() -> Bool {
        let script = "tell application \"System Events\" to tell security preferences to get automatic login"

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            if let _ = scriptObject.executeAndReturnError(&error).stringValue {
                return true
            } else if error != nil {
                return false
            }
        }
        return false
    }

    func start() {
        timer?.invalidate() // cancel timer if any
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.fdaAuthorized = TimeMachineHasBackupCheck.sharedInstance.isRunnable
            self.osaAuthorized = self.osaIsAuthorized()
            self.firewallAuthorized = HelperToolUtilities.isHelperInstalled()
            self.ran = true
        }
    }

    func stop() {
        timer?.invalidate()
    }
}

struct PermissionsView: View {
    @Binding var step: Steps
    @ObservedObject fileprivate var checker = PermissionsChecker()
    
    private var canContinue: Bool {
        // OSA is always required
        guard checker.osaAuthorized else { return false }
        
        // On macOS 15+, firewall access is also required for security checks
        if #available(macOS 15, *) {
            return checker.firewallAuthorized
        }
        
        // Pre-macOS 15, only OSA is required
        return true
    }

    func authorizeOSAClick() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func authorizeFDAClick() {
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDisk")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func authorizeFWClick() async {
        let helperManager = HelperToolManager()
        await helperManager.manageHelperTool(action: .install)
    }

    var body: some View {
        VStack {
            VStack {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60, alignment: .center)
                    .accessibility(hidden: true)

                Text("Configure Permissions").font(.largeTitle)
                Spacer()
                Text("Allow the app read-only access to the system. These permissions do not allow changing or running any of the system settings.").font(.body)
            }.frame(width: 350, alignment: .center).padding(15)
            Spacer(minLength: 20)
            
            VStack(spacing: 20) {
                // System Events Access
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Events Access").font(.title3).fontWeight(.medium)
                        Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Button(action: authorizeOSAClick, label: {
                        if checker.ran {
                            if checker.osaAuthorized {
                                Text("Authorized").frame(width: 80)
                            } else {
                                Text("Authorize").frame(width: 80)
                            }
                        } else {
                            Text("Verifying").frame(width: 80)
                        }
                    })
                    .disabled(checker.osaAuthorized || !checker.ran)
                    .frame(minWidth: 80)
                }
                
                // Full Disk Access
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Disk Access").font(.title3).fontWeight(.medium)
                        Text("App requires full disk access if you want to use the Time Machine checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Button(action: authorizeFDAClick, label: {
                        if checker.ran {
                            if checker.fdaAuthorized {
                                Text("Authorized").frame(width: 80)
                            } else {
                                Text("Authorize").frame(width: 80)
                            }
                        } else {
                            Text("Verifying").frame(width: 80)
                        }
                    })
                    .disabled(checker.fdaAuthorized || !checker.ran)
                    .frame(minWidth: 80)
                }
                
                // Firewall Access (macOS 15+ only)
                if #available(macOS 15, *) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Firewall Access").font(.title3).fontWeight(.medium)
                            Text("App requires read-only access to firewall to perform checks on macOS 15+. [Learn more](https://paretosecurity.com/docs/mac/firewall)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Button(action: { Task { await authorizeFWClick() } }, label: {
                            if checker.ran {
                                if checker.firewallAuthorized {
                                    Text("Authorized").frame(width: 80)
                                } else {
                                    Text("Authorize").frame(width: 80)
                                }
                            } else {
                                Text("Verifying").frame(width: 80)
                            }
                        })
                        .disabled(checker.firewallAuthorized || !checker.ran)
                        .frame(minWidth: 80)
                    }
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 20)
            Spacer(minLength: 40)
            Button("Continue") {
                step = Steps.Checks
            }.buttonStyle(HighlightButtonStyle(color: canContinue ? .mainColor : .systemGray)).padding(10).disabled(!canContinue)
        }.frame(width: 450, height: 500, alignment: .center).padding(15).onAppear {
            checker.start()
        }.onDisappear {
            checker.stop()
        }
    }
}

#if DEBUG
    struct PermissionsViewPreviewsBinding: View {
        @State var step = Steps.Welcome

        var body: some View {
            PermissionsView(step: $step)
        }
    }

    struct PermissionsView_Previews: PreviewProvider {
        static var previews: some View {
            PermissionsViewPreviewsBinding()
        }
    }
#endif
