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
import SwiftUI
import SwiftyJSON
import Version

protocol AppCheckProtocol {
    var appName: String { get }
    var appMarketingName: String { get }
    var appBundle: String { get }
    var sparkleURL: String { get }
}

class AppCheck: ParetoCheck, AppCheckProtocol {
    var appName: String { "" }
    var appMarketingName: String { "" }
    var appBundle: String { "" }
    var sparkleURL: String { "" }

    override var TitleON: String {
        "\(appMarketingName) is up-to-date"
    }

    override var TitleOFF: String {
        "\(appMarketingName) has an available update"
    }

    override var details: String {
        "local=\(currentVersion) online=\(latestVersion) applicationPath=\(String(describing: applicationPath))"
    }

    override public var reportIfDisabled: Bool {
        return false
    }

    static let queue = DispatchQueue(label: "co.pareto.check_versions", qos: .utility, attributes: .concurrent)
    public var latestVersion: Version {
        if try! AppInfo.versionStorage.existsObject(forKey: appBundle) {
            return try! AppInfo.versionStorage.object(forKey: appBundle)
        } else {
            let lock = DispatchSemaphore(value: 0)
            getLatestVersion { version in
                let latestVersion = Version(version) ?? Version(0, 0, 0)
                try! AppInfo.versionStorage.setObject(latestVersion, forKey: self.appBundle)
                lock.signal()
            }
            lock.wait()
            return try! AppInfo.versionStorage.object(forKey: appBundle)
        }
    }

    var applicationPath: String? {
        let globalPath = "/Applications/\(appName).app/Contents/Info.plist"
        if FileManager.default.fileExists(atPath: globalPath) {
            return globalPath
        }

        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let localPath = "\(homeDirURL.path)/Applications/\(appName).app/Contents/Info.plist"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }

        return nil
    }

    override public var isRunnable: Bool {
        // show if application is present
        return isActive && applicationPath != nil
    }

    override public var showSettings: Bool {
        return applicationPath != nil
    }

    var currentVersion: Version {
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
                        let version = json["results"][0]["version"].string ?? "0.0.0"
                        os_log("%{public}s version=%{public}s", self.appBundle, version)
                        completion(version)
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

                if response.data != nil {
                    let xml = XmlElement(fromData: response.data!)
                    let versionNew = xml["rss"]?["channel"]?["item"]?["enclosure"]?.attributeDict["sparkle:shortVersionString"]
                    let versionOld = xml["rss"]?["channel"]?["item"]?["enclosure"]?.attributeDict["sparkle:version"]
                    if versionNew != nil {
                        os_log("%{public}s sparkle:shortVersionString=%{public}s", self.appBundle, versionNew!)
                        completion(versionNew!)
                    } else if versionOld != nil {
                        os_log("%{public}s sparkle:shortVersionString=%{public}s", self.appBundle, versionOld!)
                        completion(versionOld!)
                    } else {
                        os_log("%{public}s failed:Sparkle=0.0.0", self.appBundle)
                        completion("0.0.0")
                    }

                } else {
                    completion("0.0.0")
                }

            })
        }
    }

    override func checkPasses() -> Bool {
        if NetworkHandler.sharedInstance().currentStatus != .satisfied {
            return checkPassed
        }
        return currentVersion >= latestVersion
    }

    @objc override func moreInfo() {
        if let url = URL(string: "https://paretosecurity.com/check/\(UUID)?utm_source=app&appName=\(appName.replacingOccurrences(of: " ", with: "%20"))&latestVersion=\(latestVersion)&currentVersion=\(currentVersion)&appBundle=\(appBundle)") {
            NSWorkspace.shared.open(url)
        }
    }
}
