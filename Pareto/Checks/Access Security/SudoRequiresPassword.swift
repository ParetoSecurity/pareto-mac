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

    /// Returns the output of `sudo -l -U <current user>`, run as root by the privileged helper.
    let listingProvider: () async -> String
    /// Outer nil: the helper has not answered yet. Inner nil: its answer could not be evaluated.
    private let helperResultLock = OSAllocatedUnfairLock<Bool??>(initialState: nil)
    private let helperCheckInFlight = OSAllocatedUnfairLock(initialState: false)

    init(listingProvider: @escaping () async -> String = SudoRequiresPasswordCheck.fetchListingViaHelper) {
        self.listingProvider = listingProvider
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

    /// Only offered where the privileged helper is already part of onboarding (macOS 15+, for the firewall
    /// checks), so older versions are not asked for a new permission.
    static var isSupported: Bool {
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override var requiresHelper: Bool {
        Self.isSupported
    }

    override var isRunnable: Bool {
        guard Self.isSupported else {
            return false
        }
        if teamEnforced {
            return true
        }
        return isActive && HelperToolUtilities.isHelperInstalled()
    }

    // MARK: - Evaluation

    private enum Section {
        case none, defaults, specificDefaults, commands
    }

    /// Tags that can precede a command in `sudo -l` output, e.g. `(ALL) SETENV: NOPASSWD: ALL`.
    private static let tagPattern = try! NSRegularExpression(
        pattern: "^(NO)?(PASSWD|SETENV|EXEC|LOG_INPUT|LOG_OUTPUT|MAIL|FOLLOW|INTERCEPT):\\s*"
    )

    /// Options that can precede the tags, e.g. `(root) CWD=/tmp NOPASSWD: ALL`.
    private static let optionPattern = try! NSRegularExpression(pattern: "^[A-Z_]+=\\S+\\s+")

    /// Takes the output of `sudo -l -U <user>`. Returns false when sudo lets the user run any command
    /// without a password (`NOPASSWD: ALL` or `!authenticate` for all commands), true when it does not
    /// or the user may not use sudo at all, and nil when the output is not a sudo listing.
    static func evaluate(listing output: String) -> Bool? {
        var section = Section.none
        var sawListing = false
        var noPassword = false

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }

            if line.hasPrefix("Matching Defaults entries for ") {
                section = .defaults
                sawListing = true
                continue
            }
            if line.hasPrefix("Runas and Command-specific defaults for ") {
                section = .specificDefaults
                sawListing = true
                continue
            }
            if line.hasPrefix("User "), line.contains(" may run the following commands on ") {
                section = .commands
                sawListing = true
                continue
            }
            if line.hasPrefix("User "), line.contains(" is not allowed to run sudo on ") {
                section = .none
                sawListing = true
                continue
            }

            // Lines outside a section (warnings from sudo itself) say nothing about the rules
            guard rawLine.first?.isWhitespace == true else {
                section = .none
                continue
            }

            switch section {
            case .none:
                continue
            case .defaults:
                let entries = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if entries.contains("!authenticate") {
                    return false
                }
            case .specificDefaults:
                // Runas-specific defaults and those for every command apply to all commands
                let appliesToAll = line.hasPrefix("Defaults>") || line.hasPrefix("Defaults!ALL ")
                if appliesToAll, line.contains("!authenticate") {
                    return false
                }
            case .commands:
                var rest = line
                if rest.hasPrefix("(") {
                    // A new privilege line starts with its runas spec and resets the inherited tags
                    noPassword = false
                    if let end = rest.firstIndex(of: ")") {
                        rest = String(rest[rest.index(after: end)...])
                    }
                }
                // In order, so NOPASSWD: carries over to the commands after it
                let parts = rest.components(separatedBy: ",")
                if parts.contains(where: { commandRunsWithoutPassword($0, noPassword: &noPassword) }) {
                    return false
                }
            }
        }

        return sawListing ? true : nil
    }

    /// Strips options and tags from one command of a privilege line, updating the inherited NOPASSWD
    /// state, and reports whether the command is `ALL` without a password.
    private static func commandRunsWithoutPassword(_ part: String, noPassword: inout Bool) -> Bool {
        var command = part.trimmingCharacters(in: .whitespaces)
        while true {
            let range = NSRange(command.startIndex..., in: command)
            if let match = optionPattern.firstMatch(in: command, range: range),
               let matchRange = Range(match.range, in: command)
            {
                command.removeSubrange(matchRange)
                continue
            }
            if let match = tagPattern.firstMatch(in: command, range: range),
               let matchRange = Range(match.range, in: command)
            {
                let tag = command[matchRange].trimmingCharacters(in: .whitespaces)
                if tag == "NOPASSWD:" {
                    noPassword = true
                } else if tag == "PASSWD:" {
                    noPassword = false
                }
                command.removeSubrange(matchRange)
                continue
            }
            break
        }
        return noPassword && command == "ALL"
    }

    // MARK: - Running

    override func checkPasses() -> Bool {
        refreshHelperResultIfNeeded()
        // run() clears hasError before calling this, so the error comes from the cached answer
        guard let answer = helperResultLock.withLock({ $0 }) else {
            return checkPassed
        }
        guard let passes = answer else {
            hasError = true
            return false
        }
        return passes
    }

    /// Runs the check and waits for the helper's answer; used by tests and anywhere a fresh result is needed.
    func evaluateNow() async -> Bool? {
        let output = await listingProvider()
        guard let passes = Self.evaluate(listing: output) else {
            os_log("sudo listing could not be evaluated: %{public}@", log: Log.check, output)
            return nil
        }
        return passes
    }

    private func refreshHelperResultIfNeeded() {
        let shouldStart = helperCheckInFlight.withLock { inFlight in
            if inFlight {
                return false
            }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let passes = await evaluateNow()
            helperResultLock.withLock { $0 = .some(passes) }
            helperCheckInFlight.withLock { $0 = false }
        }
    }

    static func fetchListingViaHelper() async -> String {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let helperManager = HelperToolManager()
                guard await helperManager.ensureHelperIsUpToDate() else {
                    continuation.resume(returning: "XPC: Helper tool is not installed")
                    return
                }
                await helperManager.sudoPrivileges { output in
                    continuation.resume(returning: output)
                }
            }
        }
    }
}
