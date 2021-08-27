//
//  Bundle.swift
//  Bundle
//
//  Created by Janez Troha on 27/08/2021.
//

import Foundation

extension Bundle {
    var isCodeSigned: Bool {
        return !runCMD(app: "/usr/bin/codesign", args: ["-dv", bundlePath]).contains("Error")
    }

    var codeSigningIdentity: String? {
        let lines = runCMD(app: "/usr/bin/codesign", args: ["-dvvv", bundlePath]).split(separator: "\n")
        for line in lines {
            if line.hasPrefix("Authority=") {
                return String(line.dropFirst(10))
            }
        }
        return nil
    }
}
