
//
//  AppCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
import Version
import Network
@testable import Pareto_Security

// Mock NetworkHandler for testing checkPasses
class MockNetworkHandler: NetworkHandler {
    static let shared = MockNetworkHandler()
    var mockCurrentStatus: NWPath.Status = .satisfied

    func sharedInstance() -> NetworkHandler {
        return MockNetworkHandler.shared
    }

    override var currentStatus: NWPath.Status {
        return mockCurrentStatus
    }
}

// Testable subclass of AppCheck to mock dependencies
class TestableAppCheck: AppCheck {
    var mockAppName: String = "MockApp"
    var mockAppMarketingName: String = "Mock Application"
    var mockAppBundle: String = "com.mock.app"
    var mockSparkleURL: String = "http://mock.sparkle.url"
    var mockApplicationPath: String? = nil
    var mockCurrentVersion: Version = Version(0, 0, 0)
    var mockLatestVersion: Version = Version(0, 0, 0)
    var mockFromAppStore: Bool = false
    var mockUsedRecently: Bool = true
    var mockTeamEnforced: Bool = false
    var mockCheckForUpdatesRecentOnly: Bool = true

    override var appName: String { return mockAppName }
    override var appMarketingName: String { return mockAppMarketingName }
    override var appBundle: String { return mockAppBundle }
    override var sparkleURL: String { return mockSparkleURL }

    override var applicationPath: String? {
        return mockApplicationPath
    }

    override var currentVersion: Version {
        return mockCurrentVersion
    }

    override var latestVersion: Version {
        return mockLatestVersion
    }

    override var fromAppStore: Bool {
        return mockFromAppStore
    }

    override var usedRecently: Bool {
        return mockUsedRecently
    }

    override var teamEnforced: Bool {
        return mockTeamEnforced
    }

    override func getLatestVersionAppStore(completion: @escaping (String) -> Void) {
        completion(mockLatestVersion.description)
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        completion(mockLatestVersion.description)
    }
}

class AppCheckTests: XCTestCase {

    var userDefaults: UserDefaults!
    var appCheck: TestableAppCheck!
    var mockNetworkHandler: MockNetworkHandler!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        appCheck = TestableAppCheck()
        appCheck.configure() // Ensure defaults are registered

        mockNetworkHandler = MockNetworkHandler.shared
        mockNetworkHandler.mockCurrentStatus = .satisfied // Reset to default
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        // UUID is not overridden in AppCheck, so it should be the default ParetoCheck UUID
        XCTAssertEqual(appCheck.UUID, "UUID")
    }

    func testTitles() {
        appCheck.mockAppMarketingName = "TestApp"
        XCTAssertEqual(appCheck.TitleON, "TestApp is up-to-date")
        XCTAssertEqual(appCheck.TitleOFF, "TestApp has an available update")
    }

    func testDetails() {
        appCheck.mockCurrentVersion = Version("1.0.0")
        appCheck.mockLatestVersion = Version("1.1.0")
        appCheck.mockApplicationPath = "/Applications/TestApp.app/Contents/Info.plist"
        XCTAssertTrue(appCheck.details.contains("local=1.0.0 online=1.1.0 applicationPath=/Applications/TestApp.app/Contents/Info.plist"))
    }

    func testReportIfDisabled() {
        XCTAssertFalse(appCheck.reportIfDisabled)
    }

    func testSupportsRecentlyUsed() {
        XCTAssertTrue(appCheck.supportsRecentlyUsed)
    }

    func testIsInstalled() {
        appCheck.mockApplicationPath = nil
        XCTAssertFalse(appCheck.isInstalled)

        appCheck.mockApplicationPath = "/Applications/MockApp.app/Contents/Info.plist"
        XCTAssertTrue(appCheck.isInstalled)
    }

    func testIsRunnable() {
        appCheck.isActive = true
        appCheck.mockApplicationPath = "/Applications/MockApp.app/Contents/Info.plist"
        appCheck.mockUsedRecently = true
        XCTAssertTrue(appCheck.isRunnable)

        appCheck.isActive = false
        XCTAssertFalse(appCheck.isRunnable)

        appCheck.isActive = true
        appCheck.mockApplicationPath = nil
        XCTAssertFalse(appCheck.isRunnable)

        appCheck.mockApplicationPath = "/Applications/MockApp.app/Contents/Info.plist"
        appCheck.mockUsedRecently = false
        XCTAssertFalse(appCheck.isRunnable)
    }

    func testShowSettings() {
        appCheck.mockTeamEnforced = false
        appCheck.mockApplicationPath = "/Applications/MockApp.app/Contents/Info.plist"
        XCTAssertTrue(appCheck.showSettings)

        appCheck.mockTeamEnforced = true
        XCTAssertFalse(appCheck.showSettings)

        appCheck.mockTeamEnforced = false
        appCheck.mockApplicationPath = nil
        XCTAssertFalse(appCheck.showSettings)
    }

    func testCheckPasses_upToDate() {
        appCheck.mockCurrentVersion = Version("1.0.0")!
        appCheck.mockLatestVersion = Version("1.0.0")!
        mockNetworkHandler.mockCurrentStatus = .satisfied
        XCTAssertTrue(appCheck.checkPasses())
    }

    func testCheckPasses_updateAvailable() {
        appCheck.mockCurrentVersion = Version("1.0.0")!
        appCheck.mockLatestVersion = Version("1.1.0")!
        mockNetworkHandler.mockCurrentStatus = .satisfied
        XCTAssertFalse(appCheck.checkPasses())
    }

    func testCheckPasses_noNetwork() {
        appCheck.mockCurrentVersion = Version("1.0.0")!
        appCheck.mockLatestVersion = Version("1.1.0")!
        mockNetworkHandler.mockCurrentStatus = .unsatisfied // No network
        appCheck.checkPassed = true // Simulate previous pass
        XCTAssertTrue(appCheck.checkPasses()) // Should return previous state
    }

    func testCurrentVersion_noAppPath() {
        appCheck.mockApplicationPath = nil
        XCTAssertEqual(appCheck.currentVersion, Version(0, 0, 0))
    }

    func testCurrentVersion_withAppPath_alphaBeta() {
        // Mock appVersion to return specific strings
        class MockAppCheckWithAppVersion: TestableAppCheck {
            var mockAppVersionString: String?
            func mockAppVersion(path: String, key: String = "CFBundleShortVersionString") -> String? {
                return mockAppVersionString
            }
        }

        let mockAppCheck = MockAppCheckWithAppVersion()
        mockAppCheck.mockApplicationPath = "/Applications/MockApp.app/Contents/Info.plist"

        mockAppCheck.mockAppVersionString = "1.0.0alpha"
        XCTAssertEqual(mockAppCheck.currentVersion, Version("1.0.0-alpha")!)

        mockAppCheck.mockAppVersionString = "2.0.0beta"
        XCTAssertEqual(mockAppCheck.currentVersion, Version("2.0.0-beta")!)

        mockAppCheck.mockAppVersionString = "3.0.0.alpha"
        XCTAssertEqual(mockAppCheck.currentVersion, Version("3.0.0-alpha")!)

        mockAppCheck.mockAppVersionString = "4.0.0.beta"
        XCTAssertEqual(mockAppCheck.currentVersion, Version("4.0.0-beta")!)

        mockAppCheck.mockAppVersionString = "5.0.0"
        XCTAssertEqual(mockAppCheck.currentVersion, Version("5.0.0")!)
    }
}
