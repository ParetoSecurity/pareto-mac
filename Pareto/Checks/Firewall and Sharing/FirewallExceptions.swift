//
//  FirewallExceptions.swift
//  Pareto Security
//
//  Created by ArchitektApx on 06/11/2026.
//

import Defaults
import Foundation
import os.log
import Security

class FirewallExceptionsCheck: ParetoCheck {
    static let sharedInstance = FirewallExceptionsCheck()

    struct App: Equatable {
        let path: String
        let allowsIncoming: Bool
    }

    /// Who signed an app the firewall lets in.
    enum Signer: Equatable {
        case apple
        case appStore
        case other
        /// The app is no longer on disk, so nothing can accept connections through its entry.
        case missing
    }

    /// Why an allowed app does not fail the check.
    enum Trust: Equatable {
        case apple
        case appStore
        case notInstalled
        case user
    }

    /// Allowed firewall entries grouped by the app bundle they belong to, so an app and its helpers are one row.
    struct Exception: Equatable, Identifiable {
        let bundle: String
        let paths: [String]
        let trust: Trust?

        var id: String {
            bundle
        }
    }

    let listAppsProvider: () -> String?
    let requiresHeader: Bool
    let signerProvider: (String) -> Signer

    init(
        listAppsProvider: @escaping () -> String? = { FirewallExceptionsCheck.listApps() },
        requiresHeader: Bool = FirewallExceptionsCheck.alwaysPrintsHeader,
        signerProvider: @escaping (String) -> Signer = { FirewallExceptionsCheck.signer(of: $0) }
    ) {
        self.listAppsProvider = listAppsProvider
        self.requiresHeader = requiresHeader
        self.signerProvider = signerProvider
    }

