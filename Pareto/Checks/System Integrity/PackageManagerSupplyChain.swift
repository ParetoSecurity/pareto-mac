//
//  PackageManagerSupplyChain.swift
//  Pareto Security
//
//  Created by Codex on 12/05/2026.
//

import Foundation

class PackageManagerSupplyChainCheck: ParetoCheck {
    static let sharedInstance = PackageManagerSupplyChainCheck()

    let homeDirectory: URL
    let installedBinaries: Set<String>?
    let environment: [String: String]

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        installedBinaries: Set<String>? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.installedBinaries = installedBinaries
        self.environment = environment
    }

    override var UUID: String {
        "61bf7ef7-a3ee-4d66-a859-49c3ebeb1e7f"
    }

    override var TitleON: String {
        "Package managers delay new releases"
    }

    override var TitleOFF: String {
        "Package managers install new releases immediately"
    }

    override var isRunnable: Bool {
        return isActive && hasPackageManagerConfigOrBinary()
    }

    override var showInMenu: Bool {
        return isActive && hasPackageManagerConfigOrBinary()
    }

    override var showDetailsWhenPassing: Bool {
        return true
    }

    override var details: String {
        let failures = validationFailures()
        if failures.isEmpty {
            return passingDetails()
        }
        return failures.map { "- \($0)" }.joined(separator: "\n")
    }

    override func checkPasses() -> Bool {
        return validationFailures().isEmpty
    }

    func validationFailures() -> [String] {
        let npmrc = homeDirectory.appendingPathComponent(".npmrc")
        let pnpm = pnpmConfigPath()
        let bunfig = homeDirectory.appendingPathComponent(".bunfig.toml")
        let uv = homeDirectory.appendingPathComponent(".config/uv/uv.toml")
        let pypirc = homeDirectory.appendingPathComponent(".pypirc")
        var failures: [String] = []

        if let contents = readFile(npmrc) {
            failures.append(contentsOf: Self.validateNpmrc(contents))
        } else if isBinaryInstalled("npm") || isBinaryInstalled("yarn") {
            failures.append("~/.npmrc is missing")
        }
        if let contents = readFile(pnpm) {
            failures.append(contentsOf: Self.validatePnpmConfig(contents, displayPath: pnpmConfigDisplayPath()))
        } else if isBinaryInstalled("pnpm") {
            failures.append("\(pnpmConfigDisplayPath()) is missing")
        }
        if let contents = readFile(bunfig) {
            failures.append(contentsOf: Self.validateBunfig(contents))
        } else if isBinaryInstalled("bun") {
            failures.append("~/.bunfig.toml is missing")
        }
        if let contents = readFile(uv) {
            failures.append(contentsOf: Self.validateUv(contents))
        } else if isBinaryInstalled("uv") {
            failures.append("~/.config/uv/uv.toml is missing")
        }
        if let contents = readFile(pypirc) {
            failures.append(contentsOf: Self.validatePypirc(contents))
        }

        return failures
    }

    private func passingDetails() -> String {
        var details: [String] = []

        if let contents = readFile(homeDirectory.appendingPathComponent(".npmrc")), Self.validateNpmrc(contents).isEmpty {
            details.append("~/.npmrc delays npm-compatible package releases and pins exact versions")
        }
        if let contents = readFile(pnpmConfigPath()), Self.validatePnpmConfig(contents, displayPath: pnpmConfigDisplayPath()).isEmpty {
            details.append("\(pnpmConfigDisplayPath()) delays pnpm package releases")
        }
        if let contents = readFile(homeDirectory.appendingPathComponent(".bunfig.toml")), Self.validateBunfig(contents).isEmpty {
            details.append("~/.bunfig.toml delays Bun package releases")
        }
        if let contents = readFile(homeDirectory.appendingPathComponent(".config/uv/uv.toml")), Self.validateUv(contents).isEmpty {
            details.append("~/.config/uv/uv.toml excludes Python packages newer than 7 days")
        }
        if let contents = readFile(homeDirectory.appendingPathComponent(".pypirc")), Self.validatePypirc(contents).isEmpty {
            details.append("~/.pypirc has no plaintext credentials")
        }

        if details.isEmpty {
            return "No package manager config or binary was found"
        }
        return details.map { "- \($0)" }.joined(separator: "\n")
    }

    private func hasPackageManagerConfigOrBinary() -> Bool {
        let configFiles = [
            homeDirectory.appendingPathComponent(".npmrc"),
            pnpmConfigPath(),
            homeDirectory.appendingPathComponent(".bunfig.toml"),
            homeDirectory.appendingPathComponent(".config/uv/uv.toml"),
            homeDirectory.appendingPathComponent(".pypirc"),
        ]
        if configFiles.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return true
        }
        return ["yarn", "npm", "pnpm", "bun", "uv"].contains(where: isBinaryInstalled)
    }

    private func isBinaryInstalled(_ name: String) -> Bool {
        if let installedBinaries {
            return installedBinaries.contains(name)
        }
        let output = runCMD(app: "/usr/bin/which", args: [name]).trimmingCharacters(in: .whitespacesAndNewlines)
        return !output.isEmpty
    }

    private func readFile(_ url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func pnpmConfigPath() -> URL {
        if let xdgConfigHome = xdgConfigHome() {
            return URL(fileURLWithPath: xdgConfigHome).appendingPathComponent("pnpm/config.yaml")
        }
        return homeDirectory.appendingPathComponent("Library/Preferences/pnpm/config.yaml")
    }

    private func pnpmConfigDisplayPath() -> String {
        if xdgConfigHome() != nil {
            return "$XDG_CONFIG_HOME/pnpm/config.yaml"
        }
        return "~/Library/Preferences/pnpm/config.yaml"
    }

    private func xdgConfigHome() -> String? {
        guard let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty else {
            return nil
        }
        guard (xdgConfigHome as NSString).isAbsolutePath else {
            return nil
        }
        return (xdgConfigHome as NSString).standardizingPath
    }

    static func validateNpmrc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        var failures: [String] = []

        if integerValue(values["min-release-age"]) ?? 0 < 7 {
            failures.append("~/.npmrc min-release-age is below 7 days")
        }
        if integerValue(values["minimum-release-age"]) ?? 0 < 10080 {
            failures.append("~/.npmrc minimum-release-age is below 10080 minutes")
        }
        if values["save-exact"]?.lowercased() != "true" {
            failures.append("~/.npmrc save-exact is not enabled")
        }

        return failures
    }

    static func validatePnpmConfig(_ contents: String, displayPath: String) -> [String] {
        let values = keyValuePairs(contents)
        let minimumReleaseAge = integerValue(values["minimumreleaseage"]) ?? integerValue(values["minimum-release-age"]) ?? 0

        if minimumReleaseAge < 10080 {
            return ["\(displayPath) minimumReleaseAge is below 10080 minutes"]
        }
        return []
    }

    static func validateBunfig(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let minimumReleaseAge = integerValue(values["install.minimumReleaseAge"]) ?? 0

        if minimumReleaseAge < 604800 {
            return ["~/.bunfig.toml minimumReleaseAge is below 604800 seconds"]
        }
        return []
    }

    static func validateUv(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let seconds = durationSeconds(values["pip.exclude-newer"]) ?? 0

        if seconds < 604800 {
            return ["~/.config/uv/uv.toml exclude-newer is below 7 days"]
        }
        return []
    }

    static func validatePypirc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        let credentialKeys = ["password", "token", "api-token"]

        for key in credentialKeys where values[key]?.isEmpty == false {
            return ["~/.pypirc contains plaintext credentials"]
        }
        return []
    }

    private static func keyValuePairs(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = stripComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let separator = trimmed.firstIndex(of: "=") ?? trimmed.firstIndex(of: ":")
            guard let separator else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let valueStart = trimmed.index(after: separator)
            let value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = unquote(value)
        }

        return values
    }

    private static func tomlKeyValuePairs(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]
        var section = ""

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = stripComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                section = String(trimmed.dropFirst().dropLast())
                continue
            }
            guard let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = trimmed.index(after: separator)
            let value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            let fullKey = section.isEmpty ? String(key) : "\(section).\(key)"
            values[fullKey] = unquote(value)
        }

        return values
    }

    private static func integerValue(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(unquote(value))
    }

    private static func durationSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        let normalized = unquote(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let seconds = Int(normalized) {
            return seconds
        }
        let number = String(normalized.prefix { $0.isNumber })
        let suffix = String(normalized.dropFirst(number.count))
        guard let amount = Int(number) else { return nil }

        switch suffix {
        case "s":
            return amount
        case "m":
            return amount * 60
        case "h":
            return amount * 3600
        case "d":
            return amount * 86400
        case "w":
            return amount * 604800
        default:
            return nil
        }
    }

    private static func stripComment(_ line: String) -> String {
        var isQuoted = false
        var result = ""

        for character in line {
            if character == "\"" {
                isQuoted.toggle()
            }
            if !isQuoted, character == "#" || character == ";" {
                break
            }
            result.append(character)
        }

        return result
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
        }
        if trimmed.hasPrefix("'"), trimmed.hasSuffix("'") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }
}
