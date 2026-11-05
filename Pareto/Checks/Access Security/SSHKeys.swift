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
        "SSH key is missing a password"
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
        return Self.isProtected(keygenOutput: output)
    }

    static let securityKeyTypes = ["sk-ssh-ed25519@openssh.com", "sk-ecdsa-sha2-nistp256@openssh.com"]

    static func isProtected(keygenOutput output: String) -> Bool {
        // ssh-keygen also prints a key's comment, so the error only counts at the start of the output
        let encrypted = output.hasPrefix("Load key") && output.contains("incorrect passphrase supplied")
        // A security key file only holds a key handle, the private key never leaves the authenticator
        return encrypted || securityKeyTypes.contains { output.hasPrefix($0 + " ") }
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
