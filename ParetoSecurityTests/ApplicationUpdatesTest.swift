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

    override var appName: String { "TestApp" }
    override var appMarketingName: String { "Test App" }
    override var appBundle: String { "com.example.testapp" }
    override var applicationSearchDirectories: [String] { directories }
    override var latestVersion: Version { onlineVersion }
}

class ApplicationUpdatesTest: XCTestCase {
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

    func testMicrosoftTeamsReadsCanaryMacOSOnlineVersion() throws {
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

        XCTAssertEqual(AppMicrosoftTeamsCheck.latestMacOSVersion(from: response), "26093.311.4599.3126")
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

    func testAppVersionFetchers() throws {
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
}
