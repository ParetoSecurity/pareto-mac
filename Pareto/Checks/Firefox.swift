//
//  Firefox.swift
//  Pareto Security
//
//  Created by Janez Troha on 30/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Version


struct FirefoxVersions: Decodable {
    let LATEST_FIREFOX_VERSION: String
}

class AppFirefoxCheck: AppCheck {
    static let sharedInstance = AppFirefoxCheck()

    override var appName: String { "Firefox" }
    override var appMarketingName: String { "Firefox" }
    override var appBundle: String { "org.mozilla.firefox" }

    override var UUID: String {
        "768a574c-75a2-536d-8785-ef9512981184"
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath!)!.split(separator: ".")
        if v.count == 2 {
            return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, 0)
        }
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://product-details.mozilla.org/1.0/firefox_versions.json")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseDecodable(of: FirefoxVersions.self, queue: AppCheck.queue) { response in
            if response.error == nil {
                let version = response.value?.LATEST_FIREFOX_VERSION ?? "0.0.0"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }
        }
    }
}
