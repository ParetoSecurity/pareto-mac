//
//  ApplicationUpdatesTest.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 07/12/2021.
//

@testable import Pareto_Security
import XCTest

class ApplicationUpdatesTest: XCTestCase {
    func testLibreOfficeParserReadsCurrentDownloadPageVersions() {
        let html = """
        <select id="version">
            <option value="latest">LibreOffice 26.2.2</option>
            <option value="previous">LibreOffice 25.8.6</option>
        </select>
        """

        let versions = AppLibreOfficeCheck.parseLatestVersions(from: html)

        XCTAssertEqual(versions, ["26.2.2", "25.8.6"])
    }

    func testLibreOfficeParserReadsLegacyDownloadPageVersions() {
        let html = """
        <span class="dl_version_number">26.2.1</span>
        <span class="dl_version_number">25.8.5</span>
        """

        let versions = AppLibreOfficeCheck.parseLatestVersions(from: html)

        XCTAssertEqual(versions, ["26.2.1", "25.8.5"])
    }

    func testAppVersionFetchers() throws {
        var redirects = [String]()
        var names = [String]()
        for app in Claims.updateChecks.sorted(by: { $0.appMarketingName.lowercased() < $1.appMarketingName.lowercased() }) {
            XCTAssertNotEqual(app.usedRecently, nil)
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
