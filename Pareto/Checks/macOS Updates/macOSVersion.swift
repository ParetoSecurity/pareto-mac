//
//  macOSVersionCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Alamofire
import Foundation
import os.log
import Regex
import Version

typealias AsyncCommandRunner = @Sendable (_ app: String, _ args: [String], _ timeout: TimeInterval) async throws -> String

class MacOSVersionCheck: ParetoCheck {
    static let sharedInstance = MacOSVersionCheck()
    private let latestVersionLock = OSAllocatedUnfairLock<Version>(initialState: Version(0, 0, 0))
    private let latestVersionSourceLock = OSAllocatedUnfairLock<String>(initialState: "unresolved")
    private let latestVersionInFlight = OSAllocatedUnfairLock(initialState: false)
    var commandRunner: AsyncCommandRunner = { app, args, timeout in
        try await runCMDAsync(app: app, args: args, timeout: timeout)
    }
    var supportPageVersionProvider: (@Sendable (String) async -> Version?)?
    override var UUID: String {
        "284162c2-f911-4b5e-8c81-30b2cf1ba73f"
    }

    override var TitleON: String {
        "macOS is up-to-date"
    }

    override var TitleOFF: String {
        "macOS is not up-to-date"
    }

    override var details: String {
        let latestVersion = latestVersionLock.withLock { $0 }
        let source = latestVersionSourceLock.withLock { $0 }

        if latestVersion == Version(0, 0, 0) {
            return "current=\(currentVersion) latest=unknown source=\(source)"
        }

        return "current=\(currentVersion) latest=\(latestVersion) source=\(source)"
    }

    override var help: String? {
        let latestVersion = latestVersionLock.withLock { $0 }
        if latestVersion == Version(0, 0, 0) {
            return "Current: \(currentVersion), Latest: unknown"
        }

        return "Current: \(currentVersion), Latest: \(latestVersion)"
    }

    var currentVersion: Version {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return Version(os.majorVersion, os.minorVersion, os.patchVersion)
    }

    static func normalizeVersion(_ rawVersion: String) -> Version? {
        var version = rawVersion
        if version.components(separatedBy: ".").count == 2 {
            version += ".0"
        }
        return Version(version)
    }

    static func parseLatestVersion(fromSupportPageHTML html: String) -> Version? {
        let versionRegex = Regex("<h2.*>macOS.+ ([\\.\\d]+)<\\/h2>")
        guard var version = versionRegex.firstMatch(in: html)?.groups.first?.value else {
            return nil
        }

        if version.components(separatedBy: ".").count == 2 {
            version += ".0"
        }

        return normalizeVersion(version)
    }

    static func parseLatestVersion(fromSoftwareUpdateOutput output: String, currentMajor: Int) -> Version? {
        let nsOutput = output as NSString
        let patterns = [
            #"(?m)^\s*\*?\s*Title:\s*macOS[^\n]*?,\s*Version:\s*([\d.]+)"#,
            #"(?m)^\s*\*?\s*Label:\s*macOS[^\n]*?\s([\d.]+)(?:[-,\s]|$)"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsOutput.length))
            let versions = matches.compactMap { match -> Version? in
                guard match.numberOfRanges > 1 else { return nil }
                return normalizeVersion(nsOutput.substring(with: match.range(at: 1)))
            }

            if let sameMajor = versions.filter({ $0.major == currentMajor }).max() {
                return sameMajor
            }
        }

        return nil
    }

    static func isCurrentVersionUpToDate(current: Version, latest: Version) -> Bool {
        // Special case: macOS 26.3.2 is only offered to MacBook Neo devices, but this check
        // compares against Apple's global latest version and would otherwise warn all 26.3.1 Macs.
        if current == Version(26, 3, 1), latest == Version(26, 3, 2) {
            return true
        }

        return current >= latest
    }

    func getLatestVersion(doc: String, completion: @escaping (Version, String) -> Void) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else {
                completion(Version(0, 0, 0), "unresolved")
                return
            }

            if let supportPageVersion = await self.getLatestVersionFromSupportPage(doc: doc) {
                completion(supportPageVersion, "apple-support")
                return
            }

            if let softwareUpdateVersion = await self.getLatestVersionFromSoftwareUpdate() {
                completion(softwareUpdateVersion, "softwareupdate")
                return
            }

            completion(Version(0, 0, 0), "unresolved")
        }
    }

    private func getLatestVersionFromSupportPage(doc: String) async -> Version? {
        if let supportPageVersionProvider {
            return await supportPageVersionProvider(doc)
        }

        let url = "https://support.apple.com/en-us/\(doc)"
        os_log("Determining latest macOS version via Apple support page: %{public}s", log: Log.check, url)

        return await withCheckedContinuation { continuation in
            Network.session.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
                if let error = response.error {
                    os_log("Apple support page lookup failed: %{public}@", log: Log.check, error.localizedDescription)
                    continuation.resume(returning: nil)
                    return
                }

                let parsedVersion = Self.parseLatestVersion(fromSupportPageHTML: response.value ?? "")
                os_log("Apple support page resolved latest macOS version to %{public}@", log: Log.check, parsedVersion?.description ?? "unknown")
                continuation.resume(returning: parsedVersion)
            })
        }
    }

    func getLatestVersionFromSoftwareUpdate() async -> Version? {
        do {
            os_log("Determining latest macOS version via softwareupdate", log: Log.check)
            let output = try await commandRunner("/usr/sbin/softwareupdate", ["--list"], 20.0)
            let parsedVersion = Self.parseLatestVersion(fromSoftwareUpdateOutput: output, currentMajor: currentVersion.major)
            os_log("softwareupdate resolved latest macOS version to %{public}@", log: Log.check, parsedVersion?.description ?? "unknown")
            return parsedVersion
        } catch {
            os_log("softwareupdate lookup failed: %{public}@", log: Log.check, error.localizedDescription)
            return nil
        }
    }

    func storeResolvedLatestVersion(_ version: Version, source: String) {
        latestVersionLock.withLock { $0 = version }
        latestVersionSourceLock.withLock { $0 = source }
    }

    var latestXX: Version {
        var doc = "HT211896"
        if #available(macOS 12, *) {
            doc = "HT212585"
        }
        if #available(macOS 13, *) {
            doc = "HT213268"
        }
        if #available(macOS 14, *) {
            doc = "HT213895"
        }
        if #available(macOS 15, *) {
            doc = "120283"
        }
        if #available(macOS 26, *) {
            doc = "122868"
        }
        refreshLatestVersionIfNeeded(doc: doc)
        return latestVersionLock.withLock { $0 }
    }

    private func refreshLatestVersionIfNeeded(doc: String) {
        let shouldStart = latestVersionInFlight.withLock { inFlight in
            if inFlight { return false }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        getLatestVersion(doc: doc) { version, source in
            self.storeResolvedLatestVersion(version, source: source)
            self.latestVersionInFlight.withLock { $0 = false }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    override func checkPasses() -> Bool {
        return Self.isCurrentVersionUpToDate(current: currentVersion, latest: latestXX)
    }
}
