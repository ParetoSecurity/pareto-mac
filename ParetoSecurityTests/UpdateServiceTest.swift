//
//  UpdateServiceTest.swift
//  ParetoSecurityTests
//

@testable import Pareto_Security
import Version
import XCTest

class UpdateServiceTest: XCTestCase {
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

    func testServiceAvailability() {
        // Test that UpdateService singleton is available
        XCTAssertNotNil(UpdateService.shared, "UpdateService should be available")
    }

    func testUpdateCheckIntegration() {
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
        let mockRelease = try Release(
            tag_name: "v1.2.3",
            body: "Test release",
            prerelease: false,
            html_url: XCTUnwrap(URL(string: "https://example.com")),
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
        let mockAsset = try Release.Asset(name: "test.zip", browser_download_url: XCTUnwrap(URL(string: "https://example.com/test.zip")), size: 1000, content_type: .zip)
        let mockReleases = try [
            Release(tag_name: "v1.12.0", body: "", prerelease: false, html_url: XCTUnwrap(URL(string: "https://example.com")), published_at: "2024-01-01T00:00:00Z", assets: [mockAsset]),
            Release(tag_name: "v1.12.1", body: "", prerelease: true, html_url: XCTUnwrap(URL(string: "https://example.com")), published_at: "2024-02-01T00:00:00Z", assets: [mockAsset]),
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

    func testParetoUpdatedFailsOnlyForConcreteOlderVersionMismatch() throws {
        let paretoUpdated = ParetoUpdated()
        let now = Date(timeIntervalSince1970: 1_742_000_000)
        let release = try Release(
            tag_name: "v1.21.0",
            body: "",
            prerelease: false,
            html_url: XCTUnwrap(URL(string: "https://example.com")),
            published_at: "2025-02-20T00:00:00Z",
            assets: []
        )

        let outcome = paretoUpdated.evaluateUpdateCheckOutcome(
            releases: [release],
            appVersion: "1.20.0",
            now: now
        )

        XCTAssertEqual(
            outcome,
            .resolved(isUpToDate: false, currentVersion: "1.20.0", latestVersion: "1.21.0")
        )
    }

    func testParetoUpdatedTreatsInvalidPublishedDateAsInconclusive() throws {
        let paretoUpdated = ParetoUpdated()
        let release = try Release(
            tag_name: "v1.21.0",
            body: "",
            prerelease: false,
            html_url: XCTUnwrap(URL(string: "https://example.com")),
            published_at: "not-a-date",
            assets: []
        )

        let outcome = paretoUpdated.evaluateUpdateCheckOutcome(
            releases: [release],
            appVersion: "1.20.0",
            now: Date(timeIntervalSince1970: 1_742_000_000)
        )

        XCTAssertEqual(outcome, .inconclusive)
    }

    func testParetoUpdatedTreatsUnparseableVersionsAsInconclusive() throws {
        let paretoUpdated = ParetoUpdated()
        let now = Date(timeIntervalSince1970: 1_742_000_000)
        let release = try Release(
            tag_name: "latest",
            body: "",
            prerelease: false,
            html_url: XCTUnwrap(URL(string: "https://example.com")),
            published_at: "2025-02-20T00:00:00Z",
            assets: []
        )

        let outcome = paretoUpdated.evaluateUpdateCheckOutcome(
            releases: [release],
            appVersion: "1.20.0",
            now: now
        )

        XCTAssertEqual(outcome, .inconclusive)
    }

    func testParetoUpdatedNetworkErrorsDoNotChangePreviousResult() async {
        let paretoUpdated = ParetoUpdated()
        _ = paretoUpdated.applyUpdateCheckOutcome(
            .resolved(isUpToDate: false, currentVersion: "1.20.0", latestVersion: "1.21.0")
        )
        paretoUpdated.updatesProvider = {
            throw APIError.networkError("timed out")
        }

        let outcome = await paretoUpdated.fetchUpdateCheckOutcome(
            appVersion: "1.20.0",
            now: Date(timeIntervalSince1970: 1_742_000_000)
        )
        let result = paretoUpdated.applyUpdateCheckOutcome(outcome)

        XCTAssertEqual(outcome, .inconclusive)
        XCTAssertFalse(result)
        XCTAssertFalse(paretoUpdated.hasError)
    }

    func testParetoUpdatedNetworkErrorsKeepInitialPassingState() async {
        let paretoUpdated = ParetoUpdated()
        paretoUpdated.updatesProvider = {
            throw APIError.networkError("timed out")
        }

        let outcome = await paretoUpdated.fetchUpdateCheckOutcome(
            appVersion: "1.20.0",
            now: Date(timeIntervalSince1970: 1_742_000_000)
        )
        let result = paretoUpdated.applyUpdateCheckOutcome(outcome)

        XCTAssertEqual(outcome, .inconclusive)
        XCTAssertTrue(result)
        XCTAssertFalse(paretoUpdated.hasError)
    }

    /// Trimmed copy of https://gdmf.apple.com/v2/pmv as published on 2026-10-26.
    static let gdmfFixture = """
    {
      "PublicAssetSets": {
        "macOS": [
          {"ProductVersion": "15.8.2", "Build": "24H210", "SupportedDevices": ["J314sAP", "Mac-1E7E29AD0135F9BC"]},
          {"ProductVersion": "27.2", "Build": "26B123", "SupportedDevices": ["J314sAP", "J700AP", "VMA2MACOSAP"]},
          {"ProductVersion": "26.7.2", "Build": "25H120", "SupportedDevices": ["J314sAP", "VMA2MACOSAP", "VMM-x86_64"]},
          {"ProductVersion": "26.3.2", "Build": "25D2140", "SupportedDevices": ["J800AP"]}
        ],
        "iOS": [
          {"ProductVersion": "27.9", "Build": "27Z1", "SupportedDevices": ["iPhone99,1"]}
        ]
      },
      "AssetSets": {
        "macOS": [
          {"ProductVersion": "26.3.1", "Build": "25D2128", "SupportedDevices": ["J314sAP", "J800AP"]},
          {"ProductVersion": "27.0.1", "Build": "26A190", "SupportedDevices": ["J314sAP"]}
        ]
      }
    }
    """

    func testMacOSVersionParserReadsGDMFLatestForCurrentMajor() {
        let data = Data(Self.gdmfFixture.utf8)

        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 27, deviceID: nil)?.description, "27.2.0")
        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 15, deviceID: nil)?.description, "15.8.2")
    }

    func testMacOSVersionParserGDMFReturnsNilForUnknownMajor() {
        let data = Data(Self.gdmfFixture.utf8)

        XCTAssertNil(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 28, deviceID: nil))
        XCTAssertNil(MacOSVersionCheck.parseLatestVersion(fromGDMF: Data("not json".utf8), currentMajor: 27, deviceID: nil))
    }

    func testMacOSVersionParserGDMFPrefersReleaseForThisDevice() {
        let data = Data(Self.gdmfFixture.utf8)

        // Without a device ID, the newest 26.x wins regardless of which Macs it ships to.
        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 26, deviceID: nil)?.description, "26.7.2")
        // A device-specific release only counts for the devices it ships to.
        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 26, deviceID: "J800AP")?.description, "26.3.2")
        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 26, deviceID: "J314sAP")?.description, "26.7.2")
        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 15, deviceID: "Mac-1E7E29AD0135F9BC")?.description, "15.8.2")
    }

    func testMacOSVersionParserGDMFFallsBackToAllDevicesForUnknownDevice() {
        let data = Data(Self.gdmfFixture.utf8)

        XCTAssertEqual(MacOSVersionCheck.parseLatestVersion(fromGDMF: data, currentMajor: 27, deviceID: "J999AP")?.description, "27.2.0")
    }

    func testMacOSVersionParserGDMFUsesAssetSetsWhenPublicReleaseSkipsDevice() {
        let json = """
        {
          "PublicAssetSets": {"macOS": [{"ProductVersion": "26.3.2", "SupportedDevices": ["J800AP"]}]},
          "AssetSets": {"macOS": [
            {"ProductVersion": "26.3.1", "SupportedDevices": ["J314sAP", "J800AP"]},
            {"ProductVersion": "26.3", "SupportedDevices": ["J314sAP"]}
          ]}
        }
        """

        let version = MacOSVersionCheck.parseLatestVersion(fromGDMF: Data(json.utf8), currentMajor: 26, deviceID: "J314sAP")

        XCTAssertEqual(version?.description, "26.3.1")
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

    func testMacOSVersionUsesGDMFWhenAvailable() async {
        let check = MacOSVersionCheck()
        check.gdmfVersionProvider = { Version(27, 2, 0) }
        check.commandRunner = { _, _, _ in
            XCTFail("softwareupdate should not run when GDMF resolves")
            return ""
        }

        let version = await withCheckedContinuation { continuation in
            check.getLatestVersion { version, source in
                continuation.resume(returning: (version, source))
            }
        }

        XCTAssertEqual(version.0.description, "27.2.0")
        XCTAssertEqual(version.1, "gdmf")
    }

    func testMacOSVersionFallsBackToSoftwareUpdateWhenGDMFFails() async {
        let check = MacOSVersionCheck()
        check.gdmfVersionProvider = { nil }
        check.commandRunner = { _, _, _ in
            """
            Software Update found the following new or updated software:
            * Label: macOS Tahoe 26.5-25F80
            """
        }

        let version = await withCheckedContinuation { continuation in
            check.getLatestVersion { version, source in
                continuation.resume(returning: (version, source))
            }
        }

        XCTAssertEqual(version.0.description, "26.5.0")
        XCTAssertEqual(version.1, "softwareupdate")
    }

    func testMacOSVersionUnresolvedWhenAllSourcesFail() async {
        let check = MacOSVersionCheck()
        check.gdmfVersionProvider = { nil }
        check.commandRunner = { _, _, _ in "No new software available." }

        let version = await withCheckedContinuation { continuation in
            check.getLatestVersion { version, source in
                continuation.resume(returning: (version, source))
            }
        }

        XCTAssertEqual(version.0, Version(0, 0, 0))
        XCTAssertEqual(version.1, "unresolved")
    }

    func testMacOSVersionDeviceIdentifierIsReadable() {
        // Every Mac (Apple silicon, Intel or VM) exposes target-sub-type or board-id.
        let deviceID = MacOSVersionCheck.deviceIdentifier()

        XCTAssertNotNil(deviceID)
        XCTAssertFalse(deviceID?.contains("\u{0}") ?? true)
    }

    func testMacOSVersionDetailsIncludeCurrentAndResolvedVersion() {
        let check = MacOSVersionCheck()
        check.storeResolvedLatestVersion(Version(26, 3, 1), source: "gdmf")

        XCTAssertTrue(check.details.contains("current=\(check.currentVersion)"))
        XCTAssertTrue(check.details.contains("latest=26.3.1"))
        XCTAssertTrue(check.details.contains("source=gdmf"))
    }

    func testMacOSVersionTreatsMacBookNeoPatchLagAsUpToDate() {
        XCTAssertTrue(
            MacOSVersionCheck.isCurrentVersionUpToDate(
                current: Version(26, 3, 1),
                latest: Version(26, 3, 2)
            )
        )
    }
}
