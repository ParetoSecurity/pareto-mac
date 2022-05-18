//
//  AirDrop.swift
//  AirDrop
//
//  Created by Janez Troha on 21/09/2021.
//

import Foundation

class AirDropCheck: ParetoCheck {
    static let sharedInstance = AirDropCheck()
    override var UUID: String {
        "58e8267b-05eb-490a-9c91-77ac6499af8f"
    }

    override var TitleON: String {
        "AirDrop is secured"
    }

    override var TitleOFF: String {
        "AirDrop is not secured"
    }

    override func checkPasses() -> Bool {
        // Contacts Only is the default
        let discoverableMode = readDefaultsNative(path: "com.apple.sharingd", key: "DiscoverableMode") ?? "Contacts Only"
        if discoverableMode.contains("Contacts Only") {
            return true
        }
        if discoverableMode.contains("Off") {
            return true
        }
        return false
    }
}
