//
//  ParetoUpdated.swift
//  Pareto Security
//
//  Created by Janez Troha on 4. 3. 25.
//

import Defaults
import Foundation
import os.log
import Version

class ParetoUpdated: ParetoCheck {
    enum UpdateCheckOutcome: Equatable {
        case resolved(isUpToDate: Bool, currentVersion: String, latestVersion: String)
        case inconclusive
    }

    static let sharedInstance = ParetoUpdated()
    private var updateCheckResult: Bool = true
    private var latestVersion: String = ""
    private var currentVersion: String = ""
    private let updateCheckInFlight = OSAllocatedUnfairLock(initialState: false)
    var updatesProvider: () async throws -> [Release] = {
        try await UpdateService.shared.getUpdatesAsync()
    }

    override var UUID: String {
        "44e4754a-0b42-4964-9cc2-b88b2023cb1e"
    }

    override var TitleON: String {
        "Pareto Security is up-to-date"
    }

    override var TitleOFF: String {
        "Pareto Security is outdated"
    }

    override var infoURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "paretosecurity.com"
        components.path = "/check/\(UUID)"

        // Add version parameters
        var queryItems = [URLQueryItem]()

        // Add current and latest version information
        if !currentVersion.isEmpty {
            queryItems.append(URLQueryItem(name: "current_version", value: currentVersion))
        }
        if !latestVersion.isEmpty {
            queryItems.append(URLQueryItem(name: "latest_version", value: latestVersion))
        }

        components.queryItems = queryItems

        return components.url!
    }

    func normalizedVersionString(_ rawVersion: String) -> String {
        let versionWithoutPrefix = rawVersion.replacingOccurrences(of: "v", with: "")
        if versionWithoutPrefix.contains("-") {
            return String(versionWithoutPrefix.split(separator: "-")[0])
        }
        return versionWithoutPrefix
    }

    func isCurrentVersionUpToDate(currentVersion: String, latestVersion: String) -> Bool {
        let normalizedCurrent = normalizedVersionString(currentVersion)
        let normalizedLatest = normalizedVersionString(latestVersion)

        guard
            let current = Version(normalizedCurrent),
            let latest = Version(normalizedLatest)
        else {
            return normalizedCurrent.compare(normalizedLatest, options: .numeric) != .orderedAscending
        }

        return current >= latest
    }

    func compareVersionsIfConcrete(currentVersion: String, latestVersion: String) -> Bool? {
        let normalizedCurrent = normalizedVersionString(currentVersion)
        let normalizedLatest = normalizedVersionString(latestVersion)

        guard
            let current = Version(normalizedCurrent),
            let latest = Version(normalizedLatest)
        else {
            return nil
        }

        return current >= latest
    }

    func evaluateUpdateCheckOutcome(
        releases: [Release],
        appVersion: String = AppInfo.appVersion,
        now: Date = Date()
    ) -> UpdateCheckOutcome {
        guard !releases.isEmpty else {
            os_log("Ignoring empty release list during update check")
            return .inconclusive
        }

        let sortedReleases = releases.sorted { $0.version > $1.version }
        os_log("Sorted releases: %{public}@", sortedReleases.map { $0.tag_name }.joined(separator: ", "))

        let filteredReleases = sortedReleases.filter { !$0.prerelease }
        os_log("Comparing installed app against latest stable release")

        guard let latestRelease = filteredReleases.first else {
            os_log("Ignoring update check without a stable release")
            return .inconclusive
        }

        let normalizedAppVersion = normalizedVersionString(appVersion)
        let latestVersionString = normalizedVersionString(latestRelease.tag_name)

        let tenDaysAgo = now.addingTimeInterval(-10 * 24 * 60 * 60)
        let dateFormatter = ISO8601DateFormatter()

        guard let publishedDate = dateFormatter.date(from: latestRelease.published_at) else {
            os_log("Ignoring update check with invalid published date: %{public}s", latestRelease.published_at)
            return .inconclusive
        }

        guard publishedDate < tenDaysAgo else {
            os_log("Latest stable release is within 10 days grace period. Published: %{public}s, Days ago: %{public}f, App version: %{public}s, Latest version: %{public}s",
                   latestRelease.published_at, abs(publishedDate.timeIntervalSince(now)) / (24 * 60 * 60), normalizedAppVersion, latestVersionString)
            return .resolved(
                isUpToDate: true,
                currentVersion: normalizedAppVersion,
                latestVersion: latestVersionString
            )
        }

        guard let isUpToDate = compareVersionsIfConcrete(
            currentVersion: normalizedAppVersion,
            latestVersion: latestVersionString
        ) else {
            os_log("Ignoring update check with non-concrete version comparison. App version: %{public}s, Latest version: %{public}s",
                   normalizedAppVersion, latestVersionString)
            return .inconclusive
        }

        os_log("Latest stable release is older than 10 days. App version: %{public}s, Latest version: %{public}s, Up to date: %{public}@",
               normalizedAppVersion, latestVersionString, isUpToDate ? "true" : "false")
        return .resolved(
            isUpToDate: isUpToDate,
            currentVersion: normalizedAppVersion,
            latestVersion: latestVersionString
        )
    }

    func fetchUpdateCheckOutcome(
        appVersion: String = AppInfo.appVersion,
        now: Date = Date()
    ) async -> UpdateCheckOutcome {
        do {
            let releases = try await updatesProvider()
            return evaluateUpdateCheckOutcome(releases: releases, appVersion: appVersion, now: now)
        } catch {
            os_log("Ignoring inconclusive update check result: %{public}s", error.localizedDescription)
            return .inconclusive
        }
    }

    @discardableResult
    func applyUpdateCheckOutcome(_ outcome: UpdateCheckOutcome) -> Bool {
        switch outcome {
        case let .resolved(isUpToDate, currentVersion, latestVersion):
            updateCheckResult = isUpToDate
            self.currentVersion = currentVersion
            self.latestVersion = latestVersion
        case .inconclusive:
            break
        }

        hasError = false
        return updateCheckResult
    }

    private func refreshUpdateStatusIfNeeded() {
        let shouldStart = updateCheckInFlight.withLock { inFlight in
            if inFlight { return false }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let outcome = await self.fetchUpdateCheckOutcome()
            self.applyUpdateCheckOutcome(outcome)
            self.updateCheckInFlight.withLock { $0 = false }
        }
    }

    override func checkPasses() -> Bool {
        // Disable this check when running in SetApp or when beta channel is enabled

        #if SETAPP_ENABLED
            // Always pass for SetApp builds as updates are handled by SetApp
            return true
        #else
            refreshUpdateStatusIfNeeded()
            return updateCheckResult
        #endif
    }

    override var details: String {
        #if SETAPP_ENABLED
            return "Updates handled by Setapp"
        #else
            if hasError {
                return "Update check failed"
            }
            // Prefer resolved versions captured during the last check
            let current = currentVersion.isEmpty ? AppInfo.appVersion : currentVersion
            if latestVersion.isEmpty {
                return "Current: \(current), Latest: unknown"
            }
            if checkPassed {
                return "Current: \(current) (latest \(latestVersion))"
            } else {
                return "Current: \(current), Latest: \(latestVersion)"
            }
        #endif
    }
}
