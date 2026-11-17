//
//  1Password8.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2022.
//
import Alamofire
import os.log
import Regex

class App1Password8Check: AppCheck {
    static let sharedInstance = App1Password8Check()

    override var appName: String {
        "1Password"
    }

    override var appMarketingName: String {
        "1Password"
    }

    override var appBundle: String {
        "com.1password.1password"
    }

    override var UUID: String {
        "0a076668-f8c6-4d53-b275-6806afcddca8"
    }

    static func latestStableVersion(from html: String) -> String {
        // The page shows the newest release first.
        let versionRegex = Regex("1Password for Mac ([\\d\\.]+)</h6>")
        return versionRegex.firstMatch(in: html)?.groups.first?.value ?? "0.0.0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://releases.1password.com/mac/stable/"
        os_log("Requesting %{public}s", url)
        Network.session.request(url).validate().responseString(queue: AppCheck.queue, completionHandler: { response in
            if let html = response.value, response.error == nil {
                completion(Self.latestStableVersion(from: html))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
    }
}
