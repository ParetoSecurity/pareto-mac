//
//  ParetoSecurityTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 11/08/2021.
//

@testable import Pareto_Security
import XCTest

class ParetoSecurityTests: XCTestCase {
    func testThatUUIDsAreUnique() throws {
        var uuids: [String] = []
        for claim in AppInfo.claims {
            for check in claim.checks {
                if uuids.contains(check.UUID) {
                    XCTFail("Duplicate UUID found \(check.UUID)")
                }
                uuids.append(check.UUID)
            }
        }
    }

    func testAppInfo() throws {
        XCTAssertTrue(AppInfo.getVersions().contains("HW"))
        XCTAssertTrue(AppInfo.logEntries().contains("State:"))
        XCTAssertTrue(AppInfo.bugReportURL().absoluteString.contains("github.com"))
    }
}
