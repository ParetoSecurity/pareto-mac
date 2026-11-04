//
//  macOSVersionCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Alamofire
import Foundation
import IOKit
import os.log
import Version

typealias AsyncCommandRunner = @Sendable (_ app: String, _ args: [String], _ timeout: TimeInterval) async throws -> String

class MacOSVersionCheck: ParetoCheck {
    static let sharedInstance = MacOSVersionCheck()
    private let latestVersionLock = OSAllocatedUnfairLock<Version>(initialState: Version(0, 0, 0))
    private let latestVersionSourceLock = OSAllocatedUnfairLock<String>(initialState: "unresolved")
    private let latestVersionInFlight = OSAllocatedUnfairLock(initialState: false)
    var commandRunner: AsyncCommandRunner = { app, args, timeout in
        try await runCMDAsync(app: app, args: args, timeout: timeout)
    }

    var gdmfVersionProvider: (@Sendable () async -> Version?)?

    /// Apple's public catalog of macOS releases, one entry per supported major version.
    /// This is the feed MDM servers use for software update enforcement.
    static let gdmfURL = "https://gdmf.apple.com/v2/pmv"
    override var UUID: String {
        "284162c2-f911-4b5e-8c81-30b2cf1ba73f"
    }

    override var TitleON: String {
        "macOS is up-to-date"
    }

    override var TitleOFF: String {
        "macOS is not up-to-date"
    }

    override var details: String {
        let latestVersion = latestVersionLock.withLock { $0 }
        let source = latestVersionSourceLock.withLock { $0 }

        if latestVersion == Version(0, 0, 0) {
            return "current=\(currentVersion) latest=unknown source=\(source)"
        }

        return "current=\(currentVersion) latest=\(latestVersion) source=\(source)"
    }

    override var help: String? {
        let latestVersion = latestVersionLock.withLock { $0 }
        if latestVersion == Version(0, 0, 0) {
            return "Current: \(currentVersion), Latest: unknown"
        }

        return "Current: \(currentVersion), Latest: \(latestVersion)"
    }

    var currentVersion: Version {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return Version(os.majorVersion, os.minorVersion, os.patchVersion)
    }

    static func normalizeVersion(_ rawVersion: String) -> Version? {
        var version = rawVersion
        if version.components(separatedBy: ".").count == 2 {
            version += ".0"
        }
        return Version(version)
    }

    // MARK: - GDMF

    private struct GDMFResponse: Decodable {
        let publicAssetSets: GDMFAssetSets?
        let assetSets: GDMFAssetSets?

        enum CodingKeys: String, CodingKey {
            case publicAssetSets = "PublicAssetSets"
            case assetSets = "AssetSets"
        }
    }

    private struct GDMFAssetSets: Decodable {
        let macOS: [GDMFAsset]?
    }

    private struct GDMFAsset: Decodable {
        let productVersion: String
        let supportedDevices: [String]?

        enum CodingKeys: String, CodingKey {
            case productVersion = "ProductVersion"
            case supportedDevices = "SupportedDevices"
        }
    }

    /// Picks the latest public release for `currentMajor` from a GDMF response.
    ///
    /// When `deviceID` is known, releases that ship to this device win, so a release built
    /// for specific models only (e.g. 26.3.2 for MacBook Neo) is not required of other Macs.
    static func parseLatestVersion(fromGDMF data: Data, currentMajor: Int, deviceID: String?) -> Version? {
        guard let response = try? JSONDecoder().decode(GDMFResponse.self, from: data) else {
            return nil
        }

        func candidates(_ assets: [GDMFAsset]?) -> [(version: Version, devices: [String])] {
            (assets ?? []).compactMap { asset in
                guard let version = normalizeVersion(asset.productVersion), version.major == currentMajor else {
                    return nil
                }
                return (version, asset.supportedDevices ?? [])
            }
        }

        let published = candidates(response.publicAssetSets?.macOS)
        guard !published.isEmpty else { return nil }

        if let deviceID {
            if let latest = published.filter({ $0.devices.contains(deviceID) }).map(\.version).max() {
                return latest
            }
            // The public release for this major skips this device; use the newest one that ships to it.
            if let latest = candidates(response.assetSets?.macOS).filter({ $0.devices.contains(deviceID) }).map(\.version).max() {
                return latest
            }
        }

        return published.map(\.version).max()
    }

