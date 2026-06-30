//
//  Zoom.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Regex
import Version

class AppZoomCheck: AppCheck {
    static let sharedInstance = AppZoomCheck()

    override var appName: String { "Zoom.us" }
    override var appMarketingName: String { "Zoom" }
    override var appBundle: String { "us.zoom.xos" }

    override var UUID: String {
        "c65cb89b-6c53-54af-995c-ec8ba358ecf6"
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3 (1234)")!.split(separator: " ")
        return Version(v[0]) ?? Version(0, 0, 0)
    }

    static func latestMacOSSlowTrackVersion(from response: String) -> String {
        let versionRegex = Regex("<tr[^>]*>\\s*<td>.*?>macOS</a></td><td>([\\d\\.]+)</td><td>([\\d\\.]+)</td>")
        return versionRegex.firstMatch(in: response)?.groups.dropFirst().first?.value ?? "0.0.0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0061900"
        os_log("Requesting %{public}s", url)

        Network.session.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let version = Self.latestMacOSSlowTrackVersion(from: response.value ?? "")
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }

        })
    }
}
