//
//  LuLu.swift
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

class AppLuLuCheck: AppCheck {
    static let sharedInstance = AppLuLuCheck()

    override var appName: String { "LuLu" }
    override var appMarketingName: String { "LuLu" }
    override var appBundle: String { "com.objective-see.lulu.app" }

    override var UUID: String {
        "1b282abb-888b-4f82-bba4-db8ce46a8e2a"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://objective-see.com/products/changelogs/LuLu.txt")
        let versionRegex = Regex("VERSION ([\\.\\d]+) ")
        os_log("Requesting %{public}s", url)

        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let txt = response.value ?? "VERSION 1.4.1 (11/01/2021)"
                let version = versionRegex.firstMatch(in: txt)?.groups.first?.value ?? "1.4.1"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
