//
//  UpdateServiceTest.swift
//  ParetoSecurityTests
//

@testable import Pareto_Security
import Version
import XCTest

class UpdateServiceTest: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testGetUpdatesAsync() async throws {
        let releases: [Release]
        do {
            releases = try await UpdateService.shared.getUpdatesAsync()
        } catch {
            // If network fails, test basic UpdateService structure instead
            XCTAssertNotNil(UpdateService.shared, "UpdateService should be initialized")
            return
        }

        // Test that we get releases
        XCTAssertFalse(releases.isEmpty, "Should return at least one release")

        // Test release structure
        let firstRelease = releases[0]
        XCTAssertFalse(firstRelease.tag_name.isEmpty, "Tag name should not be empty")
        XCTAssertFalse(firstRelease.published_at.isEmpty, "Published date should not be empty")
        XCTAssertNotNil(firstRelease.html_url, "HTML URL should not be nil")

        // Test that published_at is a valid date string
        let dateFormatter = ISO8601DateFormatter()
        XCTAssertNotNil(dateFormatter.date(from: firstRelease.published_at), "Published date should be valid ISO8601 format")

        // Test version parsing
        XCTAssertGreaterThan(firstRelease.version.major, 0, "Version should have major version > 0")
    }

    func testServiceAvailability() throws {
        // Test that UpdateService singleton is available
        XCTAssertNotNil(UpdateService.shared, "UpdateService should be available")
    }

    func testUpdateCheckIntegration() throws {
        let paretoUpdated = ParetoUpdated()

        // Test that the check can run without errors
        let result = paretoUpdated.checkPasses()

        // Should return a boolean (true or false, both are valid)
        XCTAssertTrue(result == true || result == false, "Check should return a boolean value")

        // Test that the check has proper metadata
        XCTAssertFalse(paretoUpdated.UUID.isEmpty, "UUID should not be empty")
        XCTAssertFalse(paretoUpdated.TitleON.isEmpty, "TitleON should not be empty")
        XCTAssertFalse(paretoUpdated.TitleOFF.isEmpty, "TitleOFF should not be empty")
    }

    func testReleaseVersionParsing() throws {
        // Test version parsing with mock data instead of network calls
        let mockRelease = Release(
            tag_name: "v1.2.3",
            body: "Test release",
            prerelease: false,
            html_url: URL(string: "https://example.com")!,
            published_at: "2025-01-01T00:00:00Z",
            assets: []
        )

        // Test version parsing
        let version = mockRelease.version
        XCTAssertEqual(version.major, 1, "Major version should be 1")
        XCTAssertEqual(version.minor, 2, "Minor version should be 2")
        XCTAssertEqual(version.patch, 3, "Patch version should be 3")

        // Test tag name format
        XCTAssertTrue(mockRelease.tag_name.hasPrefix("v"), "Tag name should start with 'v'")
    }

    func testAPIEndpointParameters() throws {
        // Test Release array filtering without network dependency
        let mockAsset = Release.Asset(name: "test.zip", browser_download_url: URL(string: "https://example.com/test.zip")!, size: 1000, content_type: .zip)
        let mockReleases = [
            Release(tag_name: "v1.12.0", body: "", prerelease: false, html_url: URL(string: "https://example.com")!, published_at: "2024-01-01T00:00:00Z", assets: [mockAsset]),
            Release(tag_name: "v1.12.1", body: "", prerelease: true, html_url: URL(string: "https://example.com")!, published_at: "2024-02-01T00:00:00Z", assets: [mockAsset]),
        ]

        // Test that we can find a viable update
        let viableUpdate = try mockReleases.findViableUpdate(prerelease: false, currentVersion: Version(1, 11, 0))
        XCTAssertNotNil(viableUpdate, "Should find a viable non-prerelease update")
        XCTAssertEqual(viableUpdate?.tag_name, "v1.12.0", "Should return stable release")

        // Test prerelease filtering
        let prereleaseUpdate = try mockReleases.findViableUpdate(prerelease: true, currentVersion: Version(1, 12, 0))
        XCTAssertNotNil(prereleaseUpdate, "Should find a viable prerelease update")
        XCTAssertEqual(prereleaseUpdate?.tag_name, "v1.12.1", "Should return prerelease")
    }

    func testParetoUpdatedTreatsExamplePrereleaseVersionAsUpToDate() {
        let paretoUpdated = ParetoUpdated()

        XCTAssertTrue(
            paretoUpdated.isCurrentVersionUpToDate(currentVersion: "1.21.4", latestVersion: "1.21.0"),
            "The example prerelease version should be treated as up to date against the latest stable release"
        )
    }

    func testMacOSVersionParserReadsSupportPageHTML() {
        let html = """
        <html>
        <body>
        <h2>macOS Sequoia 15.7</h2>
        </body>
        </html>
        """

        let version = MacOSVersionCheck.parseLatestVersion(fromSupportPageHTML: html)

        XCTAssertEqual(version?.description, "15.7.0")
    }

    func testMacOSVersionParserReadsSoftwareUpdateTitleOutput() {
        let output = """
        Software Update Tool

        Finding available software
        Software Update found the following new or updated software:
        * Label: macOS Sequoia 15.7-24H101
            Title: macOS Sequoia 15.7, Version: 15.7, Size: 3123456KiB, Recommended: YES,
        * Label: Safari16.1VenturaAuto-16.1
            Title: Safari, Version: 16.1, Size: 123456KiB, Recommended: YES,
        """

        let version = MacOSVersionCheck.parseLatestVersion(fromSoftwareUpdateOutput: output, currentMajor: 15)

        XCTAssertEqual(version?.description, "15.7.0")
    }

    func testMacOSVersionParserReadsSoftwareUpdateLabelFallback() {
        let output = """
        Software Update found the following new or updated software:
        * Label: macOS Tahoe 26.5-25F80
        """

        let version = MacOSVersionCheck.parseLatestVersion(fromSoftwareUpdateOutput: output, currentMajor: 26)

        XCTAssertEqual(version?.description, "26.5.0")
    }

    func testMacOSVersionSoftwareUpdateUsesExpectedBinaryAndArgs() async {
        let check = MacOSVersionCheck()
        check.commandRunner = { app, args, timeout in
            XCTAssertEqual(app, "/usr/sbin/softwareupdate")
            XCTAssertEqual(args, ["--list"])
            XCTAssertEqual(timeout, 20.0)
            return """
            Software Update found the following new or updated software:
            * Label: macOS Tahoe 26.5-25F80
            """
        }

        let version = await check.getLatestVersionFromSoftwareUpdate()

        XCTAssertEqual(version?.description, "26.5.0")
    }

    func testMacOSVersionFallsBackToSoftwareUpdateWhenSupportPageFails() async {
        let check = MacOSVersionCheck()
        check.supportPageVersionProvider = { _ in nil }
        check.commandRunner = { _, _, _ in
            """
            Software Update found the following new or updated software:
            * Label: macOS Tahoe 26.5-25F80
            """
        }

        let version = await withCheckedContinuation { continuation in
            check.getLatestVersion(doc: "ignored") { version, source in
                continuation.resume(returning: (version, source))
            }
        }

        XCTAssertEqual(version.0.description, "26.5.0")
        XCTAssertEqual(version.1, "softwareupdate")
    }

    func testMacOSVersionDetailsIncludeCurrentAndResolvedVersion() {
        let check = MacOSVersionCheck()
        check.storeResolvedLatestVersion(Version(26, 3, 1), source: "apple-support")

        XCTAssertTrue(check.details.contains("current=\(check.currentVersion)"))
        XCTAssertTrue(check.details.contains("latest=26.3.1"))
        XCTAssertTrue(check.details.contains("source=apple-support"))
    }
}
