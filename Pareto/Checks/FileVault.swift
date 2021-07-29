//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class FileVaultCheck: ParetoCheck {
    final var ID = "c3aee29a-f16d-4573-a861-b3ba0d860067"
    final var TITLE = "FileVault is active"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let output = runCMD(app: "/usr/bin/fdesetup", args: ["status"])
        return output.contains("FileVault is On")
    }
}
