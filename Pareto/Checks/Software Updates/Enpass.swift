//
//  Enpass.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppEnpassCheck: AppCheck {
    static let sharedInstance = AppEnpassCheck()

    override var appName: String { "Enpass" }
    override var appMarketingName: String { "" }
    override var appBundle: String { "in.sinew.Enpass-Desktop" }
    override var sparkleURL: String { "" }

    override var UUID: String {
        "ca6c8ed7-6d22-5342-908a-f010e3eb102f"
    }

    override var TitleON: String {
        "Enpass is up-to-date"
    }

    override var TitleOFF: String {
        "Enpass has an available update"
    }
}
