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
    let packageManagerVersions: [String: String]
    let environment: [String: String]

    /// A release younger than this is considered "too new to trust". Every
    /// per-manager threshold and message derives from this one policy value.
    private static let minimumCooldownSeconds = 604_800
    private static let minimumCooldownDays = minimumCooldownSeconds / 86400
    private static let minimumCooldownMinutes = minimumCooldownSeconds / 60

    /// One entry per package manager: where its user-level cooldown config
    /// lives, which binaries imply it should exist, how to validate it, and
    /// (optionally) the minimum tool version that enforces the setting.
    /// All per-manager behavior flows from this table; the checks below just
    /// iterate it.
    private struct ManagerConfig {
        /// Candidate config files, first match wins.
        let candidates: [(displayPath: String, url: URL)]
        /// Binaries whose presence means the config must exist.
        let binaries: [String]
        /// Validates the file contents; the second argument is the display
        /// path for tools whose message mentions where the config was found.
        let validate: (String, String) -> [String]
        /// Detail used when no candidate config exists, given the first
        /// candidate's display path.
        let missingDetail: (String) -> String
        /// Detail used when the config passes, given the matched display path.
        let passingDetail: (String) -> String
        /// Set when only newer tool versions actually enforce the setting.
        var versionGate: (minimumVersion: String, configDescription: String)?
        /// The gate only makes sense once the cooldown key is present.
        var usesSetting: ((String) -> Bool)?
    }

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        installedBinaries: Set<String>? = nil,
        packageManagerVersions: [String: String] = [:],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.installedBinaries = installedBinaries
        self.packageManagerVersions = packageManagerVersions
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
        isActive && hasPackageManagerConfigOrBinary()
    }

    override var showInMenu: Bool {
        isActive && hasPackageManagerConfigOrBinary()
    }

    override var showDetailsWhenPassing: Bool {
        true
    }

    override var details: String {
        let failures = validationFailures()
        if failures.isEmpty {
            return passingDetails()
        }
        return failures.map { "- \($0)" }.joined(separator: "\n")
    }

    override func checkPasses() -> Bool {
        validationFailures().isEmpty
    }

    func validationFailures() -> [String] {
        var failures: [String] = []

        for manager in managers {
            guard let active = activeConfig(in: manager) else {
                if manager.binaries.contains(where: isBinaryInstalled) {
                    failures.append(manager.missingDetail(manager.candidates[0].displayPath))
                }
                continue
            }

            var managerFailures = manager.validate(active.contents, active.displayPath)
            if let gate = manager.versionGate, managerFailures.isEmpty,
               manager.usesSetting?(active.contents) == true,
               let binary = manager.binaries.first(where: isBinaryInstalled)
            {
                managerFailures = addingVersionGate(
                    managerFailures,
                    binary: binary,
                    minimumVersion: gate.minimumVersion,
                    configDescription: gate.configDescription
                )
            }
            failures.append(contentsOf: managerFailures)
        }

        return failures
    }

    private func passingDetails() -> String {
        var details: [String] = []

        for manager in managers {
            if let active = activeConfig(in: manager), manager.validate(active.contents, active.displayPath).isEmpty {
                details.append(manager.passingDetail(active.displayPath))
            }
        }

        if details.isEmpty {
            return "No package manager config or binary was found"
        }
        return details.map { "- \($0)" }.joined(separator: "\n")
    }

    private func hasPackageManagerConfigOrBinary() -> Bool {
        let configPaths = managers.flatMap { $0.candidates.map(\.url) }
        if configPaths.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return true
        }
        return managers.flatMap(\.binaries).contains(where: isBinaryInstalled)
    }

    private func isBinaryInstalled(_ name: String) -> Bool {
        if let installedBinaries {
            return installedBinaries.contains(name)
        }
        return executablePath(for: name) != nil
    }

    private func packageManagerVersion(_ name: String) -> String? {
        if let version = packageManagerVersions[name] {
            return version.isEmpty ? nil : version
        }
        guard let path = executablePath(for: name) else { return nil }
        // Most of these binaries are `#!/usr/bin/env node` wrappers, so they
        // need a PATH that also resolves their runtime.
        var childEnvironment = environment
        childEnvironment["PATH"] = searchDirectories().joined(separator: ":")
        let output = runCMD(app: path, args: ["--version"], environment: childEnvironment)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }

    // Resolves a binary against a fixed list of well-known install prefixes. A
    // LaunchServices-launched app inherits only the launchd default PATH
    // (/usr/bin:/bin:/usr/sbin:/sbin), so relying on `which` alone made the
    // check mark itself non-runnable for every Homebrew or ~/.bun install.
    private func executablePath(for name: String) -> String? {
        for directory in searchDirectories() {
            let candidate = (directory as NSString).appendingPathComponent(name)
            if let path = Self.executablePath(fromWhichOutput: candidate) {
                return path
            }
        }
        return nil
    }

    func searchDirectories() -> [String] {
        Self.systemInstallPrefixes + Self.homeInstallPrefixes.map {
            homeDirectory.appendingPathComponent($0).path
        }
    }

    private static let systemInstallPrefixes = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
        "/usr/bin",
        "/bin",
    ]

    private static let homeInstallPrefixes = [
        ".bun/bin",
        ".local/bin",
        ".local/share/mise/shims",
        ".cargo/bin",
        ".volta/bin",
        ".yarn/bin",
        ".npm-global/bin",
        ".deno/bin",
        ".asdf/shims",
        "Library/pnpm",
        "Library/Application Support/fnm/aliases/default/bin",
    ]

    static func executablePath(fromWhichOutput output: String) -> String? {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (path as NSString).isAbsolutePath, FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return path
    }

    // MARK: - Per-manager configuration

    /// The single source of truth for every manager this check understands.
    private var managers: [ManagerConfig] {
        func homeCandidate(_ relativePath: String) -> (displayPath: String, url: URL) {
            ("~/" + relativePath, homeDirectory.appendingPathComponent(relativePath))
        }

        return [
            ManagerConfig(
                candidates: [homeCandidate(".npmrc")],
                binaries: ["npm"],
                validate: { contents, _ in Self.validateNpmrc(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.npmrc delays npm-compatible package releases" },
                versionGate: (minimumVersion: "11.14.0", configDescription: "~/.npmrc min-release-age"),
                usesSetting: { Self.npmConfigUsesMinReleaseAge($0) }
            ),
            ManagerConfig(
                // pnpm 10 keeps settings in the global rc file, pnpm 11 in
                // config.yaml; .npmrc-style files are reserved for auth.
                candidates: pnpmConfigPaths().map { candidate in (displayPath: candidate.displayPath, url: candidate.url) },
                binaries: ["pnpm"],
                validate: Self.validatePnpmConfig,
                missingDetail: { _ in self.pnpmConfigMissingDetail() },
                passingDetail: { display in "\(display) delays pnpm package releases" }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".bunfig.toml")],
                binaries: ["bun"],
                validate: { contents, _ in Self.validateBunfig(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.bunfig.toml delays Bun package releases" }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".config/uv/uv.toml")],
                binaries: ["uv"],
                validate: { contents, _ in Self.validateUv(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.config/uv/uv.toml excludes Python packages newer than 7 days" }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".pypirc")],
                binaries: [],
                validate: { contents, _ in Self.validatePypirc(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.pypirc has no plaintext credentials" }
            ),
        ]
    }

    private func activeConfig(in manager: ManagerConfig) -> (displayPath: String, contents: String)? {
        for candidate in manager.candidates {
            if let contents = readFile(candidate.url) {
                return (candidate.displayPath, contents)
            }
        }
        return nil
    }

    private func readFile(_ url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func pnpmConfigPaths() -> [(url: URL, displayPath: String)] {
        if let xdgConfigHome = xdgConfigHome() {
            let xdgDirectory = URL(fileURLWithPath: xdgConfigHome)
            return [
                (xdgDirectory.appendingPathComponent("pnpm/rc"), "$XDG_CONFIG_HOME/pnpm/rc"),
                (xdgDirectory.appendingPathComponent("pnpm/config.yaml"), "$XDG_CONFIG_HOME/pnpm/config.yaml"),
            ]
        }
        return [
            (homeDirectory.appendingPathComponent("Library/Preferences/pnpm/rc"), "~/Library/Preferences/pnpm/rc"),
            (homeDirectory.appendingPathComponent("Library/Preferences/pnpm/config.yaml"), "~/Library/Preferences/pnpm/config.yaml"),
            (homeDirectory.appendingPathComponent(".config/pnpm/rc"), "~/.config/pnpm/rc"),
            (homeDirectory.appendingPathComponent(".config/pnpm/config.yaml"), "~/.config/pnpm/config.yaml"),
        ]
    }

    private func pnpmConfigMissingDetail() -> String {
        let paths = pnpmConfigPaths().map(\.displayPath).joined(separator: ", ")
        return "pnpm config is missing (checked \(paths))"
    }

    private func xdgConfigHome() -> String? {
        guard let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty, (xdgConfigHome as NSString).isAbsolutePath else {
            return nil
        }
        return (xdgConfigHome as NSString).standardizingPath
    }

    // MARK: - Version gates

    private func addingVersionGate(
        _ failures: [String],
        binary: String,
        minimumVersion: String,
        configDescription: String
    ) -> [String] {
        var failures = failures
        guard failures.isEmpty, isBinaryInstalled(binary) else {
            return failures
        }
        guard let version = packageManagerVersion(binary) else {
            failures.append("\(binary) version could not be determined, so \(configDescription) could not be verified")
            return failures
        }
        if !Self.isVersion(version, atLeast: minimumVersion) {
            failures.append("\(binary) is older than \(minimumVersion) and does not enforce \(configDescription)")
        }
        return failures
    }

    // MARK: - Static validators

    static func validateNpmrc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        var failures: [String] = []

        let minReleaseAgeDays = integerValue(values["min-release-age"]) ?? 0
        let minimumReleaseAgeMinutes = integerValue(values["minimum-release-age"]) ?? 0
        if minReleaseAgeDays < minimumCooldownDays, minimumReleaseAgeMinutes < minimumCooldownMinutes {
            failures.append("~/.npmrc release age is below \(minimumCooldownDays) days; set either min-release-age >= \(minimumCooldownDays) or minimum-release-age >= \(minimumCooldownMinutes)")
        }
        // An explicit save-exact=false is an informed choice, so only an
        // unset value fails. https://github.com/ParetoSecurity/pareto-mac/issues/303
        if values["save-exact"] == nil {
            failures.append("~/.npmrc save-exact is not set; set it to true or false")
        }

        return failures
    }

    static func validatePnpmConfig(_ contents: String, displayPath: String) -> [String] {
        let values = keyValuePairs(contents)
        let minimumReleaseAge = integerValue(values["minimumreleaseage"]) ?? integerValue(values["minimum-release-age"]) ?? 0

        if minimumReleaseAge < minimumCooldownMinutes {
            return ["\(displayPath) minimumReleaseAge is below \(minimumCooldownMinutes) minutes"]
        }
        return []
    }

    static func validateBunfig(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let minimumReleaseAge = integerValue(values["install.minimumReleaseAge"]) ?? 0

        if minimumReleaseAge < minimumCooldownSeconds {
            return ["~/.bunfig.toml minimumReleaseAge is below \(minimumCooldownSeconds) seconds"]
        }
        return []
    }

    static func validateUv(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let seconds = durationSeconds(values["exclude-newer"]) ?? durationSeconds(values["pip.exclude-newer"]) ?? 0

        if seconds < minimumCooldownSeconds {
            return ["~/.config/uv/uv.toml exclude-newer is below \(minimumCooldownDays) days"]
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

    private static func npmConfigUsesMinReleaseAge(_ contents: String) -> Bool {
        keyValuePairs(contents)["min-release-age"] != nil
    }

    // MARK: - Parsing helpers

    static func isVersion(_ version: String?, atLeast minimumVersion: String) -> Bool {
        guard let version else { return false }
        if version.contains("-") {
            return false
        }
        let current = versionComponents(version)
        let minimum = versionComponents(minimumVersion)
        for index in 0 ..< max(current.count, minimum.count) {
            let currentPart = index < current.count ? current[index] : 0
            let minimumPart = index < minimum.count ? minimum[index] : 0
            if currentPart != minimumPart {
                return currentPart > minimumPart
            }
        }
        return true
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { part in
            Int(part.prefix { $0.isNumber }) ?? 0
        }
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
        let suffix = String(normalized.dropFirst(number.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int(number) else { return nil }

        switch suffix {
        case "s", "second", "seconds":
            return amount
        case "m", "minute", "minutes":
            return amount * 60
        case "h", "hour", "hours":
            return amount * 3600
        case "d", "day", "days":
            return amount * 86400
        case "w", "week", "weeks":
            return amount * 604_800
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
