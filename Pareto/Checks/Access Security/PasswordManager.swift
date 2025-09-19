import AppKit
import Foundation
import os.log

class PasswordManager: ParetoCheck {
    static let sharedInstance = PasswordManager()

    override var UUID: String {
        "f962c423-fdf5-428a-a57a-827abc9b253e"
    }

    override var TitleON: String {
        "Password manager is installed"
    }

    override var TitleOFF: String {
        "Password manager is not installed"
    }

    // Centralized password manager definitions
    private enum PasswordManagerData {
        static let runningAppNames = [
            "1Password",
            "1Password 8",
            "1Password 7",
            "Bitwarden",
            "Dashlane",
            "KeePassXC",
            "KeePassX",
            "KeePassium",
            "LastPass",
            "RoboForm",
            "Enpass",
            "NordPass",
            "Keeper Password Manager",
            "Keeper",
        ]

        static let installedAppNames = [
            "1Password.app",
            "1Password 8.app",
            "1Password 7.app",
            "Bitwarden.app",
            "Dashlane.app",
            "KeePassXC.app",
            "KeePassX.app",
            "KeePassium.app",
        ]

        static let browserExtensions = [
            "hdokiejnpimakedhajhdlcegeplioahd": "LastPass",
            "ghmbeldphafepmbegfdlkpapadhbakde": "ProtonPass",
            "eiaeiblijfjekdanodkjadfinkhbfgcd": "NordPass",
            "nngceckbapebfimnlniiiahkandclblb": "Bitwarden",
            "aeblfdkhhhdcdjpifhhbdiojplfjncoa": "1Password",
            "fdjamakpfbbddfjaooikfcpapjohcfmg": "Dashlane",
            "pejdijmoenmkgeppbflobdenhhabjlaj": "Apple Passwords",
        ]

        static let browsers = [
            "Google/Chrome/Default/": "Chrome",
            "BraveSoftware/Brave-Browser/Default/": "Brave",
            "Microsoft Edge/Default/": "Edge",
            "Arc/User Data/Default/": "Arc",
        ]

