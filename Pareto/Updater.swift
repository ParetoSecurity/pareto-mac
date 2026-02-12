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

extension AppUpdater {
    /// Uses ditto to preserve code signatures and permissions when copying app bundles
    static func safeCopyBundle(from source: String, to destination: String) throws {
        // First remove destination if it exists
        if FileManager.default.fileExists(atPath: destination) {
            try FileManager.default.removeItem(atPath: destination)
        }

        // Use ditto to preserve all metadata including code signatures
        let dittoProc = Process()
        dittoProc.launchPath = "/usr/bin/ditto"
        dittoProc.arguments = [source, destination]
        dittoProc.launch()
        dittoProc.waitUntilExit()

        if dittoProc.terminationStatus != 0 {
            throw Error.invalidDownloadedBundle
        }

        os_log("Successfully copied bundle from \(source) to \(destination)")
    }
}

struct Release: Decodable {
    let tag_name: String
    let body: String
    let prerelease: Bool
    let html_url: URL
    let published_at: String

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
        let size: Int
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

extension Array where Element == Release {
    func findViableUpdate(prerelease: Bool, currentVersion: Version) throws -> Release? {
        let suitableReleases = prerelease ? self : filter { !$0.prerelease }
        return suitableReleases
            .filter { !$0.assets.isEmpty && $0.version > currentVersion }
            .max(by: { $0.version < $1.version })
    }
}

public class AppUpdater {
    let owner: String
    let repo: String

    var slug: String {
        return "\(owner)/\(repo)"
    }

    public init(owner: String, repo: String) {
        self.owner = owner
        self.repo = repo
    }

    func validate(_ b1: Bundle, _ b2: Bundle) -> Bool {
        b1.codeSigningIdentity == b2.codeSigningIdentity
    }

    func downloadAndUpdate(withAsset asset: Release.Asset) async -> Bool {
        #if DEBUG
            os_log("In debug build updates are disabled")
            return false
        #else
            guard let tmpDir = try? FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: Bundle.main.bundleURL,
                create: true
            ) else {
                os_log("Failed to create temporary directory for update", log: Log.app)
                return false
            }
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            do {
                var request = URLRequest(url: asset.browser_download_url)
                request.timeoutInterval = 60.0
                let (localUrl, response) = try await URLSession.shared.download(for: request)

                guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                    os_log("Could not parse response of %{public}@", log: Log.app, asset.browser_download_url.absoluteString)
                    return false
                }

                guard statusCode == 200 else {
                    os_log("Failed to download %{public}@. Status code: %{public}d", log: Log.app, asset.browser_download_url.absoluteString, statusCode)
                    return false
                }

                guard localUrl.fileSize == asset.size else {
                    os_log("Error updating from %{public}@, wrong file size", log: Log.app, asset.browser_download_url.absoluteString)
                    return false
                }

                os_log("Successfully downloaded %{public}@. Status code: %{public}d", log: Log.app, asset.browser_download_url.absoluteString, statusCode)
                let downloadPath = tmpDir.appendingPathComponent("download")
                if FileManager.default.fileExists(atPath: downloadPath.path) {
                    try? FileManager.default.removeItem(at: downloadPath)
                }
                try FileManager.default.copyItem(at: localUrl, to: downloadPath)

                os_log("Doing update from %{public}@", log: Log.app, localUrl.path)
                try self.update(withApp: downloadPath, withAsset: asset)
                return true
            } catch {
                os_log("Error updating with asset %{public}@ : %{public}@", log: Log.app, asset.browser_download_url.absoluteString, error.localizedDescription)
                return false
            }
        #endif
    }

    static func runCMDasAdmin(cmd: String) -> Bool {
        let code =
            """
            do shell script "\(cmd)" with administrator privileges
            """
        os_log("\(code)")
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: code) {
            scriptObject.executeAndReturnError(&error)
            if error != nil {
                os_log("OSA Error: %{public}@", error.debugDescription)
                return false
            }
        }
        return true
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
                // Determine if the installed app is in user's Applications (~/Applications)
                let userApplicationsURL: URL? = {
                    if let url = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first {
                        return url
                    }
                    // Fallback to ~/Applications if the above ever fails
                    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
                }()

                let installedURL = installedAppBundle.bundleURL.resolvingSymlinksInPath()
                let userAppsURL = userApplicationsURL?.resolvingSymlinksInPath()

                let isInUserApplications: Bool = {
                    guard let userAppsURL else { return false }
                    let installedPath = installedURL.standardizedFileURL.path
                    let userAppsPath = userAppsURL.standardizedFileURL.path
                    return installedPath.hasPrefix(userAppsPath + "/")
                        || installedPath == userAppsPath // in case the bundle is exactly at ~/Applications (unlikely)
                }()

                if SystemUser.current.isAdmin || isInUserApplications {
                    try AppUpdater.safeCopyBundle(from: downloadedAppBundle.path.string, to: installedAppBundle.path.string)
                } else {
                    let path = "\(downloadedAppBundle.path)/Contents/MacOS/Pareto Security".shellEscaped()
                    _ = AppUpdater.runCMDasAdmin(cmd: "\(path) -update")
                }

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

    func getLatestRelease() async throws -> Release? {
        guard Bundle.main.executableURL != nil else {
            throw Error.bundleExecutableURL
        }
        do {
            let releases = try await UpdateService.shared.getUpdatesAsync()
            let release = try releases.findViableUpdate(prerelease: Defaults.betaChannelComputed, currentVersion: Bundle.main.version)
            return release
        } catch {
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError, .decodingError:
                    throw Error.invalidAsset
                default:
                    throw Error.invalidAsset
                }
            }
            throw error
        }
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
    let extractDir = url.deletingLastPathComponent()

    if #available(OSX 10.13, *) {
        proc.currentDirectoryURL = extractDir
    } else {
        proc.currentDirectoryPath = extractDir.path
    }

    switch contentType {
    case .tar:
        proc.launchPath = "/usr/bin/tar"
        proc.arguments = ["xf", url.path]
    case .zip:
        // Use ditto to properly extract zip files and preserve code signatures
        proc.launchPath = "/usr/bin/ditto"
        proc.arguments = ["-xk", url.path, extractDir.path]
    case .unknown:
        // Default to ditto for unknown types as well
        proc.launchPath = "/usr/bin/ditto"
        proc.arguments = ["-xk", url.path, extractDir.path]
    }

    func findApp() throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsSubdirectoryDescendants)
        for url in files {
            guard url.pathExtension == "app" else { continue }
            guard let foo = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, foo else { continue }
            return url
        }
        return nil
    }

    proc.launch()
    proc.waitUntilExit()

    if proc.terminationStatus != 0 {
        os_log("Failed to extract archive: \(url.path)")
    }

    return try! findApp()!
}
