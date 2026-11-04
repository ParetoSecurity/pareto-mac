//
//  SSHHostKeyVerification.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation

class SSHHostKeyVerificationCheck: SSHConfigCheck {
    static let sharedInstance = SSHHostKeyVerificationCheck()

    override var UUID: String {
        "79c330c4-5365-4070-b0bd-ffdbd32cca49"
    }

    override var TitleON: String {
        "SSH verifies host keys"
    }

    override var TitleOFF: String {
        "SSH skips host key verification"
    }

    /// ssh -G prints "false" for StrictHostKeyChecking no or off.
    override class func passes(settings: [String: String]) -> Bool? {
        settings["stricthostkeychecking"].map { $0 != "false" }
    }
}
