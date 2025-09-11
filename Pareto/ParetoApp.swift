//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Defaults
import Foundation
import LaunchAtLogin
import OSLog
import SwiftUI

private enum AppWindowID {
    static let welcome = "welcome"
}

class AppDelegate: AppHandlers, NSApplicationDelegate {
    func applicationDidBecomeActive(_: Notification) {
        if hideWhenNoFailures {
            // With MenuBarExtra there is no NSStatusItem visibility to toggle.
            // If you later add a bindable `isMenuBarInserted` in AppHandlers, call updateHiddenState() to adjust it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [self] in
                if statusBarModel.state == .idle {
                    updateHiddenState()
                }
            }
        }
    }

    func moveToApplicationsFolderIfNeeded() {
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let destinationPath = "/Applications/\(bundlePath.components(separatedBy: "/").last!)"

        // Ensure that the destination does not already exist
        if fileManager.fileExists(atPath: destinationPath) {
            try? fileManager.removeItem(atPath: destinationPath)
        }

        do {
            try AppUpdater.safeCopyBundle(from: bundlePath, to: destinationPath)
            print("Moved app to /Applications")
            // Clean up original bundle after successful copy
            try? fileManager.removeItem(atPath: bundlePath)
        } catch {
            print("Failed to copy the app: \(error)")
        }
        exit(0) // Terminate old instance
    }

    func applicationWillFinishLaunching(_: Notification) {
        if CommandLine.arguments.contains("-export") {
            var export: [String: [String: [String]]] = [:]

            for claim in Claims.global.all {
                // skip empty claims
                if claim.checks.count == 0 {
                    continue
                }
                var claimExport: [String: [String]] = [:]
                for check in claim.checksSorted {
                    claimExport[check.UUID] = [check.TitleON, check.TitleOFF]
                }
                export[claim.title] = claimExport
            }

            let jsonEncoder = JSONEncoder()
            let jsonData = try! jsonEncoder.encode(export)
            let json = String(data: jsonData, encoding: String.Encoding.utf8)
            print(json! as String)
            exit(0)
        }

        if CommandLine.arguments.contains("-update") {
            moveToApplicationsFolderIfNeeded()
        }

        if CommandLine.arguments.contains("-report") {
            // invalidate possible expired cache
            try! AppInfo.versionStorage.removeAll()

            for claim in Claims.global.all {
                claim.configure()
                for check in claim.checksSorted {
                    check.run()
                    print(check.report + "\n")
                }
            }
            exit(0)
        }
        if CommandLine.arguments.contains("-report-json") {
            // invalidate possible expired cache
            try! AppInfo.versionStorage.removeAll()
            print("[")
            for claim in Claims.global.all {
                claim.configure()
                for check in claim.checksSorted {
                    check.run()
                    print(check.reportJSON + ",\n")
                }
            }
            print("]")
            exit(0)
        }

        if CommandLine.arguments.contains("-mdmTeam") {
            if !Defaults[.teamAuth].isEmpty {
                print("Team license already active")
                exit(0)
            }

            var inviteParam = CommandLine.arguments.last ?? ""

            if inviteParam.isEmpty {
                print("Missing team invite parameter")
                exit(0)
            }

            var inviteID = ""
            if inviteParam.starts(with: "paretosecurity://") {
                let url = URL(string: inviteParam)!
                inviteID = url.queryParams()["invite_id"] ?? ""

                if inviteID.isEmpty {
                    print("Missing invite_id parameter in URL")
                    exit(0)
                }
            } else {
                // Assume the parameter is the invite ID directly
                inviteID = inviteParam
            }

            print("Enrolling device with invite ID")
            enrolledHandler = true

            Team.enrollDevice(inviteID: inviteID) { result in
                switch result {
                case .success(let (authToken, teamID)):
                    Defaults[.teamAuth] = authToken
                    Defaults[.teamID] = teamID
                    Defaults[.reportingRole] = .team
                    Defaults[.userID] = ""
                    LaunchAtLogin.isEnabled = true

                    print("Device successfully enrolled and linked to team: \(teamID)")
                    Defaults[.lastCheck] = 1
                    exit(0)
                case let .failure(error):
                    print("Device enrollment failed: \(error.localizedDescription)")
                    Defaults.toOpenSource()
                    exit(1)
                }
            }
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            processAction(url)
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            // disable any other code if in preview mode
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return
            }
        #endif

        // Clear the updates cache on app start
        UpdateService.shared.clearCache()

        // Terminate any older versions of process if not running tests
        #if !DEBUG
            if !AppInfo.isRunningTests {
                let procs = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
                if procs.count > 1 {
                    procs.first?.forceTerminate()
                }
            }
        #endif

        // No StatusBarController anymore; configure checks directly
        configureChecks()

        #if DEBUG
            // don't do anything else if running tests
            if AppInfo.isRunningTests {
                return
            }
        #endif

        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        runApp()
    }
}

