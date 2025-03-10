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

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case prerelease
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
                    let sortedReleases = releases.sorted {
                        self.compareVersions($0.tagName, $1.tagName) == .orderedDescending
                    }

                    let isUpToDate = sortedReleases[0].tagName == AppInfo.appVersion
                    os_log("Update check completed. App version: %{public}s, Github version: %{public}s",
                           AppInfo.appVersion,
                           releases[0].tagName)
                    completion(isUpToDate)

                case let .failure(error):
                    os_log("Failed to check for updates: %{public}s", error.localizedDescription)
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
