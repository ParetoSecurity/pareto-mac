//
//  AppCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import SwiftyJSON
import Version

protocol AppCheckProtocol {
    var appName: String { get }
    var appMarketingName: String { get }
    var appBundle: String { get }
    var sparkleURL: String { get }
}

class AppCheck: ParetoCheck, AppCheckProtocol {
    var appName: String { "appName" }
    var appMarketingName: String { "appMarketingName" }
    var appBundle: String { "appBundle" }
    var sparkleURL: String { "sparkleURL" }

    private var isApplicationPathCached: Bool = false
    private var applicationPathCached: String?

    static let queue = DispatchQueue(label: "co.pareto.check_versions", qos: .utility, attributes: .concurrent)
    private var latestVersion = Version(0, 0, 0)

    private var applicationPath: String? {
        if isApplicationPathCached {
            return applicationPathCached
        }

        let globalPath = "/Applications/\(appName).app/Contents/Info.plist"
        if FileManager.default.fileExists(atPath: globalPath) {
            applicationPathCached = globalPath
            isApplicationPathCached = true
            return globalPath
        }

        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let localPath = "\(homeDirURL.path)/Applications/\(appName).app/Contents/Info.plist"
        if FileManager.default.fileExists(atPath: localPath) {
            applicationPathCached = localPath
            isApplicationPathCached = true
            return localPath
        }

        os_log("Application is not present %{public}s", appName)
        applicationPathCached = nil
        isApplicationPathCached = true

        return nil
    }

    override public var isRunnable: Bool {
        // show if application is present
        return isActive && applicationPath != nil
    }

    override public var showSettings: Bool {
        return applicationPath != nil
    }

    private var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        return Version(appVersion(path: applicationPath ?? "") ?? "0.0.0") ?? Version(0, 0, 0)
    }

    func getLatestVersion(completion: @escaping (String) -> Void) {
        if sparkleURL.isEmpty {
            let url = "https://itunes.apple.com/lookup?bundleId=\(appBundle)&country=us&entity=macSoftware&limit=1"
            os_log("Requesting %{public}s", url)
            AF.request(url).responseJSON(queue: AppCheck.queue, completionHandler: { response in
                do {
                    if response.data != nil {
                        let json = try JSON(data: response.data!)
                        let version = json["results"][0]["version"].string
                        os_log("%{public}s version=%{public}s", self.appBundle, version ?? "0.0.0")
                        completion(version ?? "0.0.0")
                    } else {
                        completion("0.0.0")
                    }
                } catch {
                    completion("0.0.0")
                }
            })
        } else {
            os_log("Requesting %{public}s", sparkleURL)
            AF.request(sparkleURL).response(queue: AppCheck.queue, completionHandler: { response in
                do {
                    if response.data != nil {
                        let xml = XmlElement(fromData: response.data!)
                        let version = xml["rss"]!["channel"]!["item"]!["enclosure"]!.attributeDict["sparkle:shortVersionString"]
                        os_log("%{public}s version=%{public}s", self.appBundle, version ?? "0.0.0")
                        completion(version ?? "0.0.0")
                    } else {
                        completion("0.0.0")
                    }
                } catch {
                    completion("0.0.0")
                }
            })
        }
    }

    override func checkPasses() -> Bool {
        let lock = DispatchSemaphore(value: 0)

        if NetworkHandler.sharedInstance().currentStatus != .satisfied {
            return checkPassed
        }

        // invalidate cache
        applicationPathCached = nil
        isApplicationPathCached = false

        getLatestVersion { version in
            self.latestVersion = Version(version) ?? self.latestVersion
            lock.signal()
        }
        lock.wait()

        return currentVersion >= latestVersion
    }

    @objc override func moreInfo() {
        if let url = URL(string: "https://paretosecurity.com/check/\(UUID)?utm_source=app&appName=\(appName.replacingOccurrences(of: " ", with: "%20"))&latestVersion=\(latestVersion)&currentVersion=\(currentVersion)&appBundle=\(appBundle)") {
            NSWorkspace.shared.open(url)
        }
    }
}
