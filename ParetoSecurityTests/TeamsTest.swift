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
    override func setUp() {
        super.setUp()
        Defaults[.teamID] = ""
        Defaults[.teamAuth] = ""
        Defaults[.teamAPI] = "https://cloud.paretosecurity.com/"
        Defaults[.lastDeviceRemovedAlert] = 0

        for claim in Claims.global.all {
            for check in claim.checks {
                check.hasError = false
            }
        }
    }

    func testReport() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"

        let report = Report.now()

        _ = Team.update(withReport: report)
    }

    func testReportError() throws {
        guard let targetCheck = Claims.global.all
            .flatMap(\.checks)
            .first(where: { $0.isRunnable })
        else {
            XCTFail("Expected at least one runnable check")
            return
        }

        targetCheck.hasError = true

        let report = Report.now()
        XCTAssertEqual(report.state[targetCheck.UUID], "error")
        XCTAssertTrue(report.state.values.contains("pass") || report.state.values.contains("fail"))
    }

    func testSettings() throws {
        Defaults[.teamID] = "fd4e6814-440c-46d2-b240-4e0d2f786fbc"
        Defaults[.teamAPI] = "http://localhost"
        let exp = expectation(description: "settings callback")

        Team.settings { settings in
            XCTAssertNil(settings)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
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

    func testUpdateStoredDeviceAuth() throws {
        let auth = testJWT(teamID: "2429c49e-37bb-41bb-9077-6bb6202e255b")
        let data = """
        {
            "auth": "\(auth)"
        }
        """.data(using: .utf8)

        XCTAssertTrue(Team.updateStoredDeviceAuth(from: data))
        XCTAssertEqual(Defaults[.teamAuth], auth)
        XCTAssertEqual(Defaults[.teamID], "2429c49e-37bb-41bb-9077-6bb6202e255b")
    }

    func testUpdateStoredDeviceAuthRejectsBadData() throws {
        Defaults[.teamAuth] = "old-token"
        Defaults[.teamID] = "old-team"

        XCTAssertFalse(Team.updateStoredDeviceAuth(from: "{}".data(using: .utf8)))
        XCTAssertEqual(Defaults[.teamAuth], "old-token")
        XCTAssertEqual(Defaults[.teamID], "old-team")
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

    func testDeviceLinkInvalidStatusCodes() throws {
        XCTAssertTrue(Team.isDeviceLinkInvalidStatusCode(401))
        XCTAssertTrue(Team.isDeviceLinkInvalidStatusCode(404))
        XCTAssertFalse(Team.isDeviceLinkInvalidStatusCode(400))
        XCTAssertFalse(Team.isDeviceLinkInvalidStatusCode(500))
        XCTAssertFalse(Team.isDeviceLinkInvalidStatusCode(nil))
    }

    private func testJWT(teamID: String) -> String {
        let header = base64UrlEncoded(#"{"alg":"HS512","typ":"JWT"}"#)
        let payload = base64UrlEncoded(#"{"team_id":"\#(teamID)"}"#)
        return "\(header).\(payload).signature"
    }

    private func base64UrlEncoded(_ value: String) -> String {
        return value
            .data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
