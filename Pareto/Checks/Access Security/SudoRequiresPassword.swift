//
//  SudoRequiresPassword.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation
import os.log

class SudoRequiresPasswordCheck: ParetoCheck {
    static let sharedInstance = SudoRequiresPasswordCheck()

    let isAdminProvider: () -> Bool
    let sudoRunner: () -> String

    init(
        isAdminProvider: @escaping () -> Bool = { NoAdminUser.sharedInstance.isAdmin },
        sudoRunner: @escaping () -> String = {
            runCMD(app: "/usr/bin/sudo", args: ["-k", "-n", "/usr/bin/id", "-u"], environment: ["LC_ALL": "C"])
        }
    ) {
        self.isAdminProvider = isAdminProvider
        self.sudoRunner = sudoRunner
    }

    override var UUID: String {
        "f358454b-5d9b-4c6b-b47f-13b55b17ad0e"
    }

    override var TitleON: String {
        "sudo requires a password"
    }

    override var TitleOFF: String {
        "sudo runs without a password"
    }

    /// Takes the output of `sudo -k -n /usr/bin/id -u` with stderr merged: "0" when sudo ran it without asking,
    /// "sudo: a password is required" when it needs a password, also for users who are not in sudoers.
    /// Returns nil for anything else.
    static func evaluate(output: String) -> Bool? {
        switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "0":
            false
        case "sudo: a password is required":
            true
        default:
            nil
        }
    }

    override func checkPasses() -> Bool {
        // root never needs a password, and sudo mails root on every attempt by a user who is not in sudoers
        guard getuid() != 0, isAdminProvider() else {
            return true
        }
        let output = sudoRunner()
        guard let passes = Self.evaluate(output: output) else {
            os_log("sudo could not be evaluated: %{public}@", log: Log.check, output)
            hasError = true
            return false
        }
        return passes
    }
}
