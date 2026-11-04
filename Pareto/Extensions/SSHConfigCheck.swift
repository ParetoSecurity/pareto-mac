//
//  SSHConfigCheck.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation
import os.log

class SSHConfigCheck: ParetoCheck {
    static let sshBinaryPath = "/usr/bin/ssh"

    /// Match exec must fail before spawning a shell, including for negated conditions.
    static let sandboxProfile = """
    (version 1)
    (allow default)
    (deny process-exec)
    (deny process-fork)
    (deny network*)
    (deny file-write*)
    (allow file-write* (literal "/dev/null"))
    (allow process-exec (literal "/usr/bin/ssh"))
    """

    let sshConfigProvider: () -> String

    init(sshConfigProvider: @escaping () -> String = { SSHConfigCheck.readSSHConfig() }) {
        self.sshConfigProvider = sshConfigProvider
    }

    class func passes(settings _: [String: String]) -> Bool? {
        fatalError("passes(settings:) is not implemented")
    }

    override func checkPasses() -> Bool {
        let output = sshConfigProvider()
        guard let passes = Self.evaluate(sshG: output) else {
            os_log("Could not read the SSH client configuration: %{public}@", log: Log.check, output)
            hasError = true
            return false
        }
        return passes
    }

    class func evaluate(sshG output: String) -> Bool? {
        passes(settings: settings(fromSSHG: output))
    }

    static func settings(fromSSHG output: String) -> [String: String] {
        var settings: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            guard line.range(of: "^[a-z0-9]+ ", options: .regularExpression) != nil else {
                continue
            }
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                settings[String(parts[0])] = value
            }
        }
        return settings
    }

    static func readSSHConfig(configFile: String? = nil, timeout: TimeInterval = 15) -> String {
        let host = "pareto-probe-\(Foundation.UUID().uuidString.lowercased()).invalid"
        let args = (configFile.map { ["-F", $0] } ?? []) + ["-G", "-oCanonicalizeHostname=no", host]

        let output = OSAllocatedUnfairLock(initialState: "")
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let result = try await runCMDAsync(
                    app: "/usr/bin/sandbox-exec",
                    args: ["-p", sandboxProfile, sshBinaryPath] + args,
                    timeout: timeout,
                    includeStandardError: false,
                    requireSuccessfulExit: true
                )
                output.withLock { $0 = result }
            } catch {
                os_log("ssh -G failed: %{public}@", log: Log.check, error.localizedDescription)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout + 1)
        return output.withLock { $0 }
    }
}
