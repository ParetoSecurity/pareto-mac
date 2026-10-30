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
        /// Candidate config files, first match wins. Relative paths are
        /// resolved against the home directory.
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
            return Self.versionToken(from: version)
        }
        guard let path = executablePath(for: name) else { return nil }
        // Most of these binaries are `#!/usr/bin/env node` wrappers, so they
        // need a PATH that also resolves their runtime.
        var childEnvironment = environment
        childEnvironment["PATH"] = searchDirectories().joined(separator: ":")
        let output = runCMD(app: path, args: ["--version"], environment: childEnvironment)
        return Self.versionToken(from: output)
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
            // JavaScript / Node.js
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
                candidates: [homeCandidate(".yarnrc.yml")],
                binaries: ["yarn"],
                validate: { contents, _ in Self.validateYarnrc(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.yarnrc.yml delays Yarn package releases" },
                versionGate: (minimumVersion: "4.11.0", configDescription: "~/.yarnrc.yml npmMinimalAgeGate"),
                usesSetting: { Self.yarnrcUsesAgeGate($0) }
            ),

            // Python
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
            ManagerConfig(
                candidates: [homeCandidate(".config/pip/pip.conf")],
                binaries: ["pip", "pip3"],
                validate: { contents, _ in Self.validatePipConf(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.config/pip/pip.conf delays pip package releases" },
                versionGate: (minimumVersion: "26.1.0", configDescription: "~/.config/pip/pip.conf uploaded-prior-to"),
                usesSetting: { Self.pipConfUsesUploadedPriorTo($0) }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".config/pypoetry/config.toml")],
                binaries: ["poetry"],
                validate: { contents, _ in Self.validatePoetryToml(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.config/pypoetry/config.toml delays Poetry package releases" },
                versionGate: (minimumVersion: "2.4.0", configDescription: "~/.config/pypoetry/config.toml solver.min-release-age"),
                usesSetting: { Self.tomlKeyValuePairs($0)["solver.min-release-age"] != nil }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".config/pdm/config.toml")],
                binaries: ["pdm"],
                validate: { contents, _ in Self.validatePdmToml(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.config/pdm/config.toml delays PDM package releases" },
                versionGate: (minimumVersion: "2.27.0", configDescription: "~/.config/pdm/config.toml strategy.exclude-newer"),
                usesSetting: { values in
                    let values = Self.tomlKeyValuePairs(values)
                    return values["strategy.exclude-newer"] != nil || values["strategy.exclude_newer"] != nil
                }
            ),
            ManagerConfig(
                candidates: [homeCandidate(".condarc")],
                binaries: ["conda"],
                validate: { contents, _ in Self.validateCondarc(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.condarc delays conda package releases" },
                versionGate: (minimumVersion: "26.9.0", configDescription: "~/.condarc exclude_newer"),
                usesSetting: { contents in
                    let values = Self.keyValuePairs(contents)
                    return values["exclude_newer"] != nil || values["exclude-newer"] != nil
                }
            ),

            // Ruby
            ManagerConfig(
                candidates: [homeCandidate(".bundle/config")],
                binaries: ["bundle", "bundler"],
                validate: { contents, _ in Self.validateBundleConfig(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.bundle/config delays Bundler package releases" },
                versionGate: (minimumVersion: "4.0.13", configDescription: "~/.bundle/config BUNDLE_COOLDOWN"),
                usesSetting: { Self.keyValuePairs($0)["bundle_cooldown"] != nil }
            ),

            // Elixir
            ManagerConfig(
                candidates: [homeCandidate(".hex/hex.config")],
                binaries: ["mix"],
                validate: { contents, _ in Self.validateHexConfig(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.hex/hex.config delays Hex package releases" }
            ),

            // Tool version managers
            ManagerConfig(
                candidates: [homeCandidate(".config/mise/config.toml")],
                binaries: ["mise"],
                validate: { contents, _ in Self.validateMiseConfig(contents) },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { _ in "~/.config/mise/config.toml delays mise package releases" }
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

    static func validateYarnrc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        let seconds = yarnAgeGateSeconds(values["npmminimalagegate"]) ?? 0

        if seconds < minimumCooldownSeconds {
            return ["~/.yarnrc.yml npmMinimalAgeGate is below \(minimumCooldownDays) days; set it to at least \(minimumCooldownDays)d or \(minimumCooldownMinutes)"]
        }
        return []
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
        let minimumReleaseAge = cooldownSeconds(values["install.minimumReleaseAge"]) ?? 0

        if minimumReleaseAge < minimumCooldownSeconds {
            return ["~/.bunfig.toml minimumReleaseAge is below \(minimumCooldownSeconds) seconds"]
        }
        return []
    }

    static func validateUv(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let raw = values["exclude-newer"] ?? values["pip.exclude-newer"]

        return durationCooldownFailure(raw, displayKey: "~/.config/uv/uv.toml exclude-newer", hint: "\(minimumCooldownDays) days")
    }

    static func validatePipConf(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        guard let uploadedPriorTo = values["uploaded-prior-to"], !uploadedPriorTo.isEmpty else {
            return ["~/.config/pip/pip.conf uploaded-prior-to is not set; set it to a duration like P\(minimumCooldownDays)D"]
        }
        if isAbsoluteTimestamp(uploadedPriorTo) {
            return ["~/.config/pip/pip.conf uploaded-prior-to is an absolute timestamp that goes stale; set it to a duration like P\(minimumCooldownDays)D"]
        }
        if iso8601DurationSeconds(uploadedPriorTo) ?? 0 < minimumCooldownSeconds {
            return ["~/.config/pip/pip.conf uploaded-prior-to is below \(minimumCooldownDays) days; set it to at least P\(minimumCooldownDays)D"]
        }
        return []
    }

    static func validatePoetryToml(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let days = integerValue(values["solver.min-release-age"]) ?? 0

        if days < minimumCooldownDays {
            return ["~/.config/pypoetry/config.toml solver.min-release-age is below \(minimumCooldownDays) days; set it to at least \(minimumCooldownDays)"]
        }
        return []
    }

    static func validatePdmToml(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)
        let raw = values["strategy.exclude-newer"] ?? values["strategy.exclude_newer"]

        return durationCooldownFailure(raw, displayKey: "~/.config/pdm/config.toml strategy.exclude-newer", hint: "\(minimumCooldownDays)d")
    }

    static func validateCondarc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        guard let excludeNewer = values["exclude_newer"] ?? values["exclude-newer"] else {
            return ["~/.condarc exclude_newer is not set; set it to at least \(minimumCooldownDays)d"]
        }
        var failures = durationCooldownFailure(excludeNewer, displayKey: "~/.condarc exclude_newer", hint: "\(minimumCooldownDays)d")
        if failures.isEmpty, values["solver"]?.lowercased() != "classic" {
            failures.append("~/.condarc solver must be classic; the default solver does not support exclude_newer")
        }
        return failures
    }

    static func validateBundleConfig(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        // Bundler rejects anything that is not a whole number of days.
        guard let days = integerValue(values["bundle_cooldown"]), days >= minimumCooldownDays else {
            return ["~/.bundle/config BUNDLE_COOLDOWN is below \(minimumCooldownDays) days; set it to at least \(minimumCooldownDays) with bundle config set --global cooldown \(minimumCooldownDays)"]
        }
        return []
    }

    static func validateHexConfig(_ contents: String) -> [String] {
        let seconds = hexCooldownSeconds(contents) ?? 0

        if seconds < minimumCooldownSeconds {
            return ["~/.hex/hex.config cooldown is below \(minimumCooldownDays) days; set it to at least \(minimumCooldownDays)d with mix hex.config cooldown \(minimumCooldownDays)d"]
        }
        return []
    }

    static func validateMiseConfig(_ contents: String) -> [String] {
        let values = tomlKeyValuePairs(contents)

        return durationCooldownFailure(values["settings.minimum_release_age"], displayKey: "~/.config/mise/config.toml settings.minimum_release_age", hint: "\(minimumCooldownDays)d")
    }

    static func validatePypirc(_ contents: String) -> [String] {
        let values = keyValuePairs(contents)
        let credentialKeys = ["password", "token", "api-token"]

        for key in credentialKeys where values[key]?.isEmpty == false {
            return ["~/.pypirc contains plaintext credentials"]
        }
        return []
    }

    /// Validates values such as uv's exclude-newer that accept relative
    /// durations or absolute timestamps, where only durations keep working
    /// as time passes.
    private static func durationCooldownFailure(_ raw: String?, displayKey: String, hint: String) -> [String] {
        guard let raw, !raw.isEmpty else {
            return ["\(displayKey) is not set; set it to at least \(hint)"]
        }
        if isAbsoluteTimestamp(raw) {
            return ["\(displayKey) is an absolute timestamp that goes stale; set it to a relative duration like \(hint)"]
        }
        if cooldownSeconds(raw) ?? 0 < minimumCooldownSeconds {
            return ["\(displayKey) is below \(minimumCooldownDays) days; set it to at least \(hint)"]
        }
        return []
    }

    private static func npmConfigUsesMinReleaseAge(_ contents: String) -> Bool {
        keyValuePairs(contents)["min-release-age"] != nil
    }

    private static func yarnrcUsesAgeGate(_ contents: String) -> Bool {
        keyValuePairs(contents)["npmminimalagegate"] != nil
    }

    private static func pipConfUsesUploadedPriorTo(_ contents: String) -> Bool {
        keyValuePairs(contents)["uploaded-prior-to"] != nil
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

    /// Extracts the version number from the various `--version` output
    /// formats ("11.14.0", "pip 26.1.0 from ...", "Bundler version 2.6.7").
    static func versionToken(from output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).first { $0.first?.isNumber == true } ?? trimmed
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

    /// Yarn parses a bare `npmMinimalAgeGate` number as minutes; only values
    /// with a unit suffix are durations.
    private static func yarnAgeGateSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        let normalized = unquote(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let minutes = Int(normalized) {
            return minutes * 60
        }
        return cooldownSeconds(normalized)
    }

    private static func cooldownSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        return iso8601DurationSeconds(value) ?? durationSeconds(value)
    }

    private static func durationSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        let normalized = unquote(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let seconds = Int(normalized) {
            return seconds
        }
        guard !normalized.isEmpty else { return nil }

        // Compound relative durations such as "7 days", "3d12h", or "1h30m".
        var total = 0
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let digits = normalized[index...].prefix { $0.isNumber }
            guard let amount = Int(digits), !digits.isEmpty else { return nil }
            index = normalized.index(index, offsetBy: digits.count)
            while index < normalized.endIndex, normalized[index].isWhitespace {
                index = normalized.index(after: index)
            }
            let unit = normalized[index...].prefix { $0.isLetter }
            guard let seconds = unitSeconds(String(unit)), !unit.isEmpty else { return nil }
            index = normalized.index(index, offsetBy: unit.count)
            total += amount * seconds
        }
        return total
    }

    private static func unitSeconds(_ unit: String) -> Int? {
        switch unit {
        case "ms", "millisecond", "milliseconds":
            0
        case "s", "second", "seconds":
            1
        case "m", "minute", "minutes":
            60
        case "h", "hour", "hours":
            3600
        case "d", "day", "days":
            86400
        case "w", "week", "weeks":
            604_800
        case "mo", "month", "months":
            2_592_000
        default:
            nil
        }
    }

    private static func iso8601DurationSeconds(_ value: String) -> Int? {
        let normalized = unquote(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("p"), normalized.count > 1, let regex = try? NSRegularExpression(pattern: #"^p(?:(\d+)w)?(?:(\d+)d)?(?:t(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?)?$"#) else { return nil }
        let range = NSRange(normalized.startIndex..., in: normalized)
        guard let match = regex.firstMatch(in: normalized, range: range) else { return nil }

        let unitSeconds = [604_800, 86400, 3600, 60, 1]
        var total = 0
        for (group, seconds) in zip(1..., unitSeconds) where match.range(at: group).location != NSNotFound {
            guard let groupRange = Range(match.range(at: group), in: normalized), let amount = Int(normalized[groupRange]) else { return nil }
            total += amount * seconds
        }
        return total
    }

    private static func isAbsoluteTimestamp(_ value: String) -> Bool {
        let normalized = unquote(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.first?.isNumber == true else { return false }
        return normalized.contains("-")
    }

    /// Reads the cooldown value from hex.config, which stores Erlang terms
    /// such as `{cooldown,<<"7d">>}.` or `{cooldown,7}.` (days).
    private static func hexCooldownSeconds(_ contents: String) -> Int? {
        if let quoted = firstRegexCapture(#"cooldown\s*,\s*<<"([^"]+)""#, in: contents) {
            return durationSeconds(quoted)
        }
        if let bare = firstRegexCapture(#"cooldown\s*,\s*(\d+)"#, in: contents) {
            return (Int(bare) ?? 0) * 86400
        }
        return nil
    }

    private static func firstRegexCapture(_ pattern: String, in contents: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(contents.startIndex..., in: contents)
        guard let match = regex.firstMatch(in: contents, range: range), match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: contents) else { return nil }
        return String(contents[captured])
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
