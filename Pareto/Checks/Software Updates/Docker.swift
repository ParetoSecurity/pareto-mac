//
//  Docker.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import Foundation
import os.log
import OSLog
import Version

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
}

class AppDockerCheck: AppCheck {
    static let sharedInstance = AppDockerCheck()

    override var appName: String { "Docker" }
    override var appMarketingName: String { "Docker" }
    override var appBundle: String { "com.docker.docker" }

    override var UUID: String {
        "ee11fe36-a372-5cba-a1b4-151748fc2fa7"
    }

    override var TitleON: String {
        "Docker is up-to-date"
    }

    override var TitleOFF: String {
        "Docker has an available update"
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://raw.githubusercontent.com/docker/docker.github.io/master/desktop/mac/release-notes/index.md"
        let versionRegex = NSRegularExpression("## Docker Desktop (?<version>[\\d.]+)")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            do {
                if response.data != nil {
                    let md = response.value ?? ""
                    let mdRange = NSRange(
                        md.startIndex ..< md.endIndex,
                        in: md
                    )
                    let matches = versionRegex.matches(
                        in: md,
                        options: [],
                        range: mdRange
                    )

                    guard let versions = matches.first else {
                        throw NSError(domain: "", code: 0, userInfo: nil)
                    }

                    var parsedVersions: [String] = []

                    for rangeIndex in 1 ..< versions.numberOfRanges {
                        let matchRange = versions.range(at: rangeIndex)

                        // Ignore matching the entire line
                        if matchRange == mdRange { continue }

                        // Extract the substring matching the capture group
                        if let substringRange = Range(matchRange, in: md) {
                            let version = String(md[substringRange])
                            parsedVersions.append(version)
                        }
                    }
                    completion(parsedVersions.first ?? "0.0.0")
                } else {
                    completion("0.0.0")
                }
            } catch {
                completion("0.0.0")
            }
        })
    }
}
