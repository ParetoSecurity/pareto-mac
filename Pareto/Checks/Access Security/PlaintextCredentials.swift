//
//  PlaintextCredentials.swift
//  Pareto Security
//
//  Created by ArchitektApx on 10/11/2026.
//

import Foundation

class PlaintextCredentialsCheck: ParetoCheck {
    static let sharedInstance = PlaintextCredentialsCheck()

    let homeDirectory: URL
    let environment: [String: String]

    private struct CredentialSource {
        let candidates: [(displayPath: String, url: URL)]
        /// Names of the profiles, hosts or registries with a secret in the file; nil when it cannot be parsed.
        let validate: (String) -> [String]?
        let finding: (String, String) -> String
    }

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
    }

    override var UUID: String {
        "de814893-b97e-48fe-a917-4ee4a2d7c58c"
    }

    override var TitleON: String {
        "No plaintext credentials in developer tools"
    }

    override var TitleOFF: String {
        "Plaintext credentials in developer tools"
    }

    override var isRunnable: Bool {
        isActive && hasCredentialFile()
    }

    override var showInMenu: Bool {
        isActive && hasCredentialFile()
    }

    override var details: String {
        let findings = findings()
        if findings.isEmpty {
            return "None"
        }
        return findings.map { "- \($0)" }.joined(separator: "\n")
    }

    override func checkPasses() -> Bool {
        findings().isEmpty
    }

    func findings() -> [String] {
        var findings: [String] = []
        for source in sources {
            for candidate in source.candidates where FileManager.default.fileExists(atPath: candidate.url.path) {
                guard let contents = try? String(contentsOf: candidate.url, encoding: .utf8),
                      let names = source.validate(contents)
                else {
                    hasError = true
                    findings.append("\(candidate.displayPath) could not be read")
                    continue
                }
                var seen = Set<String>()
                findings += names.filter { seen.insert($0).inserted }.map { source.finding(candidate.displayPath, $0) }
            }
        }
        return findings
    }

    private func hasCredentialFile() -> Bool {
        sources.flatMap(\.candidates).contains { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    private var sources: [CredentialSource] {
        func homeCandidate(_ relativePath: String) -> (displayPath: String, url: URL) {
            ("~/" + relativePath, homeDirectory.appendingPathComponent(relativePath))
        }
        func configCandidates(_ relativePath: String) -> [(displayPath: String, url: URL)] {
            let home = homeCandidate(".config/" + relativePath)
            guard let xdgConfigHome = xdgConfigHome() else {
                return [home]
            }
            let url = URL(fileURLWithPath: xdgConfigHome).appendingPathComponent(relativePath)
            if url.standardizedFileURL.path == home.url.standardizedFileURL.path {
                return [home]
            }
            return [home, ("$XDG_CONFIG_HOME/" + relativePath, url)]
        }
        let awsFinding = { (path: String, profile: String) in
            "\(path) profile \(profile) has a long-term access key; use aws-vault or see the docs for alternatives"
        }

        return [
            CredentialSource(
                candidates: [homeCandidate(".aws/credentials")],
                validate: { Self.awsProfilesWithLongTermKeys($0, isConfigFile: false) },
                finding: awsFinding
            ),
            CredentialSource(
                candidates: [homeCandidate(".aws/config")],
                validate: { Self.awsProfilesWithLongTermKeys($0, isConfigFile: true) },
                finding: awsFinding
            ),
            CredentialSource(
                candidates: [homeCandidate(".git-credentials")] + configCandidates("git/credentials"),
                validate: Self.gitHostsWithPasswords,
                finding: { path, host in "\(path) stores a password for \(host); switch to credential.helper osxkeychain" }
            ),
            CredentialSource(
                candidates: [homeCandidate(".docker/config.json")],
                validate: Self.dockerRegistriesWithLogins,
                finding: { path, registry in "\(path) stores a login for \(registry); set a credsStore" }
            ),
            CredentialSource(
                candidates: configCandidates("gh/hosts.yml"),
                validate: Self.ghHostsWithTokens,
                finding: { path, host in
                    "\(path) stores a token for \(host); log in again with gh 2.26 or later, without --insecure-storage"
                }
            ),
        ]
    }

    private func xdgConfigHome() -> String? {
        guard let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty, (xdgConfigHome as NSString).isAbsolutePath else {
            return nil
        }
        return (xdgConfigHome as NSString).standardizingPath
    }

    // MARK: - Static validators

    /// INI as written by `aws configure`: `[name]` in the credentials file, `[default]` or `[profile name]` in the
    /// config file. A session token or an `ASIA` key id means the keys are temporary.
    static func awsProfilesWithLongTermKeys(_ contents: String, isConfigFile: Bool) -> [String] {
        var profiles: [String] = []
        var profile: String?
        var values: [String: String] = [:]

        func finishProfile() {
            let temporary = !values["aws_session_token", default: ""].isEmpty
                || !values["aws_security_token", default: ""].isEmpty
                || values["aws_access_key_id", default: ""].hasPrefix("ASIA")
            if let profile, !values["aws_secret_access_key", default: ""].isEmpty, !temporary {
                profiles.append(profile)
            }
        }

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") {
                continue
            }
            if line.hasPrefix("["), let end = line.firstIndex(of: "]") {
                finishProfile()
                values = [:]
                let section = line[line.index(after: line.startIndex) ..< end].trimmingCharacters(in: .whitespaces)
                profile = isConfigFile ? awsConfigProfileName(section) : section
                continue
            }
            if let separator = line.firstIndex(where: { $0 == "=" || $0 == ":" }) {
                values[line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()] =
                    line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            }
        }
        finishProfile()
        return profiles
    }

    private static func awsConfigProfileName(_ section: String) -> String? {
        if section == "default" {
            return section
        }
        let parts = section.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard parts.count == 2, parts[0] == "profile" else { return nil }
        return unquote(String(parts[1]))
    }

    /// One `scheme://user:password@host` per line as written by `git credential-store`; every part is percent-encoded.
    static func gitHostsWithPasswords(_ contents: String) -> [String] {
        contents.split(whereSeparator: \.isNewline).compactMap { line in
            guard let scheme = line.range(of: "://") else { return nil }
            let authority = line[scheme.upperBound...].prefix { !"/?#".contains($0) }
            guard let at = authority.lastIndex(of: "@"),
                  let colon = authority[..<at].firstIndex(of: ":"),
                  authority.index(after: colon) < at
            else { return nil }
            let host = authority[authority.index(after: at)...].trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else { return nil }
            return host.removingPercentEncoding ?? host
        }
    }

    /// Without a credential store `docker login` keeps base64 `user:password` in `auths.<registry>.auth`.
    static func dockerRegistriesWithLogins(_ contents: String) -> [String]? {
        if contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        guard let data = contents.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        guard let auths = config["auths"], !(auths is NSNull) else { return [] }
        guard let auths = auths as? [String: Any] else { return nil }
        return auths.keys.sorted().filter { registry in
            let entry = auths[registry] as? [String: Any]
            return ["auth", "identitytoken", "password", "registrytoken"].contains { (entry?[$0] as? String)?.isEmpty == false }
        }
    }

    /// gh before 2.26 wrote `oauth_token` directly under the host, newer gh with `--insecure-storage` under
    /// `users.<name>`. With the keychain neither is present.
    static func ghHostsWithTokens(_ contents: String) -> [String] {
        var hosts: [String] = []
        var host: String?
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            guard line.first == " " || line.first == "\t" else {
                host = ghHost(trimmed)
                continue
            }
            guard let host, trimmed.hasPrefix("oauth_token:"), !hosts.contains(host) else { continue }
            let token = unquote(String(trimmed.dropFirst("oauth_token:".count)))
            if !token.isEmpty, token != "null", token != "~" {
                hosts.append(host)
            }
        }
        return hosts
    }

    private static func ghHost(_ line: String) -> String? {
        if let key = line.range(of: ": ") {
            return unquote(String(line[..<key.lowerBound]))
        }
        return line.hasSuffix(":") ? unquote(String(line.dropLast())) : nil
    }

    private static func unquote(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
