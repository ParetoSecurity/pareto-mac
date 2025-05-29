//
//  ParetoSecurityHelper.swift
//  ParetoSecurityHelper
//
//  Created by Janez Troha on 23. 5. 25.
//

import Foundation

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class ParetoSecurityHelper: NSObject, ParetoSecurityHelperProtocol {
    // MARK: - Helper Functions

    private func runCMD(app: String, args: [String]) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.launchPath = app
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
    }

    // MARK: - Protocol Implementation

    func isFirewallEnabled(with reply: @escaping (Bool) -> Void) {
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
        let enabled = out.contains("State = 1") || out.contains("State = 2")
        reply(enabled)
    }

    func isFirewallStealthEnabled(with reply: @escaping (Bool) -> Void) {
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        let enabled = out.contains("enabled") || out.contains("mode is on")
        reply(enabled)
    }
}
