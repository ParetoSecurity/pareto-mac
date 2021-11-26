//
//  AppCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/11/2021.
//

import Alamofire
import Foundation
import os.log
import OSLog
import SwiftyJSON

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

    private var isApplicationPresentCached: Bool = false
    private var applicationPresentCached: Bool = false
    private static let queue = DispatchQueue(label: "co.pareto.check_versions", qos: .utility, attributes: .concurrent)

    func isApplicationPresent() -> Bool {
        if isApplicationPresentCached {
            return applicationPresentCached
        }
        let path = "/Applications/\(appName).app/Contents/Info.plist"
        let found = FileManager.default.fileExists(atPath: path)
        if !found {
            os_log("Application is not present %{public}s", path)
        }
        isApplicationPresentCached = true
        applicationPresentCached = found
        return found
    }

    override public var isRunnable: Bool {
        return isActive && isApplicationPresent()
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
                        os_log("%{public}s version=%{public}s", self.appBundle, version!)
                        completion(version!)
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
                        os_log("%{public}s version=%{public}s", self.appBundle, version!)
                        completion(version!)
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
        var latestVersion = "0.0.0"

        // Invalidate presence cache (liek after we install app and run checks)
        isApplicationPresentCached = false
        _ = isApplicationPresent()

        getLatestVersion { version in
            latestVersion = version
            lock.signal()
        }
        lock.wait()
        return appVersion(app: appName) == latestVersion
    }
}
