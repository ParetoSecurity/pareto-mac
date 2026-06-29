//
//  AnyDesk.swift
//  Pareto Security
//
//  Created by Janez Troha on 29/06/2026.
//

import Alamofire
import os.log
import Regex

class AppAnyDeskCheck: AppCheck {
    static let sharedInstance = AppAnyDeskCheck()

    override var appName: String { "AnyDesk" }
    override var appMarketingName: String { "AnyDesk" }
    override var appBundle: String { "com.philandro.anydesk" }

    override var UUID: String {
        "07316cac-018e-595f-bd89-eb894cca7446"
    }

    static func latestMacOSVersion(from response: String) -> String {
        let versionRegex = Regex("([\\d\\.]+) \\(macOS\\)")
        return versionRegex.firstMatch(in: response)?.groups.first?.value ?? "0.0.0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://download.anydesk.com/changelog.txt"
        os_log("Requesting %{public}s", url)
        Network.session.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.data != nil {
                completion(Self.latestMacOSVersion(from: response.value ?? ""))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }

        })
    }
}
