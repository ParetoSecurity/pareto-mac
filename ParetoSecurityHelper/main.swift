//
//  main.swift
//  HelperTool
//
//  Created by Alin Lupascu on 2/25/25.
//

import Foundation
import Security

/// Static version constant for helper tool
private let helperToolVersion = "1.0.4"

/// Bundle identifiers of the apps allowed to talk to the helper (direct and SetApp builds).
private let allowedClientIdentifiers = ["niteo.co.Pareto", "niteo.co.Pareto-setapp"]

/// Team that signed this helper, nil for an ad-hoc signed local build.
private func ownTeamIdentifier() -> String? {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
    var info: CFDictionary?
    let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
    guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
          let info = info as? [String: Any]
    else {
        return nil
    }
    return info[kSecCodeInfoTeamIdentifier as String] as? String
}

/// Code signing requirement every client must meet: one of the Pareto apps, signed by Apple for the same
/// team as this helper. An ad-hoc signed local build has no team to pin to, so there only the identifier
/// is checked; only someone who built and installed the helper themselves runs one.
private let clientRequirement: String = {
    let identifiers = allowedClientIdentifiers.map { "identifier \"\($0)\"" }.joined(separator: " or ")
    guard let team = ownTeamIdentifier() else {
        return "(\(identifiers))"
    }
    return "anchor apple generic and (\(identifiers)) and certificate leaf[subject.OU] = \"\(team)\""
}()

/// XPC Communication setup
class HelperToolDelegate: NSObject, NSXPCListenerDelegate, ParetoSecurityHelperProtocol {
    /// Accept new XPC connections by setting up the exported interface and object.
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("Helper: New XPC connection request received from pid %d", newConnection.processIdentifier)
        // Messages from a client that does not meet the requirement are dropped and the connection invalidated
        newConnection.setCodeSigningRequirement(clientRequirement)
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

    private func runCMD(app: String, args: [String], environment: [String: String]? = nil) -> String {
        NSLog("Helper: runCMD starting: %@ %@", app, args.joined(separator: " "))
        let pipe = Pipe()
        let task = Process()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.executableURL = URL(fileURLWithPath: app)
        if let environment {
            task.environment = environment
        }

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

    /// Lists the sudo privileges of the user on the other end of the XPC connection. Running as root,
    /// `sudo -l -U` needs no authentication, so unlike probing sudo as the user it leaves no failed attempt
    /// in the system log. The user is taken from the connection, never from the caller, so a client can
    /// only learn its own privileges.
    func sudoPrivileges(with reply: @escaping (String) -> Void) {
        NSLog("Helper: sudoPrivileges called")
        guard let uid = NSXPCConnection.current()?.effectiveUserIdentifier,
              uid != 0,
              let entry = getpwuid(uid),
              let name = String(validatingCString: entry.pointee.pw_name),
              !name.isEmpty, !name.hasPrefix("-")
        else {
            NSLog("Helper: sudoPrivileges could not resolve the calling user")
            reply("Failed to resolve calling user")
            return
        }
        let out = runCMD(
            app: "/usr/bin/sudo",
            args: ["-n", "-l", "-U", name],
            environment: ["LC_ALL": "C", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        )
        NSLog("Helper: sudoPrivileges completed for uid %d", uid)
        reply(out)
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
NSLog("Helper: Accepting clients that satisfy: %@", clientRequirement)
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: "co.niteo.ParetoSecurityHelper")
listener.delegate = delegate
NSLog("Helper: Resuming listener")
listener.resume()
NSLog("Helper: Listener resumed, starting run loop")
RunLoop.main.run()
