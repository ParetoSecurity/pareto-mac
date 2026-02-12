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
    private let latestVersionLock = OSAllocatedUnfairLock<Version>(initialState: Version(0, 0, 0))
    private let latestVersionInFlight = OSAllocatedUnfairLock(initialState: false)
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
        let url = "https://support.apple.com/en-us/\(doc)"
        let versionRegex = Regex("<h2.*>macOS.+ ([\\.\\d]+)<\\/h2>")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: AppCheck.queue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<h2>macOS 1.2.5</h2>"
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

    var latestXX: Version {
        var doc = "HT211896"
        if #available(macOS 12, *) {
            doc = "HT212585"
        }
        if #available(macOS 13, *) {
            doc = "HT213268"
        }
        if #available(macOS 14, *) {
            doc = "HT213895"
        }
        if #available(macOS 15, *) {
            doc = "120283"
        }
        if #available(macOS 26, *) {
            doc = "122868"
        }
        refreshLatestVersionIfNeeded(doc: doc)
        return latestVersionLock.withLock { $0 }
    }

    private func refreshLatestVersionIfNeeded(doc: String) {
        let shouldStart = latestVersionInFlight.withLock { inFlight in
            if inFlight { return false }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        getLatestVersion(doc: doc) { version in
            let parsed = Version(version) ?? Version(0, 0, 0)
            self.latestVersionLock.withLock { $0 = parsed }
            self.latestVersionInFlight.withLock { $0 = false }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    override func checkPasses() -> Bool {
        return currentVersion >= latestXX
    }
}
