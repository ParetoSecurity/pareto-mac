//
//  Gatekeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Defaults
import Foundation
import os.log

class SSHKeysCheck: SSHCheck {
    static let sharedInstance = SSHKeysCheck()

    override var UUID: String {
        "ef69f752-0e89-46e2-a644-310429ae5f45"
    }

    override var TitleON: String {
        "SSH keys require a password"
    }

    override var TitleOFF: String {
        return "SSH key is missing a password"
    }

    override var details: String {
        let keys = keysWithNoPassword()
        if keys.isEmpty {
            return "None"
        }
        return keys.map { "- \($0)" }.joined(separator: "\n")
    }

    func isPasswordEnabled(withKey path: String) -> Bool {
        let output = runCMD(app: getSSHKeygenPath(), args: ["-P", "''", "-y", "-f", path])
        return output.contains("incorrect passphrase supplied")
    }

    func keysWithNoPassword() -> [String] {
        var keys: [String] = []
        let ignored = Defaults[.ignoredSSHKeys]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sshPath, includingPropertiesForKeys: nil).filter { $0.pathExtension == "pub" }
            for pub in files {
                let privateKey = pub.path.replacingOccurrences(of: ".pub", with: "")
                let baseName = pub.deletingPathExtension().lastPathComponent
                // Skip ignored keys by base filename
                if ignored.contains(baseName) {
                    continue
                }
                if !itExists(privateKey) {
                    continue
                }
                if !isPasswordEnabled(withKey: privateKey) {
                    os_log("Checking %{public}s", log: Log.check, pub.absoluteURL.path)
                    keys.append(privateKey)
                }
            }
        } catch {
            os_log("Failed to check SSH keys %{public}s", error.localizedDescription)
        }
        return keys
    }

    override func checkPasses() -> Bool {
        if !hasPrerequites() {
            return true
        }

        return keysWithNoPassword().isEmpty
    }
}
