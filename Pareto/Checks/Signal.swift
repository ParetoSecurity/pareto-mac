//
//  Signal.swift
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

class AppSignalCheck: AppCheck {
    static let sharedInstance = AppSignalCheck()

    override var appName: String { "Signal" }
    override var appMarketingName: String { "Signal" }
    override var appBundle: String { "org.whispersystems.signal-desktop" }

    override var UUID: String {
        "b621849f-c1ed-5483-ba71-a90968b1fa7b"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://updates.signal.org/desktop/latest-mac.yml"
        let versionRegex = Regex("version: ?([\\.\\d]+)")
        os_log("Requesting %{public}s", url)

        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let yaml = response.value ?? "version: 1.25.0"
                let version = versionRegex.firstMatch(in: yaml)?.groups.first?.value ?? "1.25.0"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                completion("0.0.0")
            }

        })
    }
}
