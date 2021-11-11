//
//  GitHubDesktop.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppGitHubDesktopCheck: ParetoCheck {
    static let sharedInstance = AppGitHubDesktopCheck()

    override var UUID: String {
        "78e2352e-c436-5a90-bbb0-6a08e2c231b3"
    }

    override var TitleON: String {
        "GitHub Desktop is up-to-date"
    }

    override var TitleOFF: String {
        "GitHub Desktop has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "GitHub Desktop") >= ""
    }
}
