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
    override class func setUp() {
        super.setUp()
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

    func testLink() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let device = ReportingDevice(machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c", deviceName: "Foo Device")
        _ = try? Team.link(withDevice: device)
    }

    func testReport() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let report = Report.now()

        _ = try? Team.update(withReport: report)
    }
}
