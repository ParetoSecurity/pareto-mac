//
//  main.swift
//  HelperTool
//
//  Created by Alin Lupascu on 2/25/25.
//

import Foundation

// Static version constant for helper tool
private let helperToolVersion = "1.0.3"

// XPC Communication setup
class HelperToolDelegate: NSObject, NSXPCListenerDelegate, ParetoSecurityHelperProtocol {
    // Accept new XPC connections by setting up the exported interface and object.
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("Helper: New XPC connection request received")
        newConnection.exportedInterface = NSXPCInterface(with: ParetoSecurityHelperProtocol.self)
        newConnection.exportedObject = self

        newConnection.invalidationHandler = {
            NSLog("Helper: XPC connection invalidated")
        }

        newConnection.interruptionHandler = {
            NSLog("Helper: XPC connection interrupted")
        }

        NSLog("Helper: Resuming new XPC connection")
        newConnection.resume()
        NSLog("Helper: XPC connection accepted and resumed")
        return true
    }

    private func runCMD(app: String, args: [String]) -> String {
        NSLog("Helper: runCMD starting: %@ %@", app, args.joined(separator: " "))
        let pipe = Pipe()
        let task = Process()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.executableURL = URL(fileURLWithPath: app)

        do {
            NSLog("Helper: runCMD attempting to run task")
            try task.run()
            NSLog("Helper: runCMD task started, waiting for exit")
            task.waitUntilExit()
            NSLog("Helper: runCMD task exited with status: %d", task.terminationStatus)
        } catch {
            NSLog("Helper: runCMD failed with error: %@", error.localizedDescription)
            return "Failed to run command: \(error.localizedDescription)"
        }

        NSLog("Helper: runCMD reading output data")
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let result = output.isEmpty ? "No output" : output
        NSLog("Helper: runCMD completed with result: %@", result)
        return result
    }

    // MARK: - Protocol Implementation

    func isFirewallEnabled(with reply: @escaping (String) -> Void) {
        NSLog("Helper: isFirewallEnabled called")
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
        NSLog("Helper: isFirewallEnabled completed with output: %@", out)
        reply(out)
        NSLog("Helper: isFirewallEnabled reply sent")
    }

    func isFirewallStealthEnabled(with reply: @escaping (String) -> Void) {
        NSLog("Helper: isFirewallStealthEnabled called")
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        NSLog("Helper: isFirewallStealthEnabled completed with output: %@", out)
        reply(out)
        NSLog("Helper: isFirewallStealthEnabled reply sent")
    }

    func getVersion(with reply: @escaping (String) -> Void) {
        NSLog("Helper: getVersion called")
        NSLog("Helper: getVersion returning static version: %@", helperToolVersion)
        reply(helperToolVersion)
        NSLog("Helper: getVersion reply sent")
    }
}

// Set up and start the XPC listener.
NSLog("Helper: Starting XPC listener for co.niteo.ParetoSecurityHelper")
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: "co.niteo.ParetoSecurityHelper")
listener.delegate = delegate
NSLog("Helper: Resuming listener")
listener.resume()
NSLog("Helper: Listener resumed, starting run loop")
RunLoop.main.run()
