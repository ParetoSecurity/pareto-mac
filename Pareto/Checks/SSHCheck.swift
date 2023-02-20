//
//  SSHCheck.swift
//  Pareto Security
//
//  Created by Lane Shukhov on 20.02.2023.
//

import Foundation
import os.log

class SSHCheck: ParetoCheck {
    internal let sshPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh").resolvingSymlinksInPath()
    private var sshKeygenPath = ""
    
    func itExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
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
    
    override var isRunnable: Bool {
        if !itExists(getSSHKeygenPath()) {
            os_log("Not found /opt/homebrew/bin/ssh-keygen or /usr/bin/ssh-keygen, check disabled", log: Log.check)
        }
        if !itExists(sshPath.path) {
            os_log("Not found ~/.ssh, check disabled", log: Log.check)
        }
        return itExists(getSSHKeygenPath()) && itExists(sshPath.path) && isActive
    }
}
