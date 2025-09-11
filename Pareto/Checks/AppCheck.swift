//
//  AppCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/11/2021.
//

import Alamofire
import AppKit
import Cocoa
import Combine
import Defaults
import Foundation
import os.log
import OSLog
import Regex
import SwiftUI
import Version

protocol AppCheckProtocol {
    var appName: String { get }
    var appMarketingName: String { get }
    var appBundle: String { get }
    var sparkleURL: String { get }
}

private struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

private struct AppStoreResult: Codable {
    let version, wrapperType: String
    let artistID: Int
    let artistName: String

    enum CodingKeys: String, CodingKey {
        case version, wrapperType
        case artistID = "artistId"
        case artistName
    }
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

    override var reportIfDisabled: Bool {
        return false
    }

    var supportsRecentlyUsed: Bool {
        return true
    }

    var fromAppStore: Bool {
        if let appPath = applicationPath {
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: appPath))
            guard let hasReceipt = attributes?.value(forAttribute: "kMDItemAppStoreHasReceipt") as? Bool else { return false }
            return hasReceipt
        }
        return false
    }

    func getLatestVersionAppStore(completion: @escaping (String) -> Void) {
        let languageCode = Locale.current.regionCode ?? "US"
        var url = URLComponents(url: URL(string: "https://itunes.apple.com/lookup")!, resolvingAgainstBaseURL: false)
        url?.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "entity", value: "desktopSoftware"),
            URLQueryItem(name: "country", value: languageCode),
            URLQueryItem(name: "bundleId", value: appBundle),
        ]
        if let request = url?.url {
            os_log("Requesting %{public}s", request.debugDescription)
            AF.request(viaEdgeCache(request.description)).responseDecodable(of: AppStoreResponse.self, queue: AppCheck.queue, completionHandler: { response in
                if let version = response.value?.results.first, response.error == nil {
                    completion(version.version)
                    return
                } else {
                    os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                    completion("0.0.0")
                    self.hasError = true
                    return
                }
            })
        }
        completion("0.0.0")
    }

    override var help: String? {
        "Current: \(currentVersion.description), Latest: \(latestVersion)"
    }

    static let queue = DispatchQueue(label: "co.pareto.check_versions", qos: .userInteractive, attributes: .concurrent)
    var latestVersion: Version {
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

    override var isInstalled: Bool {
        applicationPath != nil
    }

    var usedRecently: Bool {
        if !Defaults[.checkForUpdatesRecentOnly] {
            return true
        }

        if isInstalled {
            if !supportsRecentlyUsed {
                return true
            }

            let app = applicationPath!.components(separatedBy: "/Contents/")[0]
            let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: app))
            guard let lastUse = attributes?.value(forAttribute: "kMDItemLastUsedDate") as? Date else { return false }
            return lastUse >= weekAgo
        }
        return false
    }

    override var isRunnable: Bool {
        // show if application is present
        return isActive && isInstalled && usedRecently
    }

    override var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return isInstalled
    }

    override var showInMenu: Bool {
        isActive && isInstalled && usedRecently
    }

    var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        var version = (appVersion(path: applicationPath!) ?? "0.0.0").lowercased()
        if version.contains("alpha") {
            version = version.replacingOccurrences(of: "alpha", with: "-alpha")
        }
        if version.contains("beta") {
            version = version.replacingOccurrences(of: "beta", with: "-beta")
        }

        version = version.replacingOccurrences(of: ".-", with: "-")

        return Version(version) ?? Version(0, 0, 0)
    }

    func getLatestVersion(completion: @escaping (String) -> Void) {
        if fromAppStore {
            getLatestVersionAppStore(completion: completion)
            return
        } else {
            os_log("Requesting %{public}s", sparkleURL)
            let versionRegex = Regex("sparkle:shortVersionString=\"([\\.\\d]+)\"")
            let versionFallbackRegex = Regex("sparkle:version=\"([\\.\\d]+)\"")
            AF.request(sparkleURL).responseString(queue: AppCheck.queue, completionHandler: { response in
                if response.error == nil {
                    let versionNew = versionRegex.allMatches(in: response.value ?? "")
                    let versionOld = versionFallbackRegex.allMatches(in: response.value ?? "")

                    if !versionNew.isEmpty {
                        let versisons = versionNew.map { $0.groups.first?.value ?? "0.0.0" }
                        let version = versisons.sorted().first ?? "0.0.0"
                        os_log("%{public}s sparkle:shortVersionString=%{public}s", self.appBundle, version)
                        completion(version)
                    } else if !versionOld.isEmpty {
                        let versisons = versionOld.map { $0.groups.first?.value ?? "0.0.0" }
                        let version = versisons.sorted().first ?? "0.0.0"
                        os_log("%{public}s sparkle:version=%{public}s", self.appBundle, version)
                        completion(version)
                    } else {
                        os_log("%{public}s failed:Sparkle=0.0.0", self.appBundle)
                        completion("0.0.0")
                    }

                } else {
                    os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
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
        if let url = URL(string: "https://paretosecurity.com/check/\(UUID)?utm_source=\(AppInfo.utmSource)&appName=\(appName.replacingOccurrences(of: " ", with: "%20"))&latestVersion=\(latestVersion)&currentVersion=\(currentVersion)&appBundle=\(appBundle)") {
            NSWorkspace.shared.open(url)
        }
    }

    override var disabledReason: String {
        get {
            if !isActive {
                return "Manually disabled"
            } else if !isInstalled {
                return "App not installed"
            } else if !usedRecently {
                return "App was not used recently"
            }
            return UserDefaults.standard.string(forKey: DisabledReasonKey) ?? "Unknown reason"
        }
        set { UserDefaults.standard.set(newValue, forKey: DisabledReasonKey) }
    }
}
