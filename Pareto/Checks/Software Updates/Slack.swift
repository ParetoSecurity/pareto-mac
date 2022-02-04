//
//  Slack.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import os.log
import Regex

class AppSlackCheck: AppCheck {
    static let sharedInstance = AppSlackCheck()

    override var appName: String { "Slack" }
    override var appMarketingName: String { "Slack" }
    override var appBundle: String { "com.tinyspeck.slackmacgap" }

    override var UUID: String {
        "9894a05b-964d-5c19-bef7-53112207d271"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://slack.com/release-notes/mac")
        let versionRegex = Regex("<h2>Slack ?([\\.\\d]+)</h2>")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<h2>Slack 1.23.0</h2>"
                let version = versionRegex.firstMatch(in: html)?.groups.first?.value ?? "1.23.0"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
