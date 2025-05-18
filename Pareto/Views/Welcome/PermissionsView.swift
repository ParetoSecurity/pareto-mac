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
            Spacer(minLength: 30)
            HStack {
                VStack(alignment: .leading) {
                    Text("System Events Access").font(.title3)
                    Text("App requires read-only access to system events so that it can react on connectivity changes, settings changes, and to run checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote)
                }

                Button(action: authorizeOSAClick, label: {
                    if checker.ran {
                        if checker.osaAuthorized {
                            Text("Authorized").frame(width: 70)
                        } else {
                            Text("Authorize").frame(width: 70)
                        }
                    } else {
                        Text("Verifying").frame(width: 70)
                    }
                }).disabled(checker.osaAuthorized)

            }.frame(width: 350, alignment: .leading)
            HStack {
                VStack(alignment: .leading) {
                    Text("Full Disk Access").font(.title3)
                    Text("App requires full disk access if you want to use the Time Machine checks. [Learn more](https://paretosecurity.com/docs/mac/permissions)").font(.footnote)
                }
                Button(action: authorizeFDAClick, label: {
                    if checker.ran {
                        if checker.fdaAuthorized {
                            Text("Authorized").frame(width: 70)
                        } else {
                            Text("Authorize").frame(width: 70)
                        }
                    } else {
                        Text("Verifying").frame(width: 70)
                    }
                }).disabled(checker.fdaAuthorized)

            }.frame(width: 350, alignment: .leading)
            Spacer(minLength: 40)
            Button("Continue") {
                step = Steps.Checks
            }.buttonStyle(HighlightButtonStyle(color: checker.osaAuthorized ? .mainColor : .systemGray)).padding(10).disabled(!checker.osaAuthorized)
        }.frame(width: 380, height: 430, alignment: .center).padding(10).onAppear {
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