    /// macOS 13 and 14 print nothing for an empty list, macOS 15 and later always print the header.
    static var alwaysPrintsHeader: Bool {
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override var UUID: String {
        "783c9607-b3dc-4a79-8d27-0f337e018c4b"
    }

    override var TitleON: String {
        "Firewall has no app exceptions"
    }

    override var TitleOFF: String {
        "Firewall has app exceptions"
    }

    override var isRunnable: Bool {
        if teamEnforced {
            return true
        }
        if !FirewallCheck.sharedInstance.isActive || !isActive {
            return false
        }
        return true
    }

    override var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override var details: String {
        let paths = exceptions() ?? []
        if paths.isEmpty {
            return "None"
        }
        return paths.map { "- \($0)" }.joined(separator: "\n")
    }

    static func listApps(app: String = "/usr/libexec/ApplicationFirewall/socketfilterfw") -> String? {
        do {
            return try runCMD(
                app: app,
                args: ["--listapps"],
                timeout: 15,
                includeStandardError: false,
                requireSuccessfulExit: true
            )
        } catch {
            os_log("socketfilterfw --listapps failed: %{public}@", log: Log.check, String(describing: error))
            return nil
        }
    }

    /// Parses `socketfilterfw --listapps`. macOS 13 and 14 print "ALF: total number of apps = N", blank lines and
    /// "( Allow incoming connections )"; macOS 15 and later print "Total number of apps = N" and
    /// "(Allow incoming connections)". Each app is an "N : <path>" line followed by its status line.
    static func parseListApps(_ output: String, requiresHeader: Bool = alwaysPrintsHeader) -> [App]? {
        let lines = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let header = lines.first else {
            return requiresHeader ? nil : []
        }
        let count = ["ALF: total number of apps = ", "Total number of apps = "]
            .first { header.hasPrefix($0) }
            .flatMap { Int(header.dropFirst($0.count)) }
        guard let count, lines.count % 2 == 1, (lines.count - 1) / 2 == count else {
            return nil
        }

        var apps: [App] = []
        for index in 0 ..< count {
            let entry = lines[1 + index * 2]
            let prefix = "\(index + 1) :"
            guard entry.hasPrefix(prefix) else {
                return nil
            }
            let path = entry.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else {
                return nil
            }
            let allowsIncoming: Bool
            switch lines[2 + index * 2] {
            case "( Allow incoming connections )", "(Allow incoming connections)":
                allowsIncoming = true
            case "( Block incoming connections )", "(Block incoming connections)":
                allowsIncoming = false
            default:
                return nil
            }
            apps.append(App(path: path, allowsIncoming: allowsIncoming))
        }
        return apps
    }

    // MARK: - Trust

    /// Signed by Apple as part of macOS or an Apple app.
    private static let appleRequirement = "anchor apple"
    /// Signed by Apple for the Mac App Store (6.1.9) or the iOS App Store for iPhone and iPad apps on Mac (6.1.3).
    private static let appStoreRequirement = "anchor apple generic and ("
        + "certificate leaf[field.1.2.840.113635.100.6.1.9] exists or "
        + "certificate leaf[field.1.2.840.113635.100.6.1.3] exists)"

    static func signer(of path: String) -> Signer {
        guard FileManager.default.fileExists(atPath: path) else {
            // An app on an external disk is only missing while the disk is unplugged.
            return path.hasPrefix("/Volumes/") ? .other : .missing
        }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess,
              let code
        else {
            return isSystemProtected(path) ? .apple : .other
        }
        if satisfies(code, appleRequirement) {
            return .apple
        }
        if satisfies(code, appStoreRequirement) {
            return .appStore
        }
        // Some system binaries such as cupsd are readable by root only, so their signature can't be checked.
        return isSystemProtected(path) && !FileManager.default.isReadableFile(atPath: path) ? .apple : .other
    }

    /// System Integrity Protection keeps these locations writable by Apple only.
    static func isSystemProtected(_ path: String) -> Bool {
        if path.hasPrefix("/usr/local/") {
            return false
        }
        return ["/System/", "/usr/", "/bin/", "/sbin/"].contains { path.hasPrefix($0) }
    }

    private static func satisfies(_ code: SecStaticCode, _ requirement: String) -> Bool {
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess, let parsed else {
            return false
        }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSBasicValidateOnly), parsed) == errSecSuccess
    }

    /// Interpreters run whatever script they are given, so an Apple signature says nothing about what listens.
    static func isInterpreter(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        let pattern = #"^(python[0-9.]*|Python\.app|ruby|perl[0-9.]*|node|php|osascript|java|"#
            + #"bash|sh|zsh|tclsh[0-9.]*)$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    /// The outermost `.app` bundle a path belongs to, so helpers group under their app. Interpreters stay on their own.
    static func owningBundle(of path: String) -> String {
        if isInterpreter(path) {
            return path
        }
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: false) {
            components.append(String(component))
            if component.hasSuffix(".app") {
                return components.joined(separator: "/")
            }
        }
        return path
    }

    /// An entry on the allow list also covers everything inside it, so allowing an app covers its helpers.
    static func isCovered(_ path: String, by allowed: [String]) -> Bool {
        allowed.contains { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }

    private func autoTrust(_ path: String) -> Trust? {
        if Self.isInterpreter(path) {
            return nil
        }
        switch signerProvider(path) {
        case .apple:
            return .apple
        case .appStore:
            return .appStore
        case .missing:
            return .notInstalled
        case .other:
            return nil
        }
    }

    /// All apps the firewall lets in, grouped by bundle. `trust` is nil for the ones that fail the check.
    func evaluate() -> [Exception]? {
        guard let output = listAppsProvider(),
              let apps = Self.parseListApps(output, requiresHeader: requiresHeader)
        else {
            return nil
        }
        let allowed = Defaults[.ignoredFirewallApps]
        var order: [String] = []
        var grouped: [String: [String]] = [:]
        for app in apps where app.allowsIncoming {
            let bundle = Self.owningBundle(of: app.path)
            if grouped[bundle] == nil {
                order.append(bundle)
            }
            grouped[bundle, default: []].append(app.path)
        }
        return order.map { bundle in
            let paths = grouped[bundle] ?? []
            let trusts = paths.map { Self.isCovered($0, by: allowed) ? .user : autoTrust($0) }
            let trust: Trust? = trusts.contains(nil) ? nil
                : trusts.contains(.user) ? .user
                : trusts.allSatisfy { $0 == .notInstalled } ? .notInstalled
                : trusts.allSatisfy { $0 == .apple || $0 == .notInstalled } ? .apple
                : .appStore
            return Exception(bundle: bundle, paths: paths, trust: trust)
        }
    }

    /// Entries inside the bundle other than its own main executable, e.g. helper apps and extensions.
    static func helpers(of exception: Exception) -> [String] {
        exception.paths.filter { path in
            path != exception.bundle
                && !path.hasPrefix(exception.bundle + "/Contents/MacOS/")
                && !path.hasPrefix(exception.bundle + "/Wrapper/")
        }
    }

    func exceptions() -> [String]? {
        evaluate()?.filter { $0.trust == nil }.map(\.bundle)
    }

    override func checkPasses() -> Bool {
        guard let paths = exceptions() else {
            os_log("Could not read socketfilterfw --listapps output", log: Log.check)
            hasError = true
            return false
        }
        return paths.isEmpty
    }
}
