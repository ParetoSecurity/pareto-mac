//
//  Tailscale.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppTailscaleCheck: AppCheck {
    static let sharedInstance = AppTailscaleCheck()

    override var appName: String { "Tailscale" }
    override var appMarketingName: String { "Tailscale" }
    override var appBundle: String { "io.tailscale.ipn.macos" }
    override var sparkleURL: String { "" }

    override var UUID: String {
        "3f70f103-2cd1-50f0-a053-5eb91c891ec8"
    }

    override var TitleON: String {
        "Tailscale is up-to-date"
    }

    override var TitleOFF: String {
        "Tailscale has an available update"
    }
}
