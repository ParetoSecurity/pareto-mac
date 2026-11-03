//
//  EditorExtensionsSupplyChain.swift
//  Pareto Security
//
//  Created by Codex on 02/11/2026.
//

import Foundation

class EditorExtensionsSupplyChainCheck: ParetoCheck {
    static let sharedInstance = EditorExtensionsSupplyChainCheck()

    let homeDirectory: URL
    let installedApps: Set<String>?
    let appVersions: [String: String]

    /// Same release-cooldown policy as PackageManagerSupplyChainCheck: a
    /// release younger than this is considered "too new to trust".
    private static let minimumCooldownSeconds = 604_800
    private static let minimumCooldownHours = minimumCooldownSeconds / 3600

    /// One entry per supported editor: where its user settings live, which
    /// app bundles imply the settings must exist, and how to validate the
    /// extension cooldown setting. All per-editor behavior flows from this
    /// table; the checks below just iterate it.
    private struct EditorConfig {
        /// App name used in messages and as the key for injected versions.
        let appName: String
        /// Candidate app bundles; relative paths are resolved against the
        /// home directory.
        let appBundles: [String]
        /// Candidate settings files, first match wins. Relative paths are
        /// resolved against the home directory.
        let settingsCandidates: [(displayPath: String, url: URL)]
        /// The settings.json key that holds the cooldown in hours.
        let settingKey: String
        /// Validates the file contents; the second argument is the display
        /// path used in messages.
        let validate: (String, String) -> [String]
        /// Detail used when no settings file exists.
        let missingDetail: (String) -> String
        /// Detail used when the settings pass; the first argument is the
        /// file contents so an editor-specific reason can be included.
        let passingDetail: (String, String) -> String
        /// Set when only newer editor versions actually enforce the setting.
        var minimumAppVersion: String?
        /// The gate only makes sense once the cooldown key is present.
        var usesSetting: ((String) -> Bool)?

