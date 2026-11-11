//
//  AppCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/11/2021.
//

import Alamofire
import AppKit
import Cocoa
import Combine
import Defaults
import Foundation
import os.log
import OSLog
import Regex
import SwiftUI
import Version

protocol AppCheckProtocol {
    var appName: String { get }
    var appMarketingName: String { get }
    var appBundle: String { get }
    var sparkleURL: String { get }
}

private struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

private struct AppStoreResult: Codable {
    let version, wrapperType: String
    let artistID: Int
    let artistName: String

    enum CodingKeys: String, CodingKey {
        case version, wrapperType
        case artistID = "artistId"
        case artistName
    }
}

private struct LatestVersionLookupState {
    var inFlight = false
    var lastFailure: Date?
    var waiters: [() -> Void] = []
}

class AppCheck: ParetoCheck, AppCheckProtocol {
    /// How long to wait before retrying a latest-version lookup that failed.
    static let failedLookupRetryInterval: TimeInterval = 10 * 60

    private let latestVersionLookup = OSAllocatedUnfairLock(initialState: LatestVersionLookupState())
    var appName: String {
        ""
    }

    var appMarketingName: String {
        ""
    }

    var appBundle: String {
        ""
    }

    var sparkleURL: String {
        ""
    }

    var sparkleChannel: String? {
        nil
    }

    var excludedSparkleChannel: String? {
        nil
    }

    override var TitleON: String {
        "\(appMarketingName) is up-to-date"
    }

    override var TitleOFF: String {
        "\(appMarketingName) has an available update"
    }

    override var details: String {
        applicationLocation ?? "not found"
    }

    override var reportIfDisabled: Bool {
        false
    }

    var supportsRecentlyUsed: Bool {
        true
    }

