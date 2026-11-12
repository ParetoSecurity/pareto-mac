//
//  ApplicationUpdatesTest.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 07/12/2021.
//

@testable import Pareto_Security
import Version
import XCTest

private func remoteString(from url: String) async throws -> String {
    var request = URLRequest(url: URL(string: url)!)
    request.setValue("ParetoSecurityTests", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
    XCTAssertTrue((200 ..< 300).contains(statusCode))
    return String(decoding: data, as: UTF8.self)
}

private class TestAppCheck: AppCheck {
    let directories: [String]
    let onlineVersion: Version

    init(directories: [String], onlineVersion: Version = Version(2, 0, 0)) {
        self.directories = directories
        self.onlineVersion = onlineVersion
    }

    override var appName: String {
        "TestApp"
    }

    override var appMarketingName: String {
        "Test App"
    }

    override var appBundle: String {
        "com.example.testapp"
    }

    override var applicationSearchDirectories: [String] {
        directories
    }

    override var latestVersion: Version {
        onlineVersion
    }
}

private class LookupAppCheck: AppCheck {
    let directories: [String]
    let bundle = "com.example.lookup.\(Foundation.UUID().uuidString)"
    var responses: [String]
    var lookups = 0

    init(directories: [String], responses: [String]) {
        self.directories = directories
        self.responses = responses
    }

    override var appName: String {
        "TestApp"
    }

    override var appMarketingName: String {
        "Test App"
    }

    override var appBundle: String {
        bundle
    }

    override var applicationSearchDirectories: [String] {
        directories
    }

    override var isOnline: Bool {
        true
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        lookups += 1
        completion(responses.isEmpty ? "0.0.0" : responses.removeFirst())
    }

    /// Mirrors ParetoCheck.run(), which clears hasError before evaluating.
    func evaluate() -> Bool {
        hasError = false
        checkPassed = checkPasses()
        return checkPassed
    }
}

private class DelayedLookupAppCheck: AppCheck {
    let directories: [String]
    let onlineVersion: String
    let bundle = "com.example.delayed.\(Foundation.UUID().uuidString)"
    var lookups = 0

    init(directories: [String], onlineVersion: String) {
        self.directories = directories
        self.onlineVersion = onlineVersion
    }

    override var UUID: String {
        bundle
    }

    override var appName: String {
        "TestApp"
    }

    override var appMarketingName: String {
        "Test App"
    }

    override var appBundle: String {
        bundle
    }

    override var applicationSearchDirectories: [String] {
        directories
    }

    override var supportsRecentlyUsed: Bool {
        false
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        lookups += 1
        let version = onlineVersion
        AppCheck.queue.asyncAfter(deadline: .now() + 0.3) {
            completion(version)
        }
    }
}

private class LookupLibreOfficeCheck: AppLibreOfficeCheck {
    let directories: [String]
    let installedVersion: Version
    let identifier = "com.example.libreoffice.\(Foundation.UUID().uuidString)"
    var responses: [[String]]
    var lookups = 0

    init(directories: [String], installedVersion: Version, responses: [[String]]) {
        self.directories = directories
        self.installedVersion = installedVersion
        self.responses = responses
    }

    override var UUID: String {
        identifier
    }

    override var appName: String {
        "TestApp"
    }

    override var applicationSearchDirectories: [String] {
        directories
    }

    override var supportsRecentlyUsed: Bool {
        false
    }

    override var currentVersion: Version {
        installedVersion
    }

    override func getLatestVersions(completion: @escaping ([String]) -> Void) {
        lookups += 1
        completion(responses.isEmpty ? ["0.0.0"] : responses.removeFirst())
    }

    /// Mirrors ParetoCheck.run(), which clears hasError before evaluating.
    func evaluate() -> Bool {
        hasError = false
        checkPassed = checkPasses()
        return checkPassed
    }
}

class ApplicationUpdatesTest: XCTestCase {
    private func installedAppDirectory(version: String = "1.0.0") throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contents = directory.appendingPathComponent("TestApp.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = ["CFBundleShortVersionString": version] as NSDictionary
        XCTAssertTrue(plist.write(toFile: contents.appendingPathComponent("Info.plist").path, atomically: true))
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func makeLookupCheck(responses: [String]) throws -> LookupAppCheck {
        let app = try LookupAppCheck(directories: [installedAppDirectory().path], responses: responses)
        try? AppInfo.versionStorage.removeObject(forKey: app.appBundle)
        addTeardownBlock { try? AppInfo.versionStorage.removeObject(forKey: app.appBundle) }
        return app
    }

    func testAppStoreLookupRetriesDirectOnlyWhenEdgeCacheRefuses() {
        let direct = "https://itunes.apple.com/lookup?bundleId=com.tinyspeck.slackmacgap"
        let edge = "https://pareto-cache.team-niteo.workers.dev/itunes.apple.com/lookup?bundleId=com.tinyspeck.slackmacgap"

        XCTAssertTrue(AppCheck.shouldRetryDirect(statusCode: 403, requestedURL: edge, directURL: direct))
        XCTAssertFalse(AppCheck.shouldRetryDirect(statusCode: 403, requestedURL: direct, directURL: direct))
        XCTAssertFalse(AppCheck.shouldRetryDirect(statusCode: 404, requestedURL: edge, directURL: direct))
        XCTAssertFalse(AppCheck.shouldRetryDirect(statusCode: nil, requestedURL: edge, directURL: direct))
    }

    func testTailscaleReadsStandaloneAppcast() {
        XCTAssertEqual(AppTailscaleCheck.sharedInstance.sparkleURL, "https://pkgs.tailscale.com/stable/appcast.xml")
        let appcast = """
        <rss><channel><item>
            <sparkle:version>101.104.6</sparkle:version>
            <sparkle:shortVersionString>1.104.6</sparkle:shortVersionString>
        </item></channel></rss>
        """
        XCTAssertEqual(AppCheck.latestSparkleVersion(from: appcast), "1.104.6")
    }

    func testSuccessfulLookupReportsAvailableUpdate() throws {
        let app = try makeLookupCheck(responses: ["2.0.0"])

        _ = app.evaluate()
        XCTAssertFalse(app.evaluate())
        XCTAssertFalse(app.hasError)
        XCTAssertEqual(app.cachedLatestVersion, Version(2, 0, 0))
        XCTAssertEqual(app.lookups, 1)
    }

    func testFailedLookupIsNotCachedAsPassingVersion() throws {
        for response in ["0.0.0", "not an appcast", ""] {
            let app = try makeLookupCheck(responses: [response])
            app.checkPassed = false

            XCTAssertFalse(app.evaluate(), "response: \(response)")
            XCTAssertTrue(app.hasError)
            XCTAssertTrue(app.latestVersionLookupFailed)
            XCTAssertNil(app.cachedLatestVersion)
            XCTAssertNil(try? AppInfo.versionStorage.object(forKey: app.appBundle))

            // Re-running keeps the error and previous result instead of passing
            XCTAssertFalse(app.evaluate())
            XCTAssertTrue(app.hasError)
            XCTAssertEqual(app.help, "Current: 1.0.0, Latest: unknown")
            // Failed lookups are not retried immediately
            XCTAssertEqual(app.lookups, 1)
        }
    }

    func testFailedLookupPreservesPreviousPassingResult() throws {
        let app = try makeLookupCheck(responses: ["0.0.0"])
        app.checkPassed = true

        XCTAssertTrue(app.evaluate())
        XCTAssertTrue(app.hasError)
    }

    func testSuccessfulLookupClearsPreviousFailure() throws {
        let app = try makeLookupCheck(responses: ["0.0.0"])
        _ = app.evaluate()
        XCTAssertTrue(app.latestVersionLookupFailed)

        app.handleLatestVersionLookup("2.0.0")

        XCTAssertFalse(app.latestVersionLookupFailed)
        XCTAssertFalse(app.evaluate())
        XCTAssertFalse(app.hasError)
    }

    func testCachedZeroVersionIsIgnored() throws {
        let app = try makeLookupCheck(responses: ["2.0.0"])
        try AppInfo.versionStorage.setObject(Version(0, 0, 0), forKey: app.appBundle)

        XCTAssertNil(app.cachedLatestVersion)
        _ = app.evaluate()
        XCTAssertEqual(app.lookups, 1)
        XCTAssertFalse(app.evaluate())
    }

    private func installFixture(version: String) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contentsDirectory = temporaryDirectory.appendingPathComponent("TestApp.app/Contents")
        try FileManager.default.createDirectory(at: contentsDirectory, withIntermediateDirectories: true)
        let plist = ["CFBundleShortVersionString": version] as NSDictionary
        XCTAssertTrue(plist.write(toFile: contentsDirectory.appendingPathComponent("Info.plist").path, atomically: true))
        return temporaryDirectory
    }

    private func reportAfterPrefetch(installed: String, online: String) throws -> (DelayedLookupAppCheck, Bool) {
        let directory = try installFixture(version: installed)
        let app = DelayedLookupAppCheck(directories: [directory.path], onlineVersion: online)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            try? AppInfo.versionStorage.removeObject(forKey: app.appBundle)
            UserDefaults.standard.removeObject(forKey: app.EnabledKey)
            UserDefaults.standard.removeObject(forKey: app.PassesKey)
            UserDefaults.standard.removeObject(forKey: app.TimestampKey)
        }
        app.configure()
        XCTAssertTrue(app.isRunnable)

        XCTAssertTrue(Claims.prefetch([app], timeout: 5))
        return (app, app.run())
    }

    func testReportReflectsResolvedNewerVersionOnColdCache() throws {
        guard NetworkHandler.sharedInstance().currentStatus == .satisfied else {
            throw XCTSkip("Needs a satisfied network path")
        }
        let (app, result) = try reportAfterPrefetch(installed: "1.0.0", online: "2.0.0")

        XCTAssertFalse(result)
        XCTAssertEqual(app.report, "\(app.UUID):false")
        XCTAssertEqual(app.lookups, 1)
    }

    func testReportPassesWhenResolvedVersionMatches() throws {
        guard NetworkHandler.sharedInstance().currentStatus == .satisfied else {
            throw XCTSkip("Needs a satisfied network path")
        }
        let (app, result) = try reportAfterPrefetch(installed: "1.0.0", online: "1.0.0")

        XCTAssertTrue(result)
        XCTAssertEqual(app.report, "\(app.UUID):true")
    }

    func testPrefetchCompletesWhenLookupFails() throws {
        let (app, _) = try reportAfterPrefetch(installed: "1.0.0", online: "0.0.0")

        XCTAssertTrue(app.latestVersionLookupFailed)
        XCTAssertNil(try? AppInfo.versionStorage.object(forKey: app.appBundle))
    }

    func testPrefetchCompletesWhenRecentLookupFailed() throws {
        let app = try makeLookupCheck(responses: ["0.0.0", "2.0.0"])
        app.configure()
        addTeardownBlock {
            UserDefaults.standard.removeObject(forKey: app.EnabledKey)
            UserDefaults.standard.removeObject(forKey: app.PassesKey)
            UserDefaults.standard.removeObject(forKey: app.TimestampKey)
        }
        XCTAssertTrue(Claims.prefetch([app], timeout: 1))
        XCTAssertTrue(app.latestVersionLookupFailed)

        // A failed lookup is not retried right away, so the second prefetch must not wait for one
        XCTAssertTrue(Claims.prefetch([app], timeout: 1))
        XCTAssertEqual(app.lookups, 1)
    }

    func testPrefetchSkipsLookupWhenVersionIsCached() throws {
        let directory = try installFixture(version: "1.0.0")
        let app = DelayedLookupAppCheck(directories: [directory.path], onlineVersion: "2.0.0")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? AppInfo.versionStorage.removeObject(forKey: app.appBundle)
        }
        try AppInfo.versionStorage.setObject(Version(1, 0, 0), forKey: app.appBundle)

        XCTAssertTrue(Claims.prefetch([app], timeout: 1))
        XCTAssertEqual(app.lookups, 0)
    }

    func testUninstalledAppDoesNotFailWithCachedLatestVersion() {
        let app = TestAppCheck(directories: [])
        app.checkPassed = false

        XCTAssertTrue(app.checkPasses())
    }

    func testApplicationUpdateDetailsIncludeFoundLocation() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let appDirectory = temporaryDirectory.appendingPathComponent("TestApp.app")
        let contentsDirectory = appDirectory.appendingPathComponent("Contents")
        let infoPlist = contentsDirectory.appendingPathComponent("Info.plist")

        try FileManager.default.createDirectory(at: contentsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let plist = ["CFBundleShortVersionString": "1.0.0"] as NSDictionary
        XCTAssertTrue(plist.write(toFile: infoPlist.path, atomically: true))

        let app = TestAppCheck(directories: [temporaryDirectory.path])

        XCTAssertEqual(app.applicationPath, infoPlist.path)
        XCTAssertEqual(app.applicationLocation, appDirectory.path)
        XCTAssertEqual(app.details, appDirectory.path)
    }

    func testMicrosoftTeamsNormalizesFourPartVersions() {
        XCTAssertEqual(AppMicrosoftTeamsCheck.normalizedVersion("26093.311.4599.3126"), "26093.311.4599")
        XCTAssertEqual(AppMicrosoftTeamsCheck.normalizedVersion("26093.415.4620.1935"), "26093.415.4620")
    }

    func testMicrosoftTeamsReadsStableMacOSOnlineVersion() throws {
        let json = """
        {
          "BuildSettings": {
            "WebView2": {
              "macOS": {
                "latestVersion": "25290.302.4044.3989"
              }
            },
            "WebView2Canary": {
              "macOS": {
                "latestVersion": "26093.311.4599.3126"
              }
            }
          }
        }
        """

        let response = try JSONDecoder().decode(TeamsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(AppMicrosoftTeamsCheck.latestMacOSVersion(from: response), "25290.302.4044.3989")
    }

    func testLibreOfficeParserReadsMaintainedEndOfLifeVersions() throws {
        let json = """
        {
          "result": {
            "releases": [
              {
                "isMaintained": true,
                "latest": {
                  "name": "26.2.2.2"
                }
              },
              {
                "isMaintained": true,
                "latest": {
                  "name": "25.8.6.2"
                }
              },
              {
                "isMaintained": false,
                "latest": {
                  "name": "25.2.7.2"
                }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(EndOfLifeProductResponse.self, from: Data(json.utf8))
        let versions = AppLibreOfficeCheck.latestVersions(from: response)

        XCTAssertEqual(versions, ["26.2.2", "25.8.6"])
    }

    func testProtonMailParserReadsStableRelease() throws {
        let json = """
        {
          "Releases": [
            {
              "CategoryName": "EarlyAccess",
              "Version": "1.13.4"
            },
            {
              "CategoryName": "Stable",
              "Version": "1.13.3"
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(ProtonMailReleasesResponse.self, from: Data(json.utf8))

        XCTAssertEqual(AppProtonMailCheck.latestStableVersion(from: response), "1.13.3")
    }

    func testProtonVPNParserSkipsBetaChannel() {
        let response = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
                <item>
                    <sparkle:channel>beta</sparkle:channel>
                    <enclosure sparkle:shortVersionString="6.6.0" />
                </item>
                <item>
                    <enclosure sparkle:shortVersionString="6.5.1" />
                </item>
            </channel>
        </rss>
        """

        XCTAssertEqual(AppCheck.latestSparkleVersion(from: response, excludedChannel: "beta"), "6.5.1")
    }

    func testProtonDriveParserReadsStableChannel() {
        let response = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
                <item>
                    <sparkle:channel>gradual-rollout</sparkle:channel>
                    <sparkle:shortVersionString>3.1.0</sparkle:shortVersionString>
                </item>
                <item>
                    <sparkle:channel>stable</sparkle:channel>
                    <sparkle:shortVersionString>3.0.0</sparkle:shortVersionString>
                </item>
            </channel>
        </rss>
        """

        XCTAssertEqual(AppCheck.latestSparkleVersion(from: response, channel: "stable"), "3.0.0")
    }

    func testAnyDeskParserReadsLatestMacOSRelease() {
        let response = """
        25.06.2026 - 9.7.8 (Windows)
        ------------------

        15.06.2026 - 9.7.1 (macOS)
        ------------------
        """

        XCTAssertEqual(AppAnyDeskCheck.latestMacOSVersion(from: response), "9.7.1")
    }

    func testZoomParserReadsMacOSSlowTrackRelease() {
        let response = """
        <table>
            <tbody>
                <tr class="table-row"><td><a href="windows">Windows</a></td><td>7.1.0</td><td>7.0.5</td><td>7.0.5</td><td>5.17.5</td></tr>
                <tr class="table-row"><td><a href="macos">macOS</a></td><td>7.1.0</td><td>7.0.5</td><td>7.0.5</td><td>6.0.2</td></tr>
            </tbody>
        </table>
        """

        XCTAssertEqual(AppZoomCheck.latestMacOSSlowTrackVersion(from: response), "7.0.5")
    }

    func testAnyDeskParserReadsRemoteChangelog() async throws {
        let response = try await remoteString(from: "https://download.anydesk.com/changelog.txt")

        XCTAssertNotEqual(AppAnyDeskCheck.latestMacOSVersion(from: response), "0.0.0")
    }

    func testProtonMailParserReadsRemoteVersionJson() async throws {
        let response = try await remoteString(from: "https://proton.me/download/mail/macos/version.json")
        let releases = try JSONDecoder().decode(ProtonMailReleasesResponse.self, from: Data(response.utf8))

        XCTAssertNotEqual(AppProtonMailCheck.latestStableVersion(from: releases), "0.0.0")
    }

    func testProtonDriveParserReadsRemoteAppcast() async throws {
        let response = try await remoteString(from: "https://proton.me/download/drive/macos/appcast.xml")

        XCTAssertNotEqual(AppCheck.latestSparkleVersion(from: response, channel: "stable"), "0.0.0")
    }

    func testProtonVPNParserReadsRemoteAppcast() async throws {
        let response = try await remoteString(from: "https://protonvpn.com/download/macos/updates/v5/sparkle.xml")

        XCTAssertNotEqual(AppCheck.latestSparkleVersion(from: response, excludedChannel: "beta"), "0.0.0")
    }

    func testZoomParserReadsRemoteSupportPage() async throws {
        let response = try await remoteString(from: "https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0061900")

        XCTAssertNotEqual(AppZoomCheck.latestMacOSSlowTrackVersion(from: response), "0.0.0")
    }

    func testRequestedAppsAreRegisteredForApplicationUpdates() {
        let appNames = Set(Claims.updateChecks.map(\.appMarketingName))

        XCTAssertTrue(appNames.isSuperset(of: [
            "AnyDesk",
            "Proton Drive",
            "Proton Mail",
            "Proton VPN",
        ]))
    }

    func testRequestedAppsUseExpectedMetadata() {
        let apps: [(AppCheck, String, String, String, String)] = [
            (AppAnyDeskCheck.sharedInstance, "AnyDesk", "AnyDesk", "com.philandro.anydesk", "07316cac-018e-595f-bd89-eb894cca7446"),
            (AppProtonDriveCheck.sharedInstance, "Proton Drive", "Proton Drive", "ch.protonmail.drive", "93b44905-9f61-5d78-84dd-cdc5479165d7"),
            (AppProtonMailCheck.sharedInstance, "Proton Mail", "Proton Mail", "ch.protonmail.desktop", "ad898b64-b6ae-5835-aa3c-261dd41d8583"),
            (AppProtonVPNCheck.sharedInstance, "ProtonVPN", "Proton VPN", "ch.protonvpn.mac", "ef8f7dfc-b7d4-5999-8e66-fb5cf1e5252e"),
        ]

        for (app, appName, appMarketingName, appBundle, uuid) in apps {
            XCTAssertEqual(app.appName, appName)
            XCTAssertEqual(app.appMarketingName, appMarketingName)
            XCTAssertEqual(app.appBundle, appBundle)
            XCTAssertEqual(app.UUID, uuid)
        }
    }

    func testAppVersionFetchers() {
        var redirects = [String]()
        var names = [String]()
        for app in Claims.updateChecks.sorted(by: { $0.appMarketingName.lowercased() < $1.appMarketingName.lowercased() }) {
            XCTAssertNotEqual(app.usedRecently, nil)
            XCTAssertNotEqual(app.latestVersion, nil)
            XCTAssertNotEqual(app.UUID, nil)
            XCTAssertNotEqual(app.currentVersion, nil)
            XCTAssertFalse(app.reportIfDisabled)
            redirects.append("<permanent-redirect tal:omit-tag from=\"https://paretosecurity.com/check/\(app.UUID)\" />")
            names.append("<li>\(app.appMarketingName)\"</li>")
        }
        print(redirects.joined(separator: "\n"))
        print(names.joined(separator: "\n"))
    }

    // MARK: - Lookup errors in reports

    private func requireNetwork() throws {
        guard NetworkHandler.sharedInstance().currentStatus == .satisfied else {
            throw XCTSkip("Needs a satisfied network path")
        }
    }

    func testReportShowsErrorWhenLookupFails() throws {
        try requireNetwork()
        let (app, _) = try reportAfterPrefetch(installed: "1.0.0", online: "0.0.0")

        XCTAssertTrue(app.hasError)
        XCTAssertEqual(app.report, "\(app.UUID):error")
        let record = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(app.reportJSON.utf8)) as? [String: String]
        )
        XCTAssertEqual(record["hasError"], "true")
    }

    private func makeLibreOfficeCheck(installed: Version, responses: [[String]]) throws -> LookupLibreOfficeCheck {
        let directory = try installFixture(version: installed.description)
        let app = LookupLibreOfficeCheck(directories: [directory.path], installedVersion: installed, responses: responses)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removeObject(forKey: app.EnabledKey)
            UserDefaults.standard.removeObject(forKey: app.PassesKey)
            UserDefaults.standard.removeObject(forKey: app.TimestampKey)
        }
        return app
    }

    func testLibreOfficeFailedLookupReportsError() throws {
        try requireNetwork()
        for response in [["0.0.0"], [], ["not a version"]] {
            let app = try makeLibreOfficeCheck(installed: Version(25, 8, 6), responses: [response])
            app.checkPassed = false

            XCTAssertFalse(app.evaluate(), "response: \(response)")
            XCTAssertTrue(app.hasError)
            XCTAssertTrue(app.latestReleasesLookupFailed)
            XCTAssertNil(app.latestVersions)

            // Re-running keeps the error instead of passing, and does not retry right away
            XCTAssertFalse(app.evaluate())
            XCTAssertTrue(app.hasError)
            XCTAssertEqual(app.lookups, 1)
        }
    }

    func testLibreOfficeFailedLookupPreservesPreviousPassingResult() throws {
        try requireNetwork()
        let app = try makeLibreOfficeCheck(installed: Version(25, 8, 6), responses: [["0.0.0"]])
        app.checkPassed = true

        XCTAssertTrue(app.evaluate())
        XCTAssertTrue(app.hasError)
    }

    func testLibreOfficeComparesAgainstMaintainedReleases() throws {
        try requireNetwork()
        let current = try makeLibreOfficeCheck(installed: Version(25, 8, 6), responses: [["26.2.2", "25.8.6"]])
        XCTAssertTrue(Claims.prefetch([current], timeout: 1))
        XCTAssertTrue(current.evaluate())
        XCTAssertFalse(current.hasError)

        let outdated = try makeLibreOfficeCheck(installed: Version(25, 8, 5), responses: [["26.2.2", "25.8.6"]])
        XCTAssertTrue(Claims.prefetch([outdated], timeout: 1))
        XCTAssertFalse(outdated.evaluate())
        XCTAssertFalse(outdated.hasError)
        XCTAssertEqual(outdated.lookups, 1)
    }

    func testLibreOfficeSuccessfulLookupClearsPreviousFailure() throws {
        try requireNetwork()
        let app = try makeLibreOfficeCheck(installed: Version(25, 8, 6), responses: [["0.0.0"]])
        _ = app.evaluate()
        XCTAssertTrue(app.latestReleasesLookupFailed)

        app.handleLatestVersionsLookup(["26.2.2", "25.8.6"])

        XCTAssertFalse(app.latestReleasesLookupFailed)
        XCTAssertTrue(app.evaluate())
        XCTAssertFalse(app.hasError)
    }

    func testLibreOfficePrefetchCompletesAfterRecentFailure() throws {
        let app = try makeLibreOfficeCheck(installed: Version(25, 8, 6), responses: [["0.0.0"], ["26.2.2"]])
        app.configure()
        XCTAssertTrue(app.isRunnable)

        XCTAssertTrue(Claims.prefetch([app], timeout: 1))
        XCTAssertTrue(app.latestReleasesLookupFailed)
        XCTAssertTrue(Claims.prefetch([app], timeout: 1))
        XCTAssertEqual(app.lookups, 1)
    }
}
