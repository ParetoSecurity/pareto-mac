//
//  ProtonVPN.swift
//  Pareto Security
//
//  Created by Janez Troha on 29/06/2026.
//

class AppProtonVPNCheck: AppCheck {
    static let sharedInstance = AppProtonVPNCheck()

    override var appName: String { "ProtonVPN" }
    override var appMarketingName: String { "Proton VPN" }
    override var appBundle: String { "ch.protonvpn.mac" }
    override var sparkleURL: String { "https://protonvpn.com/download/macos/updates/v5/sparkle.xml" }
    override var excludedSparkleChannel: String? { "beta" }

    override var UUID: String {
        "ef8f7dfc-b7d4-5999-8e66-fb5cf1e5252e"
    }
}
