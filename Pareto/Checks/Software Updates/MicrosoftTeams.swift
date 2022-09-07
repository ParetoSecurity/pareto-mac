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
        let url = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=osx&download=true"
        let versionRegex = Regex("x/?([\\.\\d]+)/T") // x/1.5.00.22362/T
        os_log("Requesting %{public}s", url)

        AF.request(url, method: .head).responseString(queue: AppCheck.queue, completionHandler: { response in
            if let url = response.response?.url, response.error == nil {
                let cdn = versionRegex.firstMatch(in: url.description)?.groups.first?.value ?? "1.5.00.22362"
                let nibbles = cdn.components(separatedBy: ".")
                let version = "\(nibbles[0]).00.\(nibbles[1])\(nibbles[nibbles.endIndex - 1])"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
