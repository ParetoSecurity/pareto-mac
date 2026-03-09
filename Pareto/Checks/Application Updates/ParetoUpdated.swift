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
    static let sharedInstance = ParetoUpdated()
    private var updateCheckResult: Bool = true
    private var latestVersion: String = ""
    private var currentVersion: String = ""
    private let updateCheckInFlight = OSAllocatedUnfairLock(initialState: false)

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

    private func checkForUpdates() async -> Bool {
        do {
            let releases = try await UpdateService.shared.getUpdatesAsync()

            if releases.isEmpty {
                os_log("No releases found during update check")
                return false
            }

            // Sort releases by version (descending order)
            let sortedReleases = releases.sorted { $0.version > $1.version }

            // Log the sorted releases for debugging
            os_log("Sorted releases: %{public}@", sortedReleases.map { $0.tag_name }.joined(separator: ", "))

            // This check reports whether the installed app is at least as new as the
            // latest stable release, even when prerelease updates are enabled.
            let filteredReleases = sortedReleases.filter { !$0.prerelease }
            os_log("Comparing installed app against latest stable release")

            guard let latestRelease = filteredReleases.first else {
                os_log("No valid releases found after filtering")
                return false
            }

            // Only fail if latest release is older than 10 days and current version does not match
            let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
            let dateFormatter = ISO8601DateFormatter()

            guard let publishedDate = dateFormatter.date(from: latestRelease.published_at) else {
                os_log("Could not parse published date for latest release")
                return false
            }

            if publishedDate < tenDaysAgo {
                // Latest release is older than 10 days, check version match
                let appVersion = normalizedVersionString(AppInfo.appVersion)
                let latestVersionString = latestRelease.tag_name.replacingOccurrences(of: "v", with: "")

                // Store versions for URL construction
                currentVersion = appVersion
                latestVersion = latestVersionString

                let isUpToDate = isCurrentVersionUpToDate(currentVersion: appVersion, latestVersion: latestVersionString)

                os_log("Latest stable release is older than 10 days. App version: %{public}s, Latest version: %{public}s, Up to date: %{public}@",
                       appVersion, latestVersionString, isUpToDate ? "true" : "false")
                return isUpToDate
            } else {
                // Within 10 days grace period, always pass
                let appVersion = normalizedVersionString(AppInfo.appVersion)
                let latestVersionString = latestRelease.tag_name.replacingOccurrences(of: "v", with: "")

                // Store versions for URL construction
                currentVersion = appVersion
                latestVersion = latestVersionString

                os_log("Latest stable release is within 10 days grace period. Published: %{public}s, Days ago: %{public}f, App version: %{public}s, Latest version: %{public}s",
                       latestRelease.published_at, abs(publishedDate.timeIntervalSinceNow) / (24 * 60 * 60), appVersion, latestVersionString)
                return true
            }

        } catch {
            let errorMessage = error.localizedDescription
            // Ignore 503 (Service Unavailable) and 403 (Forbidden) - treat as check passing
            if errorMessage.contains("503") || errorMessage.contains("403") {
                os_log("Ignoring temporary server error for update check: %{public}s", errorMessage)
                return true
            }
            os_log("Failed to check for updates: %{public}s", errorMessage)
            hasError = true
            return false
        }
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
            let result = await self.checkForUpdates()
            self.updateCheckResult = result
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
