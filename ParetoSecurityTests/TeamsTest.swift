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
        Defaults[.deviceID] = "302f10ab-90e9-485d-a1fb-3ae5735a2193"
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let device = ReportingDevice(id: "302f10ab-90e9-485d-a1fb-3ae5735a2193", machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c")
        _ = try? Team.link(withDevice: device)
    }

    func testUnlink() throws {
        Defaults[.deviceID] = "302f10ab-90e9-485d-a1fb-3ae5735a2193"
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let device = ReportingDevice(id: "302f10ab-90e9-485d-a1fb-3ae5735a2193", machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c")

        _ = try? Team.unlink(withDevice: device)
    }

    func testReport() throws {
        Defaults[.deviceID] = "302f10ab-90e9-485d-a1fb-3ae5735a2193"
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let device = ReportingDevice(id: "302f10ab-90e9-485d-a1fb-3ae5735a2193", machineUUID: "5d486371-7841-4e4d-95c4-78c71cdaa44c")
        let report = Report(passedCount: 1, failedCount: 2, disabledCount: 3, device: device, version: AppInfo.appVersion, lastChecked: Date().as3339String())

        _ = try? Team.update(withReport: report)
    }
}
