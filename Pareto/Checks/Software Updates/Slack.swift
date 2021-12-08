//
//  Slack.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppSlackCheck: AppCheck {
    static let sharedInstance = AppSlackCheck()

    override var appName: String { "Slack" }
    override var appMarketingName: String { "Slack" }
    override var appBundle: String { "com.tinyspeck.slackmacgap" }

    override var UUID: String {
        "9894a05b-964d-5c19-bef7-53112207d271"
    }
}