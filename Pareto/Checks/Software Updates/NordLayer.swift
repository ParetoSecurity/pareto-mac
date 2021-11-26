//
//  NordLayer.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppNordLayerCheck: AppCheck {
    static let sharedInstance = AppNordLayerCheck()

    override var appName: String { "NordLayer" }
    override var appMarketingName: String { "NordLayer" }
    override var appBundle: String { "com.nordvpn.macos.teams" }
    override var sparkleURL: String { "" }

    override var UUID: String {
        "567eb82b-a407-5998-a620-ca8165d74852"
    }

    override var TitleON: String {
        "NordLayer is up-to-date"
    }

    override var TitleOFF: String {
        "NordLayer has an available update"
    }
}