    var fromAppStore: Bool {
        if let appPath = applicationPath {
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: appPath))
            guard let hasReceipt = attributes?.value(forAttribute: "kMDItemAppStoreHasReceipt") as? Bool else { return false }
            return hasReceipt
        }
        return false
    }

    func getLatestVersionAppStore(completion: @escaping (String) -> Void) {
        let languageCode = Locale.current.region?.identifier ?? "US"
        var url = URLComponents(url: URL(string: "https://itunes.apple.com/lookup")!, resolvingAgainstBaseURL: false)
        url?.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "entity", value: "desktopSoftware"),
            URLQueryItem(name: "country", value: languageCode),
            URLQueryItem(name: "bundleId", value: appBundle),
        ]
        guard let request = url?.url else {
            completion("0.0.0")
            return
        }
        os_log("Requesting %{public}s", request.debugDescription)
        let directURL = request.description
        let edgeURL = viaEdgeCache(directURL)
        requestAppStoreVersion(edgeURL) { version, statusCode in
            // Apple intermittently answers the edge cache with 403; ask Apple directly instead.
            if version == nil, AppCheck.shouldRetryDirect(statusCode: statusCode, requestedURL: edgeURL, directURL: directURL) {
                os_log("%{public}s edge cache returned 403, retrying directly", self.appBundle)
                self.requestAppStoreVersion(directURL) { version, _ in
                    self.finishAppStoreLookup(version, completion: completion)
                }
                return
            }
            self.finishAppStoreLookup(version, completion: completion)
        }
    }

    /// True when an App Store lookup through the edge cache was refused and should go to Apple directly.
    static func shouldRetryDirect(statusCode: Int?, requestedURL: String, directURL: String) -> Bool {
        statusCode == 403 && requestedURL != directURL
    }

    private func requestAppStoreVersion(_ url: String, completion: @escaping (String?, Int?) -> Void) {
        Network.session.request(url).responseDecodable(of: AppStoreResponse.self, queue: AppCheck.queue) { response in
            if let version = response.value?.results.first, response.error == nil {
                completion(version.version, response.response?.statusCode)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion(nil, response.response?.statusCode)
            }
        }
    }

    private func finishAppStoreLookup(_ version: String?, completion: @escaping (String) -> Void) {
        if let version {
            completion(version)
        } else {
            hasError = true
            completion("0.0.0")
        }
    }

    override var help: String? {
        let latest = latestVersion
        let latestDescription = latestVersionLookupFailed ? "unknown" : latest.description
        return "Current: \(currentVersion.description), Latest: \(latestDescription)"
    }

    static let queue = DispatchQueue(label: "co.pareto.check_versions", qos: .userInteractive, attributes: .concurrent)
    var latestVersion: Version {
        if let cached = cachedLatestVersion {
            return cached
        }
        refreshLatestVersionIfNeeded()
        return currentVersion
    }

    /// Latest version from a successful lookup, or nil when it is not known.
    /// A cached 0.0.0 (written by older builds for failed lookups) is not a real version.
    var cachedLatestVersion: Version? {
        guard let cached = try? AppInfo.versionStorage.object(forKey: appBundle),
              cached > Version(0, 0, 0)
        else {
            return nil
        }
        return cached
    }

    /// True when the most recent latest-version lookup failed and no successful lookup followed.
    var latestVersionLookupFailed: Bool {
        latestVersionLookup.withLock { $0.lastFailure != nil }
    }

    /// Starts a latest-version lookup unless one is in flight or a recent one failed.
    /// `completion` runs when the in-flight lookup finishes, or right away when no lookup runs.
    private func refreshLatestVersionIfNeeded(completion: (() -> Void)? = nil) {
        let (shouldStart, queued) = latestVersionLookup.withLock { state -> (Bool, Bool) in
            if state.inFlight {
                if let completion {
                    state.waiters.append(completion)
                }
                return (false, completion != nil)
            }
            if let lastFailure = state.lastFailure,
               Date().timeIntervalSince(lastFailure) < AppCheck.failedLookupRetryInterval
            {
                return (false, false)
            }
            state.inFlight = true
            if let completion {
                state.waiters.append(completion)
            }
            return (true, completion != nil)
        }
        guard shouldStart else {
            if !queued {
                completion?()
            }
            return
        }

        getLatestVersion { version in
            self.handleLatestVersionLookup(version)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    /// Records the result of a latest-version lookup. Unparseable or 0.0.0 results are
    /// lookup failures: they are not cached, so they can never certify an app as up to date.
    func handleLatestVersionLookup(_ version: String) {
        let waiters: [() -> Void]
        if let latest = Version(version), latest > Version(0, 0, 0) {
            try? AppInfo.versionStorage.setObject(latest, forKey: appBundle)
            waiters = latestVersionLookup.withLock { state in
                state.inFlight = false
                state.lastFailure = nil
                defer { state.waiters.removeAll() }
                return state.waiters
            }
        } else {
            os_log("%{public}s latest version lookup failed, keeping previous result", appBundle)
            try? AppInfo.versionStorage.removeObject(forKey: appBundle)
            waiters = latestVersionLookup.withLock { state in
                state.inFlight = false
                state.lastFailure = Date()
                defer { state.waiters.removeAll() }
                return state.waiters
            }
        }
        waiters.forEach { $0() }
    }

    /// Gets the latest version before a report runs.
    /// The report then does not compare against a pending lookup.
    override func prefetch(completion: @escaping () -> Void) {
        guard isInstalled, isRunnable, cachedLatestVersion == nil else {
            completion()
            return
        }
        refreshLatestVersionIfNeeded(completion: completion)
    }

    var applicationSearchDirectories: [String] {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        return ["/Applications", "\(homeDirURL.path)/Applications"]
    }

    var applicationPath: String? {
        for directory in applicationSearchDirectories {
            let path = "\(directory)/\(appName).app/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    var applicationLocation: String? {
        applicationPath?.components(separatedBy: "/Contents/").first
    }

    override var isInstalled: Bool {
        applicationPath != nil
    }

    var usedRecently: Bool {
        if !Defaults[.checkForUpdatesRecentOnly] {
            return true
        }

        if isInstalled {
            if !supportsRecentlyUsed {
                return true
            }

            let app = applicationPath!.components(separatedBy: "/Contents/")[0]
            let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: app))
            guard let lastUse = attributes?.value(forAttribute: "kMDItemLastUsedDate") as? Date else { return false }
            return lastUse >= weekAgo
        }
        return false
    }

    override var isRunnable: Bool {
        // show if application is present
        isActive && isInstalled && usedRecently
    }

    override var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return isInstalled
    }

    override var showInMenu: Bool {
        isActive && isInstalled && usedRecently
    }

    var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        var version = (appVersion(path: applicationPath!) ?? "0.0.0").lowercased()
        if version.contains("alpha") {
            version = version.replacingOccurrences(of: "alpha", with: "-alpha")
        }
        if version.contains("beta") {
            version = version.replacingOccurrences(of: "beta", with: "-beta")
        }

        version = version.replacingOccurrences(of: ".-", with: "-")

        return Version(version) ?? Version(0, 0, 0)
    }

    func getLatestVersion(completion: @escaping (String) -> Void) {
        if fromAppStore {
            getLatestVersionAppStore(completion: completion)
            return
        } else {
            os_log("Requesting %{public}s", sparkleURL)
            Network.session.request(sparkleURL).responseString(queue: AppCheck.queue, completionHandler: { response in
                if response.error == nil {
                    let version = Self.latestSparkleVersion(
                        from: response.value ?? "",
                        channel: self.sparkleChannel,
                        excludedChannel: self.excludedSparkleChannel
                    )
                    if version != "0.0.0" {
                        os_log("%{public}s Sparkle=%{public}s", self.appBundle, version)
                        completion(version)
                    } else {
                        os_log("%{public}s failed:Sparkle=0.0.0", self.appBundle)
                        completion("0.0.0")
                    }

                } else {
                    os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                    completion("0.0.0")
                }

            })
        }
    }

    static func latestSparkleVersion(from response: String, channel: String? = nil, excludedChannel: String? = nil) -> String {
        let versionAttributeRegex = Regex("sparkle:shortVersionString=\"([\\.\\d]+)\"")
        let versionElementRegex = Regex("<sparkle:shortVersionString>([\\.\\d]+)</sparkle:shortVersionString>")
        let versionFallbackRegex = Regex("sparkle:version=\"([\\.\\d]+)\"")
        let items = response.components(separatedBy: "<item>").dropFirst().map { "<item>" + $0 }
        let candidates = items.isEmpty ? [response] : items
        let item = candidates.first {
            if let channel {
                return $0.contains("<sparkle:channel>\(channel)</sparkle:channel>")
            }
            if let excludedChannel {
                return !$0.contains("<sparkle:channel>\(excludedChannel)</sparkle:channel>")
            }
            return true
        } ?? response

        if let version = versionAttributeRegex.firstMatch(in: item)?.groups.first?.value {
            return version
        }
        if let version = versionElementRegex.firstMatch(in: item)?.groups.first?.value {
            return version
        }
        return versionFallbackRegex.firstMatch(in: item)?.groups.first?.value ?? "0.0.0"
    }

    override func checkPasses() -> Bool {
        if !isInstalled {
            return true
        }
        if !isOnline {
            return checkPassed
        }
        let latest = latestVersion
        if latestVersionLookupFailed {
            // Latest version is unknown: report an error and keep the previous result
            hasError = true
            return checkPassed
        }
        return currentVersion >= latest
    }

    var isOnline: Bool {
        NetworkHandler.sharedInstance().currentStatus == .satisfied
    }

    @objc override func moreInfo() {
        if let url = URL(string: "https://paretosecurity.com/check/\(UUID)?utm_source=\(AppInfo.utmSource)&appName=\(appName.replacingOccurrences(of: " ", with: "%20"))&latestVersion=\(latestVersion)&currentVersion=\(currentVersion)&appBundle=\(appBundle)") {
            NSWorkspace.shared.open(url)
        }
    }

    override var disabledReason: String {
        get {
            if !isActive {
                return "Manually disabled"
            } else if !isInstalled {
                return "App not installed"
            } else if !usedRecently {
                return "App was not used recently"
            }
            return UserDefaults.standard.string(forKey: DisabledReasonKey) ?? "Unknown reason"
        }
        set { UserDefaults.standard.set(newValue, forKey: DisabledReasonKey) }
    }
}
