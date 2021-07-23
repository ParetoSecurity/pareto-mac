//
//  VPNConnection.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import NetUtils
import os.log

class VPNConnectionCheck: ParetoCheck {
    final var ID = "c55ad77c-992f-4043-9be2-e3fb71c51d60"
    final var TITLE = "Connected over VPN"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let monitor = Interface.allInterfaces()
        var vpnPresent = false
        monitor.forEach { interface in
            if interface.name.hasPrefix("ipsec") {
                vpnPresent = interface.isRunning && interface.isUp
            }
            if interface.name.hasPrefix("utun") {
                vpnPresent = interface.isRunning && interface.isUp
            }
        }
        return vpnPresent
    }
}
