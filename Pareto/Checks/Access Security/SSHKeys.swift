//
//  Gatekeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class SSHKeysCheck: SSHCheck {
    static let sharedInstance = SSHKeysCheck()
    private var sshKey = ""

    override var UUID: String {
        "ef69f752-0e89-46e2-a644-310429ae5f45"
    }

    override var TitleON: String {
        "SSH keys require a password"
    }

    override var TitleOFF: String {
        if sshKey.isEmpty {
            return "SSH key is missing a password"
        }
        return "SSH key \(sshKey) is missing a password"
    }

    func isPasswordEnabled(withKey path: String) -> Bool {
        let output = runCMD(app: getSSHKeygenPath(), args: ["-P", "''", "-y", "-f", path])
        return output.contains("incorrect passphrase supplied")
    }

    override func checkPasses() -> Bool {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sshPath, includingPropertiesForKeys: nil).filter { $0.pathExtension == "pub" }
            for pub in files {
                let privateKey = pub.path.replacingOccurrences(of: ".pub", with: "")
                if !itExists(privateKey) {
                    continue
                }
                if !isPasswordEnabled(withKey: privateKey) {
                    os_log("Checking %{public}s", log: Log.check, pub.absoluteURL.path)
                    sshKey = pub.lastPathComponent.replacingOccurrences(of: ".pub", with: "")
                    return false
                }
            }
            return true
        } catch {
            os_log("Failed to check SSH keys %{public}s", error.localizedDescription)
            return true
        }
    }
}
