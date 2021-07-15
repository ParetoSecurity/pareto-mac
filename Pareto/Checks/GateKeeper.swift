//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import OSLog

let logger = Logger(subsystem: "checks", category: "GateKeeper")

func isGateKeeperEnabled() -> Bool {
    let path = "/var/db/SystemPolicy-prefs.plist"
    guard let dictionary = NSDictionary(contentsOfFile: path) else {
        logger.error("Unable to get dictionary from path \(path)")
        return false
    }
    if let enabled = dictionary.object(forKey: "enabled") as? String {
        logger.info("enabled: \(enabled)")
        return enabled == "yes"
    }
    logger.error("Unable to find value for key named enabled")
    return false
}

