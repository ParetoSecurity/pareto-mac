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

    override var appName: String { "1Password" }
    override var appMarketingName: String { "1Password" }
    override var appBundle: String { "com.1password.1password" }

    var UUID: String {
        "0a076668-f8c6-4d53-b275-6806afcddca8"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://releases.1password.com/mac/8.9/"
        let versionRegex = Regex("([\\d\\.]+)</h6>")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.data != nil {
                let result = versionRegex.allMatches(in: response.value ?? "8.9.1")

                completion(result.last?.groups.first?.value ?? "0.0.0")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }

        })
    }
}
