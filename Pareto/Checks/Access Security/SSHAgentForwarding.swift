//
//  SSHAgentForwarding.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation

class SSHAgentForwardingCheck: SSHConfigCheck {
    static let sharedInstance = SSHAgentForwardingCheck()

    override var UUID: String {
        "9ff5e3d6-8d56-4c86-9767-b792a856569d"
    }

    override var TitleON: String {
        "SSH agent is not forwarded to all hosts"
    }

    override var TitleOFF: String {
        "SSH agent is forwarded to all hosts"
    }

    /// Any value other than "no" ("yes", a socket path or $VAR) forwards an agent.
    override class func passes(settings: [String: String]) -> Bool? {
        settings["forwardagent"].map { $0 == "no" }
    }
}
