//
//  InternetShare.swift
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
        if let dict = readDefaultsFile(path: "/Library/Preferences/SystemConfiguration/com.apple.nat.plist") {
            if let NAT = (dict.value(forKey: "NAT") as? NSDictionary) {
                let natPrimaryDisabled = (NAT.value(forKey: "PrimaryInterface") as! NSDictionary).value(forKey: "Enabled") as! Int == 0
                let natAirPortDisabled = (NAT.value(forKey: "AirPort") as! NSDictionary).value(forKey: "Enabled") as! Int == 0
                let natDisabled = NAT.value(forKey: "Enabled") as! Int == 0
                return natDisabled && natAirPortDisabled && natPrimaryDisabled
            }
        }
        // can also be missing if it never changed, but defaults to true
        return true
    }
}
