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
        let apps = [
            App1Password7Check.sharedInstance,
            AppBitwardenCheck.sharedInstance,
            AppCyberduckCheck.sharedInstance,
            AppDashlaneCheck.sharedInstance,
            AppDockerCheck.sharedInstance,
            AppEnpassCheck.sharedInstance,
            AppFirefoxCheck.sharedInstance,
            AppGoogleChromeCheck.sharedInstance,
            AppiTermCheck.sharedInstance,
            AppNordLayerCheck.sharedInstance,
            AppSlackCheck.sharedInstance,
            AppTailscaleCheck.sharedInstance,
            AppZoomCheck.sharedInstance,
            AppSignalCheck.sharedInstance,
            AppLibreOfficeCheck.sharedInstance,
            AppWireGuardCheck.sharedInstance
        ]
        for app in apps {
            XCTAssertNotEqual(app.latestVersion, nil)
            XCTAssertNotEqual(app.UUID, nil)
            XCTAssertNotEqual(app.currentVersion, nil)
            XCTAssertFalse(app.reportIfDisabled)
        }
    }
}
