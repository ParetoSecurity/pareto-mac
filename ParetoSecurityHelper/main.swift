//
//  main.swift
//  HelperTool
//
//  Created by Alin Lupascu on 2/25/25.
//

import Foundation

// XPC Communication setup
class HelperToolDelegate: NSObject, NSXPCListenerDelegate, ParetoSecurityHelperProtocol {
    // Accept new XPC connections by setting up the exported interface and object.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ParetoSecurityHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    private func runCMD(app: String, args: [String]) -> String {
        let pipe = Pipe()
        let task = Process()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.executableURL = URL(fileURLWithPath: app)
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return "Failed to run command: \(error.localizedDescription)"
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? "No output" : output
    }
    
    // MARK: - Protocol Implementation
    
    func isFirewallEnabled(with reply: @escaping (String) -> Void) {
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
        reply(out)
    }
    
    func isFirewallStealthEnabled(with reply: @escaping (String) -> Void) {
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        reply(out)
    }
}

// Set up and start the XPC listener.
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: "co.niteo.ParetoSecurityHelper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
