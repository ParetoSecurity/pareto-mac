//
//  PasswordtoUnlock.swift
//  PasswordtoUnlock.swift
//
//  Created by Janez Troha on 17/08/2021.
//

import Foundation
import Security

class RequirePasswordToUnlock: ParetoCheck {
    static let sharedInstance = RequirePasswordToUnlock()
    override var UUID: String {
        "f962c423-fdf5-428a-a57a-816abc9b252d"
    }

    override var TitleON: String {
        "Password to unlock preferences"
    }

    override var TitleOFF: String {
        "No password to unlock preferences"
    }

    override var showSettingsWarnEvents: Bool {
        return true
    }

    private let legacyScript = "tell application \"System Events\" to tell security preferences to get require password to unlock"

    // Reads the `system.preferences` authorization right directly. This is the
    // rule the "Require an administrator password to access systemwide settings"
    // toggle writes to, and it works without Apple Events. The System Events
    // `security preferences` suite fails with -10000 on macOS 27.
    private func requiresPasswordFromAuthorizationDB() -> Bool? {
        var rightDefinition: CFDictionary?
        let status = AuthorizationRightGet("system.preferences", &rightDefinition)
        guard status == errAuthorizationSuccess,
              let rule = rightDefinition as? [String: Any]
        else {
            return nil
        }

        // `shared` true means an existing credential is reused, so no password
        // is requested; false means every access has to authenticate.
        if let shared = rule["shared"] as? NSNumber {
            return !shared.boolValue
        }

        // Some systems store a rule reference instead of an inline definition.
        if let ruleNames = rule["rule"] as? [String] {
            return ruleNames.contains { $0.hasPrefix("authenticate") }
        }

        return nil
    }

    override func checkPasses() -> Bool {
        if let required = requiresPasswordFromAuthorizationDB() {
            return required
        }
        // Fallback for systems where the authorization right cannot be read.
        let out = runOSA(appleScript: legacyScript) ?? "false"
        return out.contains("true")
    }

    override var details: String {
        if let required = requiresPasswordFromAuthorizationDB() {
            return "system.preferences authorization right: \(required ? "enabled" : "disabled")"
        }

        let rawOut = runOSA(appleScript: legacyScript)
        let interpreted: String
        if let out = rawOut {
            if out.contains("true") {
                interpreted = "enabled"
            } else if out.contains("false") {
                interpreted = "disabled"
            } else {
                interpreted = "unknown"
            }
        } else {
            interpreted = "error (nil output)"
        }

        // Keep it debug-focused: show raw OSA output and our interpretation.
        return "authorization right unreadable; OSA output: \(rawOut ?? "nil"); interpreted: \(interpreted)"
    }
}
