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

    // Helper function to compare semantic versions
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1 = version1.replacingOccurrences(of: "v", with: "")
        let v2 = version2.replacingOccurrences(of: "v", with: "")

        return v1.compare(v2, options: .numeric)
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

            // Filter out pre-releases if showBeta is false
            let filteredReleases = Defaults[.showBeta] ? sortedReleases : sortedReleases.filter { !$0.prerelease }

            if !Defaults[.showBeta] {
                os_log("Excluding beta releases in update check")
            } else {
                os_log("Including beta releases in update check")
            }

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
                var appVersion = AppInfo.appVersion
                if appVersion.contains("-") {
                    // Strip any pre-release suffix for comparison
                    appVersion = String(appVersion.split(separator: "-")[0])
                }

                let latestVersionString = latestRelease.tag_name.replacingOccurrences(of: "v", with: "")

                // Store versions for URL construction
                currentVersion = appVersion
                latestVersion = latestVersionString

                let isUpToDate = appVersion == latestVersionString

                os_log("Latest release is older than 10 days. App version: %{public}s, Latest version: %{public}s, Up to date: %{public}@",
                       appVersion, latestVersionString, isUpToDate ? "true" : "false")
                return isUpToDate
            } else {
                // Within 10 days grace period, always pass
                var appVersion = AppInfo.appVersion
                if appVersion.contains("-") {
                    appVersion = String(appVersion.split(separator: "-")[0])
                }
                let latestVersionString = latestRelease.tag_name.replacingOccurrences(of: "v", with: "")

                // Store versions for URL construction
                currentVersion = appVersion
                latestVersion = latestVersionString

                os_log("Latest release is within 10 days grace period. Published: %{public}s, Days ago: %{public}f, App version: %{public}s, Latest version: %{public}s",
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
            // Also disable when beta channel is enabled
            if Defaults[.showBeta] {
                return true
            }

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
            if Defaults[.showBeta] {
                return "Beta channel enabled"
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
