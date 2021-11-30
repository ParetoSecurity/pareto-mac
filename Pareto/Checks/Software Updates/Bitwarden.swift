//
//  Bitwarden.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppBitwardenCheck: AppCheck {
    static let sharedInstance = AppBitwardenCheck()

    override var appName: String { "Bitwarden" }
    override var appMarketingName: String { "Bitwarden" }
    override var appBundle: String { "com.bitwarden.desktop" }

    override var UUID: String {
        "42e4fce2-b34f-5220-990a-33ba64e9ffa0"
    }
}
