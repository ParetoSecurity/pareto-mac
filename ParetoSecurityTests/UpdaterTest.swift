//
//  UpdaterTest.swift
//  UpdaterTest
//
//  Created by Janez Troha on 31/08/2021.
//

@testable import Pareto_Security
import Version
import XCTest

class UpdaterTest: XCTestCase {
    func testFindViableUpdateStableChannel() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.13.1", body: "", prerelease: true, html_url: URL(string: "foo://")!, published_at: "2025-01-01T00:00:00Z", assets: asset),
            Release(tag_name: "1.13.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2024-12-01T00:00:00Z", assets: asset),
            Release(tag_name: "1.12.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2024-11-01T00:00:00Z", assets: asset),
        ]

        XCTAssertEqual(try releases.findViableUpdate(prerelease: false, currentVersion: Version(1, 11, 0))?.tag_name, "1.13.0")
    }

    func testFindViableUpdatePrereleaseChannelPrefersHighestAcrossChannels() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.12.3", body: "", prerelease: true, html_url: URL(string: "foo://")!, published_at: "2025-01-01T00:00:00Z", assets: asset),
            Release(tag_name: "1.13.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2025-01-02T00:00:00Z", assets: asset),
        ]

        XCTAssertEqual(try releases.findViableUpdate(prerelease: true, currentVersion: Version(1, 12, 2))?.tag_name, "1.13.0")
    }

    func testFindViableUpdatePrereleaseChannelSelectsPrereleaseWhenHigherThanStable() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.12.3", body: "", prerelease: true, html_url: URL(string: "foo://")!, published_at: "2025-01-03T00:00:00Z", assets: asset),
            Release(tag_name: "1.12.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2025-01-02T00:00:00Z", assets: asset),
        ]

        XCTAssertEqual(try releases.findViableUpdate(prerelease: true, currentVersion: Version(1, 12, 1))?.tag_name, "1.12.3")
    }

    func testFindViableUpdateReturnsNilWhenNothingIsNewer() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.12.1", body: "", prerelease: true, html_url: URL(string: "foo://")!, published_at: "2025-01-01T00:00:00Z", assets: asset),
            Release(tag_name: "1.12.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2025-01-02T00:00:00Z", assets: asset),
        ]

        XCTAssertNil(try releases.findViableUpdate(prerelease: true, currentVersion: Version(1, 12, 1)))
    }
}
