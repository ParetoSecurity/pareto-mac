//
//  Docker.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import Foundation
import os.log
import OSLog
import Regex
import Version

class AppDockerCheck: AppCheck {
    static let sharedInstance = AppDockerCheck()

    override var appName: String { "Docker" }
    override var appMarketingName: String { "Docker" }
    override var appBundle: String { "com.docker.docker" }

    override var UUID: String {
        "ee11fe36-a372-5cba-a1b4-151748fc2fa7"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://raw.githubusercontent.com/docker/docker.github.io/master/desktop/mac/release-notes/index.md")
        let versionRegex = Regex("## Docker Desktop ([\\d.]+)")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.data != nil {
                let result = versionRegex.firstMatch(in: response.value ?? "")
                completion(result?.groups.first?.value ?? "0.0.0")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
