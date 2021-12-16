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
        "bcf5196e-6757-422d-8ac3-99ebdb243afa"
    }

    override var TitleON: String {
        "WiFi connection is secure"
    }

    override var TitleOFF: String {
        "WiFi connection is not secure"
    }

    var isWiFiActive: Bool {
        return CWWiFiClient.shared().interface(withName: nil)?.serviceActive() ?? false
    }

    var isWiFiSecured: Bool {
        return CWWiFiClient.shared().interface(withName: nil)?.security() != CWSecurity.none
    }

    var isRoutedViaVPN: Bool {
        let data = runCMD(app: "/usr/sbin/netstat", args: ["-rnt"])

        for line in data.split(separator: "\n") {
            if line.split(separator: " ").count > 3 {
                let linedata = String(line)
                let regex = try! NSRegularExpression(pattern: " +", options: NSRegularExpression.Options.caseInsensitive)
                let range = NSRange(location: 0, length: linedata.count)
                let normalized = regex.stringByReplacingMatches(in: linedata, options: [], range: range, withTemplate: "\t")
                let info = normalized.split(separator: "\t")
                // most vpns use default gateway as indiation that they route over extension
                if info[0] == "default", info[1].contains("link#") {
                    return true
                }
                // ExpressVPN uses netlink rule to route all traffic over virtual device
                if info[0] == "0/1", info[3].contains("utun") {
                    return true
                }
            }
        }
        return false
    }

    override func checkPasses() -> Bool {
        // Wifi is not active
        if !isWiFiActive {
            return true
        }
        return isWiFiSecured || isRoutedViaVPN
    }
}
