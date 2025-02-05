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

    override func checkPasses() -> Bool {
        let passwordManagers = [
            "1Password.app",
            "1Password 8.app",
            "1Password 7.app",
            "Bitwarden.app",
            "Dashlane.app",
            "KeePassXC.app",
            "KeePassX.app"
        ]

        return checkInstalledApplications(appNames: passwordManagers) || checkForBrowserExtensions()
    }

    private func checkInstalledApplications(appNames: [String]) -> Bool {
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Setapp",
            "\(NSHomeDirectory())/Applications"
        ]

        for path in searchPaths {
            let appDirectory = URL(fileURLWithPath: path)
            if let contents = try? FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil) {
                for app in contents {
                    if appNames.contains(app.lastPathComponent) {
                        os_log(.info, "Found %{public}@", app.lastPathComponent)
                        return true
                    }
                }
            }
        }
        return false
    }

    private func checkForBrowserExtensions() -> Bool {
        let browserExtensions = [
            "LastPass",
            "ProtonPass",
            "NordPass",
            "Bitwarden",
            "1Password",
            "KeePass",
            "Dashlane",
        ]

        let browsers = [
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser"
        ]

        for browser in browsers {
            if let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser) {
                let extensionsPath = browserURL.appendingPathComponent("Extensions").path
                for ext in browserExtensions {
                    if FileManager.default.fileExists(atPath: extensionsPath + "/" + ext) {
                        os_log(.info, "Found %{public}@", ext)
                        return true
                    }
                }
            }
        }

        return false
    }
}
