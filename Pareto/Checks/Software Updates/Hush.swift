//
//  Hush.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppHushCheck: AppCheck {
    static let sharedInstance = AppHushCheck()

    override var appName: String { "Hush" }
    override var appMarketingName: String { "Hush" }
    override var appBundle: String { "se.oblador.Hush" }
    override var sparkleURL: String { "" }

    override var UUID: String {
        "1774a8ba-348c-5b23-909a-028c8498e6ee"
    }

    override var TitleON: String {
        "Hush is up-to-date"
    }

    override var TitleOFF: String {
        "Hush has an available update"
    }
}