        init(
            appName: String,
            appBundles: [String],
            settingsCandidates: [(displayPath: String, url: URL)],
            settingKey: String,
            validate: @escaping (String, String) -> [String],
            missingDetail: @escaping (String) -> String,
            passingDetail: @escaping (String, String) -> String,
            minimumAppVersion: String? = nil,
            usesSetting: ((String) -> Bool)? = nil
        ) {
            self.appName = appName
            self.appBundles = appBundles
            self.settingsCandidates = settingsCandidates
            self.settingKey = settingKey
            self.validate = validate
            self.missingDetail = missingDetail
            self.passingDetail = passingDetail
            self.minimumAppVersion = minimumAppVersion
            self.usesSetting = usesSetting
        }
    }

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        installedApps: Set<String>? = nil,
        appVersions: [String: String] = [:]
    ) {
        self.homeDirectory = homeDirectory
        self.installedApps = installedApps
        self.appVersions = appVersions
    }

    override var UUID: String {
        "d53a7b3b-2484-4d2f-966e-0ef1e9b64e48"
    }

    override var TitleON: String {
        "Editor extensions delay new releases"
    }

    override var TitleOFF: String {
        "Editor extensions install new releases immediately"
    }

    override var isRunnable: Bool {
        isActive && hasEditorConfigOrApp()
    }

    override var showInMenu: Bool {
        isActive && hasEditorConfigOrApp()
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

        for editor in editors {
            guard let active = activeSettings(in: editor) else {
                if isAppInstalled(editor) {
                    failures.append(editor.missingDetail(editor.settingsCandidates[0].displayPath))
                }
                continue
            }

            var editorFailures = editor.validate(active.contents, active.displayPath)
            if let minimumVersion = editor.minimumAppVersion, editorFailures.isEmpty,
               editor.usesSetting?(active.contents) == true,
               isAppInstalled(editor)
            {
                editorFailures = addingVersionGate(
                    editorFailures,
                    editor: editor,
                    minimumVersion: minimumVersion
                )
            }
            failures.append(contentsOf: editorFailures)
        }

        return failures
    }

    private func passingDetails() -> String {
        var details: [String] = []

        for editor in editors {
            if let active = activeSettings(in: editor), editor.validate(active.contents, active.displayPath).isEmpty {
                details.append(editor.passingDetail(active.contents, active.displayPath))
            }
        }

        if details.isEmpty {
            return "No supported editor installation or settings file was found"
        }
        return details.map { "- \($0)" }.joined(separator: "\n")
    }

    private func hasEditorConfigOrApp() -> Bool {
        let settingsPaths = editors.flatMap { $0.settingsCandidates.map(\.url) }
        if settingsPaths.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return true
        }
        return editors.contains(where: isAppInstalled)
    }

    private func isAppInstalled(_ editor: EditorConfig) -> Bool {
        if let installedApps {
            return installedApps.contains(editor.appName)
        }
        return editor.appBundles.contains { FileManager.default.fileExists(atPath: resolvedPath($0)) }
    }

    /// Reads the editor version from the app bundle's Info.plist, so no
    /// process is ever launched.
    private func appVersion(for editor: EditorConfig) -> String? {
        if let version = appVersions[editor.appName] {
            return PackageManagerSupplyChainCheck.versionToken(from: version)
        }
        // With injected app detection the check runs fully synthetically;
        // the real /Applications must never influence a test outcome.
        if installedApps != nil {
            return nil
        }
        for bundle in editor.appBundles {
            let path = resolvedPath(bundle)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let infoPlist = URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist")
            if let values = NSDictionary(contentsOf: infoPlist), let version = values["CFBundleShortVersionString"] as? String {
                return PackageManagerSupplyChainCheck.versionToken(from: version)
            }
        }
        return nil
    }

    private func resolvedPath(_ candidate: String) -> String {
        guard candidate.hasPrefix("~/") else { return candidate }
        return homeDirectory.appendingPathComponent(String(candidate.dropFirst(2))).path
    }

    private func addingVersionGate(_ failures: [String], editor: EditorConfig, minimumVersion: String) -> [String] {
        var failures = failures
        guard failures.isEmpty, isAppInstalled(editor) else {
            return failures
        }
        guard let version = appVersion(for: editor) else {
            failures.append("\(editor.appName) version could not be determined, so \(editor.settingKey) could not be verified")
            return failures
        }
        if !PackageManagerSupplyChainCheck.isVersion(version, atLeast: minimumVersion) {
            failures.append("\(editor.appName) is older than \(minimumVersion) and does not enforce \(editor.settingKey)")
        }
        return failures
    }

    // MARK: - Per-editor configuration

    /// The single source of truth for every editor this check understands.
    private var editors: [EditorConfig] {
        func settingsCandidate(_ relativePath: String) -> (displayPath: String, url: URL) {
            ("~/" + relativePath, homeDirectory.appendingPathComponent(relativePath))
        }

        return [
            // Visual Studio Code family
            EditorConfig(
                appName: "Visual Studio Code",
                appBundles: [
                    "/Applications/Visual Studio Code.app",
                    "~/Applications/Visual Studio Code.app",
                ],
                settingsCandidates: [settingsCandidate("Library/Application Support/Code/User/settings.json")],
                settingKey: "extensions.autoUpdateDelay",
                validate: { contents, displayPath in
                    Self.validateVSCodeFamily(contents, displayPath: displayPath, settingKey: "extensions.autoUpdateDelay")
                },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { contents, display in
                    Self.isAutoUpdateDisabled(contents)
                        ? "\(display) has automatic extension updates disabled"
                        : "\(display) delays Visual Studio Code extension updates"
                },
                minimumAppVersion: "1.125.0",
                usesSetting: { Self.settingsValue($0, key: "extensions.autoUpdateDelay") != nil }
            ),
            EditorConfig(
                appName: "Visual Studio Code - Insiders",
                appBundles: [
                    "/Applications/Visual Studio Code - Insiders.app",
                    "~/Applications/Visual Studio Code - Insiders.app",
                ],
                settingsCandidates: [settingsCandidate("Library/Application Support/Code - Insiders/User/settings.json")],
                settingKey: "extensions.autoUpdateDelay",
                validate: { contents, displayPath in
                    Self.validateVSCodeFamily(contents, displayPath: displayPath, settingKey: "extensions.autoUpdateDelay")
                },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { contents, display in
                    Self.isAutoUpdateDisabled(contents)
                        ? "\(display) has automatic extension updates disabled"
                        : "\(display) delays Visual Studio Code - Insiders extension updates"
                },
                minimumAppVersion: "1.125.0",
                usesSetting: { Self.settingsValue($0, key: "extensions.autoUpdateDelay") != nil }
            ),
            EditorConfig(
                appName: "VSCodium",
                appBundles: [
                    "/Applications/VSCodium.app",
                    "~/Applications/VSCodium.app",
                ],
                settingsCandidates: [settingsCandidate("Library/Application Support/VSCodium/User/settings.json")],
                settingKey: "extensions.autoUpdateDelay",
                validate: { contents, displayPath in
                    Self.validateVSCodeFamily(contents, displayPath: displayPath, settingKey: "extensions.autoUpdateDelay")
                },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { contents, display in
                    Self.isAutoUpdateDisabled(contents)
                        ? "\(display) has automatic extension updates disabled"
                        : "\(display) delays VSCodium extension updates"
                },
                minimumAppVersion: "1.125.0",
                usesSetting: { Self.settingsValue($0, key: "extensions.autoUpdateDelay") != nil }
            ),

            // Other editors
            EditorConfig(
                appName: "Cursor",
                appBundles: [
                    "/Applications/Cursor.app",
                    "~/Applications/Cursor.app",
                ],
                settingsCandidates: [settingsCandidate("Library/Application Support/Cursor/User/settings.json")],
                settingKey: "extensions.installCooldownHours",
                validate: { contents, displayPath in
                    Self.validateCursor(contents, displayPath: displayPath, settingKey: "extensions.installCooldownHours")
                },
                missingDetail: { display in "\(display) is missing" },
                passingDetail: { contents, display in
                    Self.isAutoUpdateDisabled(contents)
                        ? "\(display) has automatic extension updates disabled"
                        : "\(display) delays Cursor extension updates"
                }
            ),
        ]
    }

    private func activeSettings(in editor: EditorConfig) -> (displayPath: String, contents: String)? {
        for candidate in editor.settingsCandidates {
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

    // MARK: - Static validators

    /// VS Code gates automatic extension updates on `autoUpdateDelay` hours;
    /// with auto-update disabled entirely nothing installs on its own.
    static func validateVSCodeFamily(_ contents: String, displayPath: String, settingKey: String) -> [String] {
        if isAutoUpdateDisabled(contents) {
            return []
        }
        return cooldownHoursFailure(contents, displayPath: displayPath, settingKey: settingKey)
    }

    static func validateCursor(_ contents: String, displayPath: String, settingKey: String) -> [String] {
        if isAutoUpdateDisabled(contents) {
            return []
        }
        return cooldownHoursFailure(contents, displayPath: displayPath, settingKey: settingKey)
    }

    private static func cooldownHoursFailure(_ contents: String, displayPath: String, settingKey: String) -> [String] {
        guard let raw = settingsValue(contents, key: settingKey), let hours = Int(raw) else {
            return ["\(displayPath) \(settingKey) is not set; set it to at least \(minimumCooldownHours) hours"]
        }
        if hours < minimumCooldownHours {
            return ["\(displayPath) \(settingKey) is below \(minimumCooldownHours) hours; set it to at least \(minimumCooldownHours)"]
        }
        return []
    }

    /// True when automatic extension updates are explicitly disabled. VS
    /// Code accepts the legacy boolean `false` and the current `"off"` enum
    /// value; an omitted key means the default (auto-update on).
    static func isAutoUpdateDisabled(_ contents: String) -> Bool {
        let value = settingsValue(contents, key: "extensions.autoUpdate")
        return value == "false" || value == "off"
    }

    // MARK: - Parsing helpers

    /// Reads a top-level `"key": value` token from settings.json, which is
    /// JSONC: comments and trailing commas are allowed. Commented-out
    /// occurrences are ignored.
    static func settingsValue(_ contents: String, key: String) -> String? {
        let stripped = stripJSONCComments(contents)
        let pattern = "\"" + NSRegularExpression.escapedPattern(for: key) + "\"\\s*:\\s*([^\\n,}]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(stripped.startIndex..., in: stripped)
        guard let match = regex.firstMatch(in: stripped, range: range), match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: stripped) else { return nil }
        return unquote(String(stripped[captured]).trimmingCharacters(in: .whitespaces))
    }

    /// Removes `//` line comments and `/* */` block comments while leaving
    /// string contents untouched.
    static func stripJSONCComments(_ contents: String) -> String {
        var result = ""
        var index = contents.startIndex
        var inString = false

        while index < contents.endIndex {
            let character = contents[index]
            if inString {
                result.append(character)
                if character == "\\" {
                    let next = contents.index(after: index)
                    if next < contents.endIndex {
                        result.append(contents[next])
                        index = next
                    }
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
                result.append(character)
            } else if character == "/" {
                let next = contents.index(after: index)
                if next < contents.endIndex, contents[next] == "/" {
                    while index < contents.endIndex, contents[index] != "\n" {
                        index = contents.index(after: index)
                    }
                    continue
                }
                if next < contents.endIndex, contents[next] == "*" {
                    index = contents.index(after: next)
                    while index < contents.endIndex {
                        let blockNext = contents.index(after: index)
                        if contents[index] == "*", blockNext < contents.endIndex, contents[blockNext] == "/" {
                            index = contents.index(after: blockNext)
                            break
                        }
                        index = contents.index(after: index)
                    }
                    continue
                }
                result.append(character)
            } else {
                result.append(character)
            }
            index = contents.index(after: index)
        }

        return result
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        if trimmed.hasPrefix("'"), trimmed.hasSuffix("'"), trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }
}
