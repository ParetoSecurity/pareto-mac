//
//  InternetSharing.swift
//  InternetShare
//
//  Created by Janez Troha on 21/09/2021.
//

import Foundation

class InternetShareCheck: ParetoCheck {
    static let sharedInstance = InternetShareCheck()
    override var UUID: String {
        "2ed19e08-6ea7-4c53-b735-321cebefa1b4"
    }

    override var TitleON: String {
        "Sharing internet is off"
    }

    override var TitleOFF: String {
        "Sharing internet is on"
    }

    override func checkPasses() -> Bool {
        guard let dict = readDefaultsFile(path: "/Library/Preferences/SystemConfiguration/com.apple.nat.plist") else {
            // can also be missing if it never changed, but defaults to true
            return true
        }

        guard let nat = dict["NAT"] as? [String: Any] else {
            // If the NAT dictionary is missing, default to passing (off)
            return true
        }

        // NAT Enabled flag (expects 0/1 stored as Int)
        let natDisabled = (nat["Enabled"] as? Int) == 0

        var natPrimaryDisabled = true
        if let primary = nat["PrimaryInterface"] as? [String: Any] {
            natPrimaryDisabled = (primary["Enabled"] as? Int) == 0
        }

        var natAirPortDisabled = true
        if let airport = nat["AirPort"] as? [String: Any] {
            natAirPortDisabled = (airport["Enabled"] as? Int) == 0
        }

        return natDisabled && natAirPortDisabled && natPrimaryDisabled
    }
}
