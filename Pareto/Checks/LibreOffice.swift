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
import Regex
import Version

class AppLibreOfficeCheck: AppCheck {
    static let sharedInstance = AppLibreOfficeCheck()

    override var appName: String { "LibreOffice" }
    override var appMarketingName: String { "LibreOffice" }
    override var appBundle: String { "org.libreoffice.script" }

    override var UUID: String {
        "5726931a-264a-5758-b7dd-d09285ac4b7f"
    }

    // Special treatment follows
    // Use build number as definite version comparator

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://www.libreoffice.org/download/download/"
        os_log("Requesting %{public}s", url)
        let versionRegex = Regex("<span class=\"dl_version_number\">?([\\.\\d]+)</span>")
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let yaml = response.value ?? "<span class=\"dl_version_number\">1.2.4</span>"
                let version = versionRegex.firstMatch(in: yaml)?.groups.first?.value ?? "1.2.4"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                completion("0.0.0")
            }
        })
    }
}
