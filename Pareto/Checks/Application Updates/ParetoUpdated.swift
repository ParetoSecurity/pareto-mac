//
//  ParetoUpdated.swift
//  Pareto Security
//
//  Created by Janez Troha on 4. 3. 25.
//

import Alamofire
import Defaults
import Foundation
import os.log

struct ParetoRelease: Codable {
    let tagName: String
    let name: String
    let prerelease: Bool
    let draft: Bool
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case prerelease
        case draft
        case publishedAt = "published_at"
    }
}

typealias ParetoReleases = [ParetoRelease]

class ParetoUpdated: ParetoCheck {
    static let sharedInstance = ParetoUpdated()
    private var updateCheckResult: Bool = false

    override var UUID: String {
        "44e4754a-0b42-4964-9cc2-b88b2023cb1e"
    }

    override var TitleON: String {
        "Pareto Security is up-to-date"
    }

    override var TitleOFF: String {
        "Pareto Security is outdated"
    }

    // Helper function to compare semantic versions
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1 = version1.replacingOccurrences(of: "v", with: "")
        let v2 = version2.replacingOccurrences(of: "v", with: "")

        return v1.compare(v2, options: .numeric)
    }

    private func checkForUpdates(completion: @escaping (Bool) -> Void) {
        let baseURL = "https://api.github.com/repos/ParetoSecurity/pareto-mac/releases"

        AF.request(baseURL)
            .responseDecodable(of: ParetoReleases.self, queue: AppCheck.queue) { response in
                switch response.result {
                case let .success(releases):
                    if releases.isEmpty {
                        os_log("No releases found during update check")
                        completion(false)
                        return
                    }

                    // Sort releases by version (descending order)
                    var sortedReleases = releases.sorted {
                        self.compareVersions($0.tagName, $1.tagName) == .orderedDescending
                    }

                    // Exclude draft releases
                    sortedReleases = sortedReleases.filter { !$0.draft }

                    // Log the sorted releases for debugging
                    os_log("Sorted releases: %{public}@", sortedReleases.map { $0.tagName }.joined(separator: ", "))

                    // Filter out pre-releases if showBeta is false
                    if Defaults[.showBeta] {
                        // Include all releases
                        os_log("Including beta releases in update check")
                    } else {
                        // Exclude pre-releases
                        os_log("Excluding beta releases in update check")
                        sortedReleases = sortedReleases.filter { !$0.prerelease }
                    }

                    // Include releases with published date older than 10 days
                    let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
                    let dateFormatter = ISO8601DateFormatter()
                    // dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let recentReleases = sortedReleases.filter { release in
                        guard let publishedDate = dateFormatter.date(from: release.publishedAt) else {
                            return false
                        }
                        return tenDaysAgo >= publishedDate
                    }
                    if recentReleases.isEmpty {
                        os_log("No recent releases older found in update check")
                        completion(false)
                        return
                    }

                    if Defaults[.showBeta] {
                        let isUpToDate = sortedReleases[0].tagName == AppInfo.appVersion
                        os_log("Update check completed. App version: %{public}s, Github version: %{public}s",
                               AppInfo.appVersion,
                               releases[0].tagName)
                        completion(isUpToDate)

                    } else {
                        let isUpToDate = sortedReleases.filter { !$0.prerelease }[0].tagName == AppInfo.appVersion
                        os_log("Update check completed. App version: %{public}s, Github version: %{public}s",
                               AppInfo.appVersion,
                               releases[0].tagName)
                        completion(isUpToDate)
                    }

                case let .failure(error):
                    os_log("Failed to check for updates: %{public}s", error.localizedDescription)
                    self.hasError = true
                    completion(false)
                }
            }
    }

    override func checkPasses() -> Bool {
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
    }
}
