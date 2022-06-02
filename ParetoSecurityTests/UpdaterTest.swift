//
//  UpdaterTest.swift
//  UpdaterTest
//
//  Created by Janez Troha on 31/08/2021.
//

@testable import Pareto_Security
import XCTest

class UpdaterTest: XCTestCase {
    override class func setUp() {
        super.setUp()
    }
    
    override class func tearDown() {
        super.tearDown()
    }

    func testFetching() throws {
        let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
        if let release = try? updater.getLatestRelease() {
            
        }
    }

    func testParsing() throws {
        let asset = [Release.Asset(name: "", browser_download_url: URL(string: "foo://")!, size: 1, content_type: Release.Asset.ContentType.zip)]
        let releases = [
            Release(tag_name: "1.1.1", body: "", prerelease: true, html_url: URL(string: "foo://")!, assets: asset),
            Release(tag_name: "1.0.0", body: "", prerelease: false, html_url: URL(string: "foo://")!, assets: asset)
        ]
        XCTAssertEqual(try! releases.findViableUpdate(prerelease: false)?.tag_name, "1.0.0")
        XCTAssertEqual(try! releases.findViableUpdate(prerelease: true)?.tag_name, "1.1.1")
    }
}
