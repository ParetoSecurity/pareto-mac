//
//  Slack.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import os.log
import Regex

class AppSlackCheck: AppCheck {
    static let sharedInstance = AppSlackCheck()

    override var appName: String { "Slack" }
    override var appMarketingName: String { "Slack" }
    override var appBundle: String { "com.tinyspeck.slackmacgap" }

    override var UUID: String {
        "9894a05b-964d-5c19-bef7-53112207d271"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        // If installed from the app store, assume it's managed via releases API
        getLatestVersionAppStore(completion: completion)
    }
}
