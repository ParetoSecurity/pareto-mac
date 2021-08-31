//
//  Updater.swift
//  Updater
//
//  Created by Janez Troha on 27/08/2021.
//

import var AppKit.NSApp
import class AppKit.NSBackgroundActivityScheduler
import Defaults
import Foundation
import os.log
import Path
import SwiftUI
import Version

enum Error: Swift.Error {
    case bundleExecutableURL
    case codeSigningIdentity
    case invalidDownloadedBundle
    case invalidAsset
    case uptoDate
}

struct Release: Decodable {
    let tag_name: String
    let body: String
    let prerelease: Bool
    let html_url: URL

    var version: Version {
        if let ver = Version(tag_name.replacingOccurrences(of: "v", with: "")) {
            return ver
        } else {
            return Version(0, 0, 0)
        }
    }

    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        enum ContentType: Decodable {
            init(from decoder: Decoder) throws {
                switch try decoder.singleValueContainer().decode(String.self) {
                case "application/x-bzip2", "application/x-xz", "application/x-gzip":
                    self = .tar
                case "application/zip":
                    self = .zip
                default:
                    self = .unknown
                }
            }

            case zip
            case tar
            case unknown
        }

        let content_type: ContentType
    }

    let assets: [Asset]
}

private extension Array where Element == Release {
    func findViableUpdate(prerelease: Bool) throws -> Release? {
        let suitableReleases = prerelease ? self : filter { !$0.prerelease }
        guard let latestRelease = suitableReleases.sorted(by: {
            $0.version < $1.version
        }).filter({ $0.assets.count > 0 }).last else { return nil }
        return latestRelease
    }
}

public class AppUpdater {
    let owner: String
    let repo: String
    let tmpdir: URL

    var slug: String {
        return "\(owner)/\(repo)"
    }

    public init(owner: String, repo: String) {
        self.owner = owner
        self.repo = repo
        self.tmpdir = try! FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: Bundle.main.bundleURL, create: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmpdir)
    }

    func validate(_ b1: Bundle, _ b2: Bundle) -> Bool {
        b1.codeSigningIdentity == b2.codeSigningIdentity
    }

    func downloadAndUpdate(withAsset asset: Release.Asset) -> Bool {
        let lock = DispatchSemaphore(value: 0)
        var state = false
        URLSession.shared.downloadTask(with: asset.browser_download_url) { tempLocalUrl, response, error in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Success
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    os_log("Successfully downloaded. Status code: \(statusCode)")
                }
                let downloadPath = self.tmpdir.appendingPathComponent("download")
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: downloadPath)
                } catch let writeError {
                    os_log("Error creating a file \(downloadPath) : \(writeError.localizedDescription)")
                    lock.signal()
                }
                do {
                    try self.update(withApp: downloadPath, withAsset: asset)
                    state = true
                    lock.signal()
                } catch let writeError {
                    os_log("Error creating a file \(downloadPath) : \(writeError.localizedDescription)")
                    lock.signal()
                }

            } else {
                os_log("Error took place while downloading a file.")
                lock.signal()
            }
        }.resume()
        lock.wait()
        return state
    }

    func update(withApp dst: URL, withAsset asset: Release.Asset) throws {
        let bundlePath = unzip(dst, contentType: asset.content_type)
        let downloadedAppBundle = Bundle(url: bundlePath)!
        let installedAppBundle = Bundle.main
        guard let exe = downloadedAppBundle.executable, exe.exists else {
            throw Error.invalidDownloadedBundle
        }
        let finalExecutable = installedAppBundle.path / exe.relative(to: downloadedAppBundle.path)
        if validate(downloadedAppBundle, installedAppBundle) {
            do {
                try installedAppBundle.path.delete()
                os_log("Delete installedAppBundle: \(installedAppBundle)")
                try downloadedAppBundle.path.move(to: installedAppBundle.path)
                os_log("Move new app to installedAppBundle: \(installedAppBundle)")
                // runOSA(appleScript: "delay 3\n activate application \"Pareto Security\"")

                let proc = Process()
                if #available(OSX 10.13, *) {
                    proc.executableURL = finalExecutable.url
                } else {
                    proc.launchPath = finalExecutable.string
                }
                proc.launch()
                DispatchQueue.main.async {
                    NSApp.terminate(self)
                }

            } catch {
                os_log("Failed update: \(error.localizedDescription)")
                throw Error.invalidDownloadedBundle
            }
        } else {
            os_log("Failed codeSigningIdentity")
            throw Error.codeSigningIdentity
        }
    }

    func getLatestRelease() throws -> Release? {
        guard Bundle.main.executableURL != nil else {
            throw Error.bundleExecutableURL
        }
        let url = URL(string: "https://api.github.com/repos/\(slug)/releases")!
        let data = try Data(contentsOf: url)
        let releases = try JSONDecoder().decode([Release].self, from: data)
        let release = try releases.findViableUpdate(prerelease: Defaults[.betaChannel])
        return release
    }
}

extension Release: Comparable {
    static func < (lhs: Release, rhs: Release) -> Bool {
        return lhs.version < rhs.version
    }

    static func == (lhs: Release, rhs: Release) -> Bool {
        return lhs.version == rhs.version
    }
}

private func unzip(_ url: URL, contentType: Release.Asset.ContentType) -> URL {
    let proc = Process()
    if #available(OSX 10.13, *) {
        proc.currentDirectoryURL = url.deletingLastPathComponent()
    } else {
        proc.currentDirectoryPath = url.deletingLastPathComponent().path
    }

    switch contentType {
    case .tar:
        proc.launchPath = "/usr/bin/tar"
        proc.arguments = ["xf", url.path]
    case .zip:
        proc.launchPath = "/usr/bin/unzip"
        proc.arguments = [url.path]
    case .unknown:
        proc.launchPath = "/usr/bin/unzip"
        proc.arguments = [url.path]
    }
    func findApp() throws -> URL? {
        let cnts = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: [.isDirectoryKey], options: .skipsSubdirectoryDescendants)
        for url in cnts {
            guard url.pathExtension == "app" else { continue }
            guard let foo = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, foo else { continue }
            return url
        }
        return nil
    }
    proc.launch()
    proc.waitUntilExit()
    return try! findApp()!
}
