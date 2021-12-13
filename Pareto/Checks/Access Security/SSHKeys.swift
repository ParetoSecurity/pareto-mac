//
//  Gatekeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class SSHKeysCheck: ParetoCheck {
    static let sharedInstance = SSHKeysCheck()
    private let sshPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
    private var sshKey = ""

    override var UUID: String {
        "ef69f752-0e89-46e2-a644-310429ae5f45"
    }

    override var TitleON: String {
        "All SSH keys require a password"
    }

    override var TitleOFF: String {
        if sshKey.isEmpty {
            return "One of SSH keys is missing password"
        }
        return "The \(sshKey) SSH key is missing password"
    }

    func itExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    override var isRunnable: Bool {
        if !itExists("/usr/bin/ssh-keygen") {
            os_log("Not found /usr/bin/ssh-keygen, check disabled")
        }
        if !itExists(sshPath.path) {
            os_log("Not found ~/.ssh, check disabled")
        }
        return itExists("/usr/bin/ssh-keygen") && itExists(sshPath.path) && isActive
    }

    func isPasswordEnabled(withKey path: String) -> Bool {
        let output = runCMD(app: "/usr/bin/ssh-keygen", args: ["-P", "''", "-y", "-f", path])
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
                    os_log("Checking %{public}s", pub.path)
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
