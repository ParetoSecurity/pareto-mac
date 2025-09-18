//
//  OpenWiFi.swift
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

    private func securityDescription(_ security: CWSecurity?) -> String {
        guard let s = security else { return "Unknown" }
        switch s {
        case .none: return "Open (no encryption)"
        case .WEP: return "WEP"
        case .wpaPersonal: return "WPA Personal"
        case .wpaPersonalMixed: return "WPA/WPA2 Personal (mixed)"
        case .wpa2Personal: return "WPA2 Personal"
        case .personal: return "Personal"
        case .dynamicWEP: return "Dynamic WEP"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA/WPA2 Enterprise (mixed)"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .enterprise: return "Enterprise"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA2/WPA3 Personal (transition)"
        case .unknown: return "Unknown"
        case .OWE:
            return "OWE"
        case .oweTransition:
            return "oweTransition"
        @unknown default: return "Unknown"
        }
    }

    override var details: String {
        guard let iface = CWWiFiClient.shared().interface(withName: nil) else {
            return "Could not access Wi‑Fi interface"
        }

        // Not runnable scenario context
        if !isWiFiActive {
            return "Wi‑Fi is not active"
        }

        let ssid = iface.ssid() ?? "Unknown SSID"
        let security = iface.security()
        let securityText = securityDescription(security)

        if isRoutedViaVPN {
            return "Traffic routed via VPN while connected to '\(ssid)' (\(securityText))"
        }

        if security != .none {
            return "Connected to secured Wi‑Fi '\(ssid)' (\(securityText))"
        } else {
            return "Connected to open Wi‑Fi '\(ssid)' without encryption"
        }
    }

    override func checkPasses() -> Bool {
        // Wifi is not active
        if !isWiFiActive {
            return true
        }
        return isWiFiSecured || isRoutedViaVPN
    }
}
