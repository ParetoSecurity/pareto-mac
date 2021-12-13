//
//  SublimeText.swift
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
import SwiftyJSON
import Version

class AppVSCodeCheck: AppCheck {
    static let sharedInstance = AppVSCodeCheck()

    override var appName: String { "Visual Studio Code" }
    override var appMarketingName: String { "Visual Studio Code" }
    override var appBundle: String { "com.microsoft.VSCode" }

    override var UUID: String {
        "febd20fb-3dec-5834-a0ba-58f3342df58c"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://code.visualstudio.com/updates/"
        let versionRegex = Regex("<strong>Update ([\\.\\d]+)</strong>")
        os_log("Requesting %{public}s", url)

        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<strong>Update 1.12.1</strong>"
                let versions = versionRegex.allMatches(in: html).map { $0.groups.first!.value }
                let version = versions.sorted(by: { $0.lowercased() < $1.lowercased() }).last ?? "1.12.1"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
