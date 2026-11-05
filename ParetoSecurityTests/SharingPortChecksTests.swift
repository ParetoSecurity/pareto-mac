//
//  SharingPortChecksTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import SwiftSocket
import XCTest

class SharingPortChecksTests: XCTestCase {
    func testScreenSharingFailsWhenPort5900IsListening() throws {
        let server = TCPServer(address: "127.0.0.1", port: 5900)
        guard case .success = server.listen() else {
            throw XCTSkip("Could not listen on 127.0.0.1:5900")
        }
        defer { server.close() }

        XCTAssertFalse(ScreenSharingCheck().checkPasses())
    }

    func testRemoteApplicationScriptingFailsWhenPort3031IsListening() throws {
        let server = TCPServer(address: "127.0.0.1", port: 3031)
        guard case .success = server.listen() else {
            throw XCTSkip("Could not listen on 127.0.0.1:3031")
        }
        defer { server.close() }

        XCTAssertFalse(RemoteApplicationScriptingCheck().checkPasses())
    }

    func testChecksAreRegisteredInFirewallAndSharingClaim() {
        guard let claim = Claims.global.all.first(where: { $0.title == "Firewall & Sharing" }) else {
            XCTFail("Expected a Firewall & Sharing claim")
            return
        }

        XCTAssertTrue(claim.checks.contains { $0 === ScreenSharingCheck.sharedInstance })
        XCTAssertTrue(claim.checks.contains { $0 === RemoteApplicationScriptingCheck.sharedInstance })
    }

    func testIsNotListeningDetectsLoopbackListener() {
        let server = TCPServer(address: "127.0.0.1", port: 0)
        guard case .success = server.listen() else {
            XCTFail("Expected a loopback listener")
            return
        }
        let port = Int(server.port)
        let check = ScreenSharingCheck()

        XCTAssertFalse(check.isNotListening(withPort: port))

        server.close()
        XCTAssertTrue(check.isNotListening(withPort: port))
    }
}
