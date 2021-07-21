//
//  VPNConnection.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import os.log
import CFNetwork

class VPNConnectionCheck: ParetoCheck {
    final var ID = "c55ad77c-992f-4043-9be2-e3fb71c51d60"
    final var TITLE = "Connected over VPN"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        guard let cfProxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let proxySettings = cfProxySettings as? [String: AnyObject],
              let connectedInterfaces = proxySettings["__SCOPED__"] as? [String: AnyObject] else { return false}
        var vpnPresent = false
        connectedInterfaces.keys.forEach { interface in
            if interface.hasPrefix("ipsec") {
                vpnPresent =  true
            }
        }
        return vpnPresent
    }
}

