//
//  MicrosoftTeams.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import Foundation
import os.log
import Regex

extension String {
    func trim() -> String {
        return replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\t", with: "")
    }
}

class AppMicrosoftTeamsCheck: AppCheck {
    static let sharedInstance = AppMicrosoftTeamsCheck()

    override var appName: String { "Microsoft Teams" }
    override var appMarketingName: String { "Microsoft Teams" }
    override var appBundle: String { "com.microsoft.teams" }

    override var UUID: String {
        "a0fb7240-191e-4d27-84bd-175f2b61bec1"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://macadmins.software/latest.xml")
        let packageRegex = Regex("<package>(.*)</package>")
        let versionRegex = Regex("<cfbundleversion>(\\d+)</cfbundleversion>")

        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let fallback = "<package><cfbundleidentifier>com.microsoft.teams</cfbundleidentifier><cfbundleversion>435562</cfbundleversion></package>"
                let html = response.value?.trim() ?? fallback
                let app = packageRegex.allMatches(in: html).filter { $0.value.contains(self.appBundle) }.first
                let version = versionRegex.firstMatch(in: app?.value ?? fallback)?.groups.first?.value ?? "135562"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion("1.00.\(version)")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
