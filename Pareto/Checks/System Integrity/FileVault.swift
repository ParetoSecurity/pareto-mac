//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

class FileVaultCheck: ParetoCheck {
    override var UUID: String {
        "c3aee29a-f16d-4573-a861-b3ba0d860067"
    }

    override var TitleON: String {
        "FileVault is on"
    }

    override var TitleOFF: String {
        "FileVault is off"
    }

    override func checkPasses() -> Bool {
        let output = runCMD(app: "/usr/bin/fdesetup", args: ["status"])
        return output.contains("FileVault is On")
    }
}
