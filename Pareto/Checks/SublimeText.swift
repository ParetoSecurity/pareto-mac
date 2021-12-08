//
//  SublimeText.swift
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
import SwiftyJSON
import Version

class AppSublimeTextCheck: AppCheck {
    static let sharedInstance = AppSublimeTextCheck()

    override var appName: String { "Sublime Text" }
    override var appMarketingName: String { "Sublime Text" }
    override var appBundle: String { "com.sublimetext.4" }

    override var UUID: String {
        "0ae675c9-1fbe-5fcc-8e4a-c0f53f4d8b4d"
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let version = appVersion(path: applicationPath ?? "Build 3121")!.split(separator: " ")[1]
        return Version("\(version.prefix(1)).\(version.suffix(3)).0") ?? Version(0, 0, 0)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://www.sublimetext.com/download"
        let versionRegex = Regex("Build (\\d+)")
        os_log("Requesting %{public}s", url)

        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let yaml = response.value ?? "Build 3121"
                let version = versionRegex.firstMatch(in: yaml)?.groups.first?.value ?? "3121"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion("\(version.prefix(1)).\(version.suffix(3)).0")
            } else {
                completion("0.0.0")
            }

        })
    }
}
