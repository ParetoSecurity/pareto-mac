//
//  Brave Browser.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//
import Version

class AppBraveBrowserCheck: AppCheck {
    static let sharedInstance = AppBraveBrowserCheck()

    override var appName: String { "Brave Browser" }
    override var appMarketingName: String { "Brave Browser" }
    override var appBundle: String { "com.brave.Browser" }
    override var sparkleURL: String { viaEdgeCache("https://updates.bravesoftware.com/sparkle/Brave-Browser/stable/appcast.xml") }

    var UUID: String {
        "64026bd2-54c2-4d3e-8696-559091457dde"
    }

    // Special treatment follows
    // Use build number as definite version comparator
    // https://www.chromium.org/developers/version-numbers

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath!, key: "CFBundleVersion")!

        return Version("\(v).0") ?? Version(0, 0, 0)
    }
}
