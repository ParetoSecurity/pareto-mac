//
//  SSHCheck.swift
//  Pareto Security
//
//  Created by Lane Shukhov on 20.02.2023.
//

import Foundation
import os.log

class SSHCheck: ParetoCheck {
    let sshPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh").resolvingSymlinksInPath()
    private var sshKeygenPath = ""

    private var itExistsCache = [String: Bool]()

    func itExists(_ path: String) -> Bool {
        if let cachedResult = itExistsCache[path] {
            return cachedResult
        }
        let exists = FileManager.default.fileExists(atPath: path)
        itExistsCache[path] = exists
        return exists
    }

    func getSSHKeygenPath() -> String {
        if !sshKeygenPath.isEmpty {
            return sshKeygenPath
        }

        if itExists("/opt/homebrew/bin/ssh-keygen") {
            sshKeygenPath = "/opt/homebrew/bin/ssh-keygen"
        } else {
            sshKeygenPath = "/usr/bin/ssh-keygen"
        }

        return sshKeygenPath
    }

    func runKeygen(args: [String], keyPath: String) -> String? {
        let key = URL(fileURLWithPath: keyPath).resolvingSymlinksInPath().path
        let publicKey = URL(fileURLWithPath: keyPath + ".pub").resolvingSymlinksInPath().path
        return CheckCommand.run(app: getSSHKeygenPath(), args: args, readFiles: [key, publicKey],
                                includeStandardError: true, requireSuccessfulExit: false)
    }

    func hasPrerequites() -> Bool {
        if !itExists(getSSHKeygenPath()) {
            os_log("Not found /opt/homebrew/bin/ssh-keygen or /usr/bin/ssh-keygen, check disabled", log: Log.check)
        }
        if !itExists(sshPath.path) {
            os_log("Not found ~/.ssh, check disabled", log: Log.check)
        }
        return itExists(getSSHKeygenPath()) && itExists(sshPath.path)
    }

    override var isRunnable: Bool {
        isActive
    }

    override var prerequisiteFailureDetails: String? {
        if isRunnable {
            return nil
        }

        let sshKeygenPath = getSSHKeygenPath()
        let sshDirPath = sshPath.path

        if !itExists(sshKeygenPath) {
            let checkedPaths = ["/opt/homebrew/bin/ssh-keygen", "/usr/bin/ssh-keygen"]
            return "ssh-keygen command not found. Checked paths:\n" + checkedPaths.map { "- \($0)" }.joined(separator: "\n") + "\n\nThis tool is required to check SSH key security."
        }

        if !itExists(sshDirPath) {
            return "SSH directory not found at \(sshDirPath)\n\nNo SSH keys are configured for this user account."
        }

        return nil
    }
}
