//
//  WireGuard.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppWireGuardCheck: AppCheck {
    static let sharedInstance = AppWireGuardCheck()

    override var appName: String { "WireGuard" }
    override var appMarketingName: String { "WireGuard" }
    override var appBundle: String { "com.wireguard.macos" }

    override var UUID: String {
        "b0e0e64a-2d8c-50d1-947c-b037773827c9"
    }
}
