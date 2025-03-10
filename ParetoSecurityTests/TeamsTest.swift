//
//  TeamsTest.swift
//  TeamsTest
//
//  Created by Janez Troha on 20/09/2021.
//

import Defaults
@testable import Pareto_Security
import XCTest

class TeamsTest: XCTestCase {

    func testLink() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let device = ReportingDevice(
            machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c",
            machineName: "Foo Device",
            auth: "foo",
            macOSVersion: "12.0.1",
            modelName: "foo",
            modelSerial: "foo"
        )
        _ = Team.link(withDevice: device)
    }

    func testReport() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let report = Report.now()

        _ = Team.update(withReport: report)
    }

    func testSettings() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        Team.settings { settings in
            XCTAssertEqual(settings?.enforcedList, [])
        }
    }
}
