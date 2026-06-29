//
//  ProtonMail.swift
//  Pareto Security
//
//  Created by Janez Troha on 29/06/2026.
//

import Alamofire
import Foundation
import os.log

struct ProtonMailReleasesResponse: Codable {
    let releases: [ProtonMailRelease]

    enum CodingKeys: String, CodingKey {
        case releases = "Releases"
    }
}

struct ProtonMailRelease: Codable {
    let categoryName: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case categoryName = "CategoryName"
        case version = "Version"
    }
}

class AppProtonMailCheck: AppCheck {
    static let sharedInstance = AppProtonMailCheck()

    override var appName: String { "Proton Mail" }
    override var appMarketingName: String { "Proton Mail" }
    override var appBundle: String { "ch.protonmail.desktop" }

    override var UUID: String {
        "ad898b64-b6ae-5835-aa3c-261dd41d8583"
    }

    static func latestStableVersion(from response: ProtonMailReleasesResponse) -> String {
        response.releases.first { $0.categoryName == "Stable" }?.version ?? "0.0.0"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://proton.me/download/mail/macos/version.json"
        os_log("Requesting %{public}s", url)
        Network.session.request(url).responseDecodable(of: ProtonMailReleasesResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                completion(Self.latestStableVersion(from: value))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion("0.0.0")
            }

        })
    }
}
