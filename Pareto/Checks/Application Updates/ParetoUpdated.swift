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
    private var updateCheckResult: Bool = false
    private var latestVersion: String = ""
    private var currentVersion: String = ""

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

    private func checkForUpdates(completion: @escaping (Bool) -> Void) {
        do {
            let releases = try UpdateService.shared.getUpdatesSync()

            if releases.isEmpty {
                os_log("No releases found during update check")
                completion(false)
                return
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
                completion(false)
                return
            }

            // Only fail if latest release is older than 10 days and current version does not match
            let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
            let dateFormatter = ISO8601DateFormatter()

            guard let publishedDate = dateFormatter.date(from: latestRelease.published_at) else {
                os_log("Could not parse published date for latest release")
                completion(false)
                return
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
                completion(isUpToDate)
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
                completion(true)
            }

        } catch {
            os_log("Failed to check for updates: %{public}s", error.localizedDescription)
            hasError = true
            completion(false)
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

            // Create a semaphore to wait for the async operation to complete
            let semaphore = DispatchSemaphore(value: 0)

            // Call checkForUpdates with a completion handler
            checkForUpdates { result in
                self.updateCheckResult = result
                semaphore.signal()
            }

            // Wait for the completion handler to be called
            _ = semaphore.wait(timeout: .now() + 10.0) // 10-second timeout

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
