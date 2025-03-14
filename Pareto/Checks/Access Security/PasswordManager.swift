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
        return checkInstalledApplications() || checkForBrowserExtensions()
    }

    private func checkInstalledApplications() -> Bool {
        let passwordManagers = [
            "1Password.app",
            "1Password 8.app",
            "1Password 7.app",
            "Bitwarden.app",
            "Dashlane.app",
            "KeePassXC.app",
            "KeePassX.app",
            "KeePassium.app"
        ]

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
                    if passwordManagers.contains(app.lastPathComponent) {
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
            "hdokiejnpimakedhajhdlcegeplioahd", // LastPass
            "ghmbeldphafepmbegfdlkpapadhbakde", // ProtonPass
            "eiaeiblijfjekdanodkjadfinkhbfgcd", // nordpass
            "nngceckbapebfimnlniiiahkandclblb", // bitwarden
            "aeblfdkhhhdcdjpifhhbdiojplfjncoa", // 1password
            "fdjamakpfbbddfjaooikfcpapjohcfmg" // dashlane
        ]

        let browsers = [
            "Google/Chrome/Default/",
            "BraveSoftware/Brave-Browser/Default/",
            "Microsoft Edge/Default/",
            "Arc/User Data/Default/"
        ]

        for browser in browsers {
            if let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let extensionsPath = appSupportDirectory.appendingPathComponent(browser).appendingPathComponent("Extensions").path
                for ext in browserExtensions {
                    if FileManager.default.fileExists(atPath: extensionsPath + "/" + ext) {
                        os_log(.info, "Found %{public}@ %{public}@", browser, ext)
                        return true
                    }
                }
            }
        }

        return false
    }
}
