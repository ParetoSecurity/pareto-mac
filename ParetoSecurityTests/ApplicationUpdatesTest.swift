//
//  ApplicationUpdatesTest.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 07/12/2021.
//

@testable import Pareto_Security
import Version
import XCTest

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
