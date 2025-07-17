//
//  LibreOffice.swift
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

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    func getLatestVersions(completion: @escaping ([String]) -> Void) {
        let url = viaEdgeCache("https://www.libreoffice.org/download/download/")
        os_log("Requesting %{public}s", url)
        let versionRegex = Regex("<span class=\"dl_version_number\">?([\\.\\d]+)</span>")
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<span class=\"dl_version_number\">1.2.4</span>"
                let versions = versionRegex.allMatches(in: html).map { $0.groups.first?.value ?? "1.2.4" }
                completion(versions)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion(["0.0.0"])
            }
        })
    }

    var latestVersions: [Version] {
        var tempVersions = [Version(0, 0, 0)]
        let lock = DispatchSemaphore(value: 0)
        getLatestVersions { versions in
            tempVersions = versions.map { Version($0) ?? Version(0, 0, 0) }
            lock.signal()
        }
        lock.wait()
        return tempVersions
    }

    override func checkPasses() -> Bool {
        if NetworkHandler.sharedInstance().currentStatus != .satisfied {
            return checkPassed
        }

        for version in latestVersions {
            if currentVersion >= version {
                return true
            }
        }

        return false
    }
}