        static let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Setapp",
            NSString(string: "~/Applications").expandingTildeInPath,
        ]
    }

    // Results structure for debug info
    private struct ScanResults {
        var runningApps: [String] = []
        var installedApps: [(String, String)] = [] // (name, path)
        var browserExtensions: [(String, String, String)] = [] // (browser, extension, name)
    }

    override func checkPasses() -> Bool {
        let results = performScan()
        return !results.runningApps.isEmpty || !results.installedApps.isEmpty || !results.browserExtensions.isEmpty
    }

    override func debugInfo() -> String {
        let results = performScan()
        var debug = "Password Manager Scan Results:\n\n"

        debug += "=== RUNNING PROCESSES ===\n"
        if results.runningApps.isEmpty {
            debug += "No password manager processes found running.\n"
        } else {
            for app in results.runningApps {
                debug += "✓ \(app) (running)\n"
            }
        }

        // Show all running processes for debugging
        debug += "\nAll running processes (for debugging):\n"
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let appName = app.localizedName {
                let isPasswordManager = PasswordManagerData.runningAppNames.contains(appName)
                debug += "\(isPasswordManager ? "✓" : "  ") \(appName)\n"
            }
        }

        debug += "\n=== INSTALLED APPLICATIONS ===\n"
        if results.installedApps.isEmpty {
            debug += "No password manager applications found installed.\n"
        } else {
            for (name, path) in results.installedApps {
                debug += "✓ \(name) at \(path)\n"
            }
        }

        // Show all apps in search paths for debugging
        debug += "\nAll applications found in search paths:\n"
        for path in PasswordManagerData.searchPaths {
            let appDirectory = URL(fileURLWithPath: path)
            debug += "\nPath: \(path)\n"
            if let contents = try? FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil) {
                let sortedContents = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
                for app in sortedContents where app.pathExtension == "app" {
                    let isPasswordManager = PasswordManagerData.installedAppNames.contains(app.lastPathComponent)
                    debug += "\(isPasswordManager ? "✓" : "  ") \(app.lastPathComponent)\n"
                }
            } else {
                debug += "  (directory not accessible)\n"
            }
        }

        debug += "\n=== BROWSER EXTENSIONS ===\n"
        if results.browserExtensions.isEmpty {
            debug += "No password manager browser extensions found.\n"
        } else {
            for (browser, extensionId, name) in results.browserExtensions {
                debug += "✓ \(name) (\(extensionId)) in \(browser)\n"
            }
        }

        // Show browser extension paths for debugging
        debug += "\nBrowser extension paths checked:\n"
        if let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for (browserPath, browserName) in PasswordManagerData.browsers {
                let extensionsPath = appSupportDirectory.appendingPathComponent(browserPath).appendingPathComponent("Extensions").path
                debug += "\n\(browserName): \(extensionsPath)\n"

                if FileManager.default.fileExists(atPath: extensionsPath) {
                    if let extensionDirs = try? FileManager.default.contentsOfDirectory(atPath: extensionsPath) {
                        for extensionDir in extensionDirs.sorted() {
                            if let extensionName = PasswordManagerData.browserExtensions[extensionDir] {
                                debug += "  ✓ \(extensionDir) (\(extensionName))\n"
                            } else {
                                debug += "    \(extensionDir)\n"
                            }
                        }
                    }
                } else {
                    debug += "  (path does not exist)\n"
                }
            }
        }

        debug += "\n=== SEARCH PATHS ===\n"
        for path in PasswordManagerData.searchPaths {
            let exists = FileManager.default.fileExists(atPath: path)
            debug += "\(exists ? "✓" : "✗") \(path)\n"
        }

        debug += "\n=== LOOKUP TABLES ===\n"
        debug += "Known password manager process names (\(PasswordManagerData.runningAppNames.count)):\n"
        for name in PasswordManagerData.runningAppNames.sorted() {
            debug += "  - \(name)\n"
        }

        debug += "\nKnown password manager app names (\(PasswordManagerData.installedAppNames.count)):\n"
        for name in PasswordManagerData.installedAppNames.sorted() {
            debug += "  - \(name)\n"
        }

        debug += "\nKnown browser extension IDs (\(PasswordManagerData.browserExtensions.count)):\n"
        for (id, name) in PasswordManagerData.browserExtensions.sorted(by: { $0.value < $1.value }) {
            debug += "  - \(name): \(id)\n"
        }

        return debug
    }

    private func performScan() -> ScanResults {
        var results = ScanResults()

        // Scan running processes
        results.runningApps = getRunningPasswordManagers()

        // Scan installed applications
        results.installedApps = getInstalledPasswordManagers()

        // Scan browser extensions
        results.browserExtensions = getBrowserExtensions()

        return results
    }

    private func getRunningPasswordManagers() -> [String] {
        var found: [String] = []
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            if let appName = app.localizedName {
                if PasswordManagerData.runningAppNames.contains(appName) {
                    found.append(appName)
                }
            }
        }

        return found
    }

    private func getInstalledPasswordManagers() -> [(String, String)] {
        var found: [(String, String)] = []

        for path in PasswordManagerData.searchPaths {
            let appDirectory = URL(fileURLWithPath: path)
            if let contents = try? FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil) {
                for app in contents where PasswordManagerData.installedAppNames.contains(app.lastPathComponent) {
                    found.append((app.lastPathComponent, app.path))
                    os_log(.info, "Found %{public}@", app.lastPathComponent)
                }
            }
        }

        return found
    }

    private func getBrowserExtensions() -> [(String, String, String)] {
        var found: [(String, String, String)] = []

        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return found
        }

        for (browserPath, browserName) in PasswordManagerData.browsers {
            let extensionsPath = appSupportDirectory.appendingPathComponent(browserPath).appendingPathComponent("Extensions").path

            for (extensionId, extensionName) in PasswordManagerData.browserExtensions where FileManager.default.fileExists(atPath: extensionsPath + "/" + extensionId) {
                found.append((browserName, extensionId, extensionName))
                os_log(.info, "Found %{public}@ %{public}@", browserName, extensionId)
            }
        }

        return found
    }

    // Legacy methods for backward compatibility
    func isPasswordManagerRunning() -> Bool {
        return !getRunningPasswordManagers().isEmpty
    }

    private func checkInstalledApplications() -> Bool {
        return !getInstalledPasswordManagers().isEmpty
    }

    private func checkForBrowserExtensions() -> Bool {
        return !getBrowserExtensions().isEmpty
    }
}
