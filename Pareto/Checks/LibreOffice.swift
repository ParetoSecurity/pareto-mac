//
//  LibreOffice.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Version

struct EndOfLifeProductResponse: Decodable {
    let result: EndOfLifeProduct
}

struct EndOfLifeProduct: Decodable {
    let releases: [EndOfLifeRelease]
}

struct EndOfLifeRelease: Decodable {
    let isMaintained: Bool
    let latest: EndOfLifeLatestRelease
}

struct EndOfLifeLatestRelease: Decodable {
    let name: String
}

private struct LatestReleasesLookupState {
    /// Maintained releases from the last successful lookup, or nil when they are not known.
    var versions: [Version]?
    var inFlight = false
    var lastFailure: Date?
    var waiters: [() -> Void] = []
}

class AppLibreOfficeCheck: AppCheck {
    static let sharedInstance = AppLibreOfficeCheck()
    private let latestReleasesLookup = OSAllocatedUnfairLock(initialState: LatestReleasesLookupState())

    override var appName: String {
        "LibreOffice"
    }

    override var appMarketingName: String {
        "LibreOffice"
    }

    override var appBundle: String {
        "org.libreoffice.script"
    }

    override var UUID: String {
        "5726931a-264a-5758-b7dd-d09285ac4b7f"
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    static func latestVersions(from response: EndOfLifeProductResponse) -> [String] {
        var versions = [String]()
        for release in response.result.releases where release.isMaintained {
            let version = normalizeVersion(release.latest.name)
            if !versions.contains(version) {
                versions.append(version)
            }
        }
        return versions
    }

    private static func normalizeVersion(_ version: String) -> String {
        version.split(separator: ".").prefix(3).joined(separator: ".")
    }

    func getLatestVersions(completion: @escaping ([String]) -> Void) {
        let url = viaEdgeCache("https://endoflife.date/api/v1/products/libreoffice/")
        os_log("Requesting %{public}s", url)
        Network.session.request(url).responseDecodable(of: EndOfLifeProductResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                completion(Self.latestVersions(from: value))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion(["0.0.0"])
            }
        })
    }

    /// Maintained releases, or nil while the lookup is pending or after it failed.
    var latestVersions: [Version]? {
        refreshLatestVersionsIfNeeded()
        return latestReleasesLookup.withLock { $0.versions }
    }

    /// True when the most recent releases lookup failed and no successful lookup followed.
    var latestReleasesLookupFailed: Bool {
        latestReleasesLookup.withLock { $0.lastFailure != nil }
    }

    /// Starts a releases lookup unless one is in flight, the releases are known, or a recent one failed.
    /// `completion` runs when the in-flight lookup finishes, or right away when no lookup runs.
    private func refreshLatestVersionsIfNeeded(completion: (() -> Void)? = nil) {
        let (shouldStart, queued) = latestReleasesLookup.withLock { state -> (Bool, Bool) in
            if state.inFlight {
                if let completion {
                    state.waiters.append(completion)
                }
                return (false, completion != nil)
            }
            if state.versions != nil {
                return (false, false)
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

        getLatestVersions { versions in
            self.handleLatestVersionsLookup(versions)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    /// Records the result of a releases lookup. An empty list, or one with only unparseable
    /// or 0.0.0 entries, is a lookup failure: it can never certify LibreOffice as up to date.
    func handleLatestVersionsLookup(_ versions: [String]) {
        let parsed = versions.compactMap { Version($0) }.filter { $0 > Version(0, 0, 0) }
        if parsed.isEmpty {
            os_log("%{public}s releases lookup failed, keeping previous result", appBundle)
        }
        let waiters = latestReleasesLookup.withLock { state in
            state.inFlight = false
            if parsed.isEmpty {
                state.versions = nil
                state.lastFailure = Date()
            } else {
                state.versions = parsed
                state.lastFailure = nil
            }
            defer { state.waiters.removeAll() }
            return state.waiters
        }
        waiters.forEach { $0() }
    }

    /// Gets the maintained releases before a report runs.
    override func prefetch(completion: @escaping () -> Void) {
        guard isInstalled, isRunnable else {
            completion()
            return
        }
        refreshLatestVersionsIfNeeded(completion: completion)
    }

    override func checkPasses() -> Bool {
        if NetworkHandler.sharedInstance().currentStatus != .satisfied {
            return checkPassed
        }

        guard let versions = latestVersions else {
            if latestReleasesLookupFailed {
                // Releases are unknown: report an error and keep the previous result
                hasError = true
            }
            return checkPassed
        }

        for version in versions where currentVersion >= version {
            return true
        }

        return false
    }
}
