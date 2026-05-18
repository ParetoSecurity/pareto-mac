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
import Version

// MARK: - Welcome

struct TeamsResponse: Codable {
    let buildSettings: BuildSettings?

    enum CodingKeys: String, CodingKey {
        case buildSettings = "BuildSettings"
    }
}

// MARK: - BuildSettings

struct BuildSettings: Codable {
    let webView2: WebView2?
    let webView2Canary: WebView2?

    enum CodingKeys: String, CodingKey {
        case webView2 = "WebView2"
        case webView2Canary = "WebView2Canary"
    }
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
    override var appBundle: String { "com.microsoft.teams2" }

    override var UUID: String {
        "a0fb7240-191e-4d27-84bd-175f2b61bec1"
    }

    static func normalizedVersion(_ version: String) -> String {
        version.split(separator: ".").prefix(3).joined(separator: ".")
    }

    static func latestMacOSVersion(from response: TeamsResponse) -> String? {
        response.buildSettings?.webView2Canary?.macOS?.latestVersion ?? response.buildSettings?.webView2?.macOS?.latestVersion
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let version = appVersion(path: applicationPath!) ?? "0.0.0"
        return Version(Self.normalizedVersion(version)) ?? Version(0, 0, 0)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://config.teams.microsoft.com/config/v1/MicrosoftTeams/1415_1.0.0.0?environment=prod&audienceGroup=general&teamsRing=general&agent=TeamsBuilds")

        os_log("Requesting %{public}s", url)
        Network.session.request(url).responseDecodable(of: TeamsResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let v = response.value.flatMap(Self.latestMacOSVersion)
                completion(Self.normalizedVersion(v ?? "0.0.0"))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }
        })
    }
}
