//
//  UpdaterTest.swift
//  UpdaterTest
//
//  Created by Janez Troha on 31/08/2021.
//

@testable import Pareto_Security
import XCTest

class UpdaterTest: XCTestCase {
    func testParsing() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.1.1", body: "", prerelease: true, html_url: URL(string: "foo://")!, published_at: "2025-01-01T00:00:00Z", assets: asset),
            Release(tag_name: "1.0.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, published_at: "2024-12-01T00:00:00Z", assets: asset),
        ]
        XCTAssertEqual(try! releases.findViableUpdate(prerelease: false)?.tag_name, "1.0.0")
        XCTAssertEqual(try! releases.findViableUpdate(prerelease: true)?.tag_name, "1.1.1")
    }
}
