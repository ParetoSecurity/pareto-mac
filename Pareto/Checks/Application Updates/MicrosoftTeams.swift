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

// MARK: - Welcome

struct TeamsResponse: Codable {
    let buildSettings: BuildSettings?
}

// MARK: - BuildSettings

struct BuildSettings: Codable {
    let webView2: WebView2?
}

// MARK: - WebView2

struct WebView2: Codable {
    let macOS: MACOSClass?
}

// MARK: - MACOSClass

struct MACOSClass: Codable {
    let latestVersion: String?
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
        let url = viaEdgeCache("https://config.teams.microsoft.com/config/v1/MicrosoftTeams/1415_1.0.0.0?environment=prod&audienceGroup=general&teamsRing=general&agent=TeamsBuilds")

        os_log("Requesting %{public}s", url)
        AF.request(url).responseDecodable(of: TeamsResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let v = response.value?.buildSettings?.webView2?.macOS?.latestVersion
                completion(v ?? "0.0.0")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
    }
}
