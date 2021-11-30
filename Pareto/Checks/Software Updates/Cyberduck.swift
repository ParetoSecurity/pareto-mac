//
//  Cyberduck.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppCyberduckCheck: AppCheck {
    static let sharedInstance = AppCyberduckCheck()

    override var appName: String { "Cyberduck" }
    override var appMarketingName: String { "Cyberduck" }
    override var appBundle: String { "ch.sudo.cyberduck" }
    override var sparkleURL: String { "https://version.cyberduck.io//changelog.rss" }

    override var UUID: String {
        "765b6f80-7a20-5d60-a8c4-013ea360c28e"
    }
}