@main
struct Pareto: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar UI
        MenuBarExtra(isInserted: .constant(true)) {
            StatusBarMenuView(statusBarModel: appDelegate.statusBarModel)
                .environmentObject(appDelegate as AppHandlers)
        } label: {
            StatusBarIcon(statusBarModel: appDelegate.statusBarModel)
        }

        // Welcome window managed by SwiftUI, replacing custom AppKit window controller
        WindowGroup("Welcome", id: AppWindowID.welcome) {
            WelcomeView()
                .environmentObject(appDelegate as AppHandlers)
                .frame(minWidth: 380, idealWidth: 380, maxWidth: 480,
                       minHeight: 520, idealHeight: 520, maxHeight: 700)
                // Capture openWindow environment here and install it into AppHandlers
                .background(InstallOpenWindow { id in
                    if #available(macOS 13.0, *) {
                        if id == AppWindowID.welcome {
                            // This is just a placeholder; real open happens via environment action inside InstallOpenWindow
                        }
                    }
                })
        }
        .defaultPosition(.center)
        .defaultSize(width: 380, height: 520)

        // Settings window
        Settings {
            SettingsView(selected: SettingsView.Tabs.general)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}

// Helper view to inject the openWindow action into AppHandlers
private struct InstallOpenWindow: View {
    @Environment(\.openWindow) private var openWindow
    let didSet: (String) -> Void

    init(_ didSet: @escaping (String) -> Void) {
        self.didSet = didSet
    }

    var body: some View {
        Color.clear
            .onAppear {
                // Provide a closure to AppHandlers so @objc showWelcome can call it.
                (NSApp.delegate as? AppHandlers)?.openWindowHandler = { id in
                    if #available(macOS 13.0, *) {
                        openWindow(id: id)
                    }
                }
                didSet(AppWindowID.welcome)
            }
    }
}

// MARK: - Welcome window opener from AppHandlers

extension AppHandlers {
    // A stored handler that SwiftUI installs so AppKit callers can open windows by id
    @MainActor
    @objc func showWelcome() {
        if #available(macOS 13.0, *) {
            // Call into the injected SwiftUI opener if available
            if let opener = openWindowHandler {
                opener(AppWindowID.welcome)
                return
            }
        }
        // Fallback for macOS 12: present a temporary AppKit window hosting the view
        DispatchQueue.main.async {
            let hostingController = NSHostingController(rootView: WelcomeView())
            let welcomeSize = NSSize(width: 380, height: 520)
            hostingController.preferredContentSize = welcomeSize
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome"
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.setContentSize(welcomeSize)
            window.contentMinSize = welcomeSize
            window.center()
            let wc = NSWindowController(window: window)
            wc.showWindow(nil)
        }
    }

    // Storage for the SwiftUI openWindow bridge
    // Declare this in an extension to avoid touching your existing class layout elsewhere.
    private struct OpenWindowKey {
        static var key = "openWindowHandlerKey"
    }

    var openWindowHandler: ((String) -> Void)? {
        get {
            objc_getAssociatedObject(self, &OpenWindowKey.key) as? ((String) -> Void)
        }
        set {
            objc_setAssociatedObject(self, &OpenWindowKey.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
