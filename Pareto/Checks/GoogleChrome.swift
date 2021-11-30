//
//  GoogleChrome.swift
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
import SwiftyJSON
import Version

class AppGoogleChromeCheck: AppCheck {
    static let sharedInstance = AppGoogleChromeCheck()

    override var appName: String { "Google Chrome" }
    override var appMarketingName: String { "Google Chrome" }
    override var appBundle: String { "com.google.Chrome" }

    override var UUID: String {
        "d34ee340-67a7-5e3e-be8b-aef4e3133de0"
    }

    override var TitleON: String {
        "Google Chrome is up-to-date"
    }

    override var TitleOFF: String {
        "Google Chrome has an available update"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://versionhistory.googleapis.com/v1/chrome/platforms/mac/channels/stable/versions"
        os_log("Requesting %{public}s", url)
        AF.request(url).responseJSON(queue: AppCheck.queue, completionHandler: { response in
            do {
                if response.data != nil {
                    let json = try JSON(data: response.data!)
                    let version = json["versions"][0]["version"].string
                    os_log("%{public}s version=%{public}s", self.appBundle, version ?? "0.0.0")
                    completion(version ?? "0.0.0")
                } else {
                    completion("0.0.0")
                }
            } catch {
                completion("0.0.0")
            }
        })
    }
}
