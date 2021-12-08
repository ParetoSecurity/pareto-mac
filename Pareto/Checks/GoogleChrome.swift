//
//  GoogleChrome.swift
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
import SwiftyJSON
import Version

class AppGoogleChromeCheck: AppCheck {
    static let sharedInstance = AppGoogleChromeCheck()

    override var appName: String { "Google Chrome" }
    override var appMarketingName: String { "Google Chrome" }
    override var appBundle: String { "com.google.Chrome" }

    override var UUID: String {
        "d34ee340-67a7-5e3e-be8b-aef4e3133de0"
    }

    // Special treatment follows
    // Use build number as definite version comparator
    // https://www.chromium.org/developers/version-numbers

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://versionhistory.googleapis.com/v1/chrome/platforms/mac/channels/stable/versions"
        os_log("Requesting %{public}s", url)
        AF.request(url).responseJSON(queue: AppCheck.queue, completionHandler: { response in
            do {
                if response.data != nil {
                    let json = try JSON(data: response.data!)
                    let version = json["versions"][0]["version"].string ?? "2.3.4.5"
                    let v = version.split(separator: ".")
                    os_log("%{public}s version=%{public}s", self.appBundle, version)
                    completion("\(v[0]).\(v[1]).\(v[2])")
                } else {
                    completion("0.0.0")
                }
            } catch {
                completion("0.0.0")
            }
        })
    }
}