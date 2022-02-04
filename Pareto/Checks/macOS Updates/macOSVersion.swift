//
//  macOSVersionCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Alamofire
import Foundation
import os.log
import Regex
import Version

class MacOSVersionCheck: ParetoCheck {
    static let sharedInstance = MacOSVersionCheck()
    override var UUID: String {
        "284162c2-f911-4b5e-8c81-30b2cf1ba73f"
    }

    override var TitleON: String {
        "macOS is up-to-date"
    }

    override var TitleOFF: String {
        "macOS is not up-to-date"
    }

    var currentVersion: Version {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return Version(os.majorVersion, os.minorVersion, os.patchVersion)
    }

    func getLatestVersion(doc: String, completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://support.apple.com/en-us/\(doc)")
        let versionRegex = Regex("<h2.*>macOS.+ ([\\.\\d]+)<\\/h2>")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<h2>macOS Dar win 1.2.5</h2>"
                var version = versionRegex.firstMatch(in: html)?.groups.first?.value ?? "1.2.3"
                if version.components(separatedBy: ".").count == 2 {
                    version = "\(version).0"
                }
                completion(version)
            } else {
                completion("0.0.0")
            }

        })
    }

    var latest11xx: Version {
        var tempVersion = "0.0.0"
        let lock = DispatchSemaphore(value: 0)
        getLatestVersion(doc: "HT211896") { version in
            tempVersion = version
            lock.signal()
        }
        lock.wait()
        return Version(tempVersion) ?? Version(0, 0, 0)
    }

    var latest12xx: Version {
        var tempVersion = "0.0.0"
        let lock = DispatchSemaphore(value: 0)
        getLatestVersion(doc: "HT212585") { version in
            tempVersion = version
            lock.signal()
        }
        lock.wait()

        return Version(tempVersion) ?? Version(0, 0, 0)
    }

    override func checkPasses() -> Bool {
        if currentVersion.major == 11 {
            return currentVersion >= latest11xx
        }
        return currentVersion >= latest12xx
    }
}