    /// Identifier GDMF uses in `SupportedDevices`: `target-sub-type` on Apple silicon and VMs
    /// (e.g. `J314sAP`), `board-id` on Intel (e.g. `Mac-1E7E29AD0135F9BC`).
    static func deviceIdentifier() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        for key in ["target-sub-type", "board-id"] {
            guard let property = IORegistryEntryCreateCFProperty(platformExpert, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
            else { continue }

            let value: String? = if let data = property as? Data {
                String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\u{0}"))
            } else {
                property as? String
            }
            if let value, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    // MARK: - softwareupdate

    static func parseLatestVersion(fromSoftwareUpdateOutput output: String, currentMajor: Int) -> Version? {
        let nsOutput = output as NSString
        let patterns = [
            #"(?m)^\s*\*?\s*Title:\s*macOS[^\n]*?,\s*Version:\s*([\d.]+)"#,
            #"(?m)^\s*\*?\s*Label:\s*macOS[^\n]*?\s([\d.]+)(?:[-,\s]|$)"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsOutput.length))
            let versions = matches.compactMap { match -> Version? in
                guard match.numberOfRanges > 1 else { return nil }
                return normalizeVersion(nsOutput.substring(with: match.range(at: 1)))
            }

            if let sameMajor = versions.filter({ $0.major == currentMajor }).max() {
                return sameMajor
            }
        }

        return nil
    }

    static func isCurrentVersionUpToDate(current: Version, latest: Version) -> Bool {
        // Special case: macOS 26.3.2 is only offered to MacBook Neo devices, but this check
        // compares against Apple's global latest version and would otherwise warn all 26.3.1 Macs.
        if current == Version(26, 3, 1), latest == Version(26, 3, 2) {
            return true
        }

        return current >= latest
    }

    func getLatestVersion(completion: @escaping (Version, String) -> Void) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else {
                completion(Version(0, 0, 0), "unresolved")
                return
            }

            if let gdmfVersion = await getLatestVersionFromGDMF() {
                completion(gdmfVersion, "gdmf")
                return
            }

            if let softwareUpdateVersion = await getLatestVersionFromSoftwareUpdate() {
                completion(softwareUpdateVersion, "softwareupdate")
                return
            }

            completion(Version(0, 0, 0), "unresolved")
        }
    }

    private func getLatestVersionFromGDMF() async -> Version? {
        if let gdmfVersionProvider {
            return await gdmfVersionProvider()
        }

        let currentMajor = currentVersion.major
        let deviceID = Self.deviceIdentifier()
        os_log("Determining latest macOS %d.x via GDMF for device %{public}@", log: Log.check, currentMajor, deviceID ?? "unknown")

        return await withCheckedContinuation { continuation in
            Network.session.request(Self.gdmfURL).validate().responseData(queue: AppCheck.queue) { response in
                switch response.result {
                case let .success(data):
                    let parsedVersion = Self.parseLatestVersion(fromGDMF: data, currentMajor: currentMajor, deviceID: deviceID)
                    os_log("GDMF resolved latest macOS version to %{public}@", log: Log.check, parsedVersion?.description ?? "unknown")
                    continuation.resume(returning: parsedVersion)
                case let .failure(error):
                    os_log("GDMF lookup failed: %{public}@", log: Log.check, error.localizedDescription)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func getLatestVersionFromSoftwareUpdate() async -> Version? {
        do {
            os_log("Determining latest macOS version via softwareupdate", log: Log.check)
            let output = try await commandRunner("/usr/sbin/softwareupdate", ["--list"], 20.0)
            let parsedVersion = Self.parseLatestVersion(fromSoftwareUpdateOutput: output, currentMajor: currentVersion.major)
            os_log("softwareupdate resolved latest macOS version to %{public}@", log: Log.check, parsedVersion?.description ?? "unknown")
            return parsedVersion
        } catch {
            os_log("softwareupdate lookup failed: %{public}@", log: Log.check, error.localizedDescription)
            return nil
        }
    }

    func storeResolvedLatestVersion(_ version: Version, source: String) {
        latestVersionLock.withLock { $0 = version }
        latestVersionSourceLock.withLock { $0 = source }
    }

    var latestXX: Version {
        refreshLatestVersionIfNeeded()
        return latestVersionLock.withLock { $0 }
    }

    private func refreshLatestVersionIfNeeded() {
        let shouldStart = latestVersionInFlight.withLock { inFlight in
            if inFlight {
                return false
            }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        getLatestVersion { version, source in
            self.storeResolvedLatestVersion(version, source: source)
            self.latestVersionInFlight.withLock { $0 = false }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    override func checkPasses() -> Bool {
        Self.isCurrentVersionUpToDate(current: currentVersion, latest: latestXX)
    }
}
