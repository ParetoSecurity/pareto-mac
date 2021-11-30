//
//  iTerm.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppiTermCheck: AppCheck {
    static let sharedInstance = AppiTermCheck()

    override var appName: String { "iTerm" }
    override var appMarketingName: String { "iTerm2" }
    override var appBundle: String { "com.googlecode.iterm2" }
    override var sparkleURL: String { "https://iterm2.com/appcasts/final_modern.xml" }

    override var UUID: String {
        "1a925bda-7c49-52de-a970-a84b53ea2d7b"
    }

    override var TitleON: String {
        "iTerm is up-to-date"
    }

    override var TitleOFF: String {
        "iTerm has an available update"
    }
}
