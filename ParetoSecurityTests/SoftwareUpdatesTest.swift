//
//  SoftwareUpdatesTest.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 07/12/2021.
//

@testable import Pareto_Security
import XCTest

class SoftwareUpdatesTest: XCTestCase {
    override class func setUp() {
        super.setUp()
    }

    func testAppVersionFetcehrs() throws {
        var redirects = [String]()
        var names = [String]()
        for app in Claims.updateChecks.sorted(by: { $0.appMarketingName.lowercased() < $1.appMarketingName.lowercased() }) {
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
