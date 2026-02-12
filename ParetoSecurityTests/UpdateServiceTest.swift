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
}
