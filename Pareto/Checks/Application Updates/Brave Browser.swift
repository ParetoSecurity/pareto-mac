//
//  Brave Browser.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//
import Alamofire
import os.log
import Regex
import Version

class AppBraveBrowserCheck: AppCheck {
    static let sharedInstance = AppBraveBrowserCheck()

    override var appName: String {
        "Brave Browser"
    }

    override var appMarketingName: String {
        "Brave Browser"
    }

    override var appBundle: String {
        "com.brave.Browser"
    }

    override var sparkleURL: String {
        "https://updates.bravesoftware.com/sparkle/Brave-Browser/stable/appcast.xml"
    }

    override var UUID: String {
        "64026bd2-54c2-4d3e-8696-559091457dde"
    }

    /// The Brave marketing version (1.99.56.0) does not compare correctly.
    /// Use the build number (sparkle:version). It matches the installed CFBundleVersion.
    static func latestBuildVersion(from appcast: String) -> String {
        let item = appcast.components(separatedBy: "<item>").dropFirst().first ?? appcast
        let buildRegex = Regex("sparkle:version=\"([\\.\\d]+)\"")
        guard let build = buildRegex.firstMatch(in: item)?.groups.first?.value else {
            return "0.0.0"
        }
        return "\(build).0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        os_log("Requesting %{public}s", sparkleURL)
        Network.session.request(sparkleURL).validate().responseString(queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                completion(Self.latestBuildVersion(from: value))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
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
