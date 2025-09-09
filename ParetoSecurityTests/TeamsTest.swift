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
    func testReport() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let report = Report.now()

        _ = Team.update(withReport: report)
    }

    func testReportError() throws {
        for claim in Claims.global.all {
            for check in claim.checks {
                check.hasError = true
                break
            }
        }

        let report = Report.now()
        XCTAssertEqual(report.state["2e46c89a-5461-4865-a92e-3b799c12034a"], "error")
        XCTAssertEqual(report.state["b96524e0-850b-4bb9-abc7-517051b6c14e"], "pass")
    }

    func testSettings() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        Team.settings { settings in
            XCTAssertEqual(settings?.enforcedList, [])
        }
    }

    func testDeviceEnrollmentRequest() throws {
        let testDevice = ReportingDevice(
            machineUUID: "test-uuid",
            machineName: "Test Machine",
            macOSVersion: "14.0",
            modelName: "Test Model",
            modelSerial: "Test Serial"
        )
        let request = DeviceEnrollmentRequest(inviteID: "test-invite-id", device: testDevice)
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["invite_id"] as! String, "test-invite-id")
        XCTAssertNotNil(json["device"])
    }

    func testDeviceEnrollmentResponse() throws {
        let json = """
        {
            "auth": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZWFtX2lkIjoiMjQyOWM0OWUtMzdiYi00MWJiLTkwNzctNmJiNjIwMmUyNTViIn0.test"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(DeviceEnrollmentResponse.self, from: data)

        XCTAssertEqual(response.auth, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZWFtX2lkIjoiMjQyOWM0OWUtMzdiYi00MWJiLTkwNzctNmJiNjIwMmUyNTViIn0.test")
    }
    
    func testShouldShowDeviceRemovedAlertFirstTime() throws {
        // Reset the last alert timestamp
        Defaults[.lastDeviceRemovedAlert] = 0
        
        // Should show alert when never shown before
        XCTAssertTrue(Defaults.shouldShowDeviceRemovedAlert())
    }
    
    func testShouldShowDeviceRemovedAlertAfterWeek() throws {
        // Set last alert to more than a week ago
        let moreThanWeekAgo = Date().currentTimeMs() - (Date.HourInMs * 24 * 8)
        Defaults[.lastDeviceRemovedAlert] = moreThanWeekAgo
        
        // Should show alert after a week has passed
        XCTAssertTrue(Defaults.shouldShowDeviceRemovedAlert())
    }
    
    func testShouldNotShowDeviceRemovedAlertWithinWeek() throws {
        // Set last alert to less than a week ago (e.g., 3 days ago)
        let threeDaysAgo = Date().currentTimeMs() - (Date.HourInMs * 24 * 3)
        Defaults[.lastDeviceRemovedAlert] = threeDaysAgo
        
        // Should not show alert within a week
        XCTAssertFalse(Defaults.shouldShowDeviceRemovedAlert())
    }
    
    func testShouldNotShowDeviceRemovedAlertJustShown() throws {
        // Set last alert to now
        Defaults[.lastDeviceRemovedAlert] = Date().currentTimeMs()
        
        // Should not show alert immediately after showing
        XCTAssertFalse(Defaults.shouldShowDeviceRemovedAlert())
    }
}
