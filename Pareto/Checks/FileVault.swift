//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import IOKit
import os.log

class FileVaultCheck: ParetoCheck {
    final var ID = "c3aee29a-f16d-4573-a861-b3ba0d860067"
    final var TITLE = "FileVault is on"

    required init(id _: String! = "", title _: String! = "") {
        super.init(id: ID, title: TITLE)
        canRunInSandbox = false
    }

    override func checkPasses() -> Bool {
        let output = runCMD(app: "/usr/bin/fdesetup", args: ["status"])
        return output.contains("FileVault is On")
    }
}
