//
//  OpenWIFI.swift
//  Pareto Security
//
//  Created by Janez Troha on 28/09/2021.
//

import CoreWLAN
import Foundation

class OpenWiFiCheck: ParetoCheck {
    static let sharedInstance = OpenWiFiCheck()

    override var UUID: String {
        "bcf5196e-6757-422d-9ac2-99ebdb243afe"
    }

    override var TitleON: String {
        "WiFi connection is secured"
    }

    override var TitleOFF: String {
        "WiFi connection is not secured"
    }

    var isWiFiActive: Bool {
        return CWWiFiClient.shared().interface(withName: nil)?.serviceActive() ?? false
    }

    var isWiFiSecured: Bool {
        return CWWiFiClient.shared().interface(withName: nil)?.security() != CWSecurity.none
    }

    override func checkPasses() -> Bool {
        // Wifi is not active
        if !isWiFiActive {
            return true
        }
        return isWiFiSecured
    }
}
