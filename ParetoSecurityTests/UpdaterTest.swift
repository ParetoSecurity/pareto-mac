//
//  UpdaterTest.swift
//  UpdaterTest
//
//  Created by Janez Troha on 31/08/2021.
//

@testable import Pareto_Security
import XCTest

class UpdaterTest: XCTestCase {
    func testFetching() throws {
        let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
        if let release = try? updater.getLatestRelease() {
            XCTAssertTrue(release.tag_name.count > 0)
        }
    }
}
