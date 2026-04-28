//
//  LibreOffice.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Version

struct EndOfLifeProductResponse: Decodable {
    let result: EndOfLifeProduct
}

struct EndOfLifeProduct: Decodable {
    let releases: [EndOfLifeRelease]
}

struct EndOfLifeRelease: Decodable {
    let isMaintained: Bool
    let latest: EndOfLifeLatestRelease
}

struct EndOfLifeLatestRelease: Decodable {
    let name: String
}

class AppLibreOfficeCheck: AppCheck {
    static let sharedInstance = AppLibreOfficeCheck()
    private let latestVersionsLock = OSAllocatedUnfairLock<[Version]>(initialState: [Version(0, 0, 0)])
    private let latestVersionsInFlight = OSAllocatedUnfairLock(initialState: false)

    override var appName: String { "LibreOffice" }
    override var appMarketingName: String { "LibreOffice" }
    override var appBundle: String { "org.libreoffice.script" }

    override var UUID: String {
        "5726931a-264a-5758-b7dd-d09285ac4b7f"
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    static func latestVersions(from response: EndOfLifeProductResponse) -> [String] {
        var versions = [String]()
        for release in response.result.releases where release.isMaintained {
            let version = normalizeVersion(release.latest.name)
            if !versions.contains(version) {
                versions.append(version)
            }
        }
        return versions
    }

    private static func normalizeVersion(_ version: String) -> String {
        version.split(separator: ".").prefix(3).joined(separator: ".")
    }

    func getLatestVersions(completion: @escaping ([String]) -> Void) {
        let url = viaEdgeCache("https://endoflife.date/api/v1/products/libreoffice/")
        os_log("Requesting %{public}s", url)
        Network.session.request(url).responseDecodable(of: EndOfLifeProductResponse.self, queue: AppCheck.queue, completionHandler: { response in
            if let value = response.value, response.error == nil {
                completion(Self.latestVersions(from: value))
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                self.hasError = true
                completion(["0.0.0"])
            }
        })
    }

    var latestVersions: [Version] {
        refreshLatestVersionsIfNeeded()
        return latestVersionsLock.withLock { $0 }
    }

    private func refreshLatestVersionsIfNeeded() {
        let shouldStart = latestVersionsInFlight.withLock { inFlight in
            if inFlight { return false }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        getLatestVersions { versions in
            let parsed = versions.map { Version($0) ?? Version(0, 0, 0) }
            self.latestVersionsLock.withLock { $0 = parsed }
            self.latestVersionsInFlight.withLock { $0 = false }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    override func checkPasses() -> Bool {
        if NetworkHandler.sharedInstance().currentStatus != .satisfied {
            return checkPassed
        }

        for version in latestVersions {
            if currentVersion >= version {
                return true
            }
        }

        return false
    }
}
