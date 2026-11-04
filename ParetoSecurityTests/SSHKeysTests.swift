//
//  SSHKeysTests.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import XCTest

class SSHKeysTests: XCTestCase {
    let ed25519SK = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIN1Ey4B7zdikMDSAAPkrqYVIEa2m+M2oVMauz+JfgiQMAAAABHNzaDo= sk-test"
    let ecdsaSK = "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBD7Vr1sY/X/gIOvhFOBohEzoRFr7c/L+1zkPznG4exRdTpMPyxgO+Jj9pgH1R1wLFKBd7ChXhMH80NF5z5AUrmQAAAAEc3NoOg== sk-test"
    let ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN1Ey4B7zdikMDSAAPkrqYVIEa2m+M2oVMauz+JfgiQM test"
    let rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDXNiWHZc3UdtkFjDqJckQduoqvXQZIwwgwCgdS+dopDq3hZpRoxdRbqTlNuDq6LT5V2IdZkF51ZxwN6AH29uwKKrp0UwNMTCEcMqk2cdyf8xMgfLWVQnSxU1OKG8xetUsMjisA1G4Ah2XTkS7Ci5vWkA5nHitvtq4we3y0Q97Low== test"
    let ecdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBD7Vr1sY/X/gIOvhFOBohEzoRFr7c/L+1zkPznG4exRdTpMPyxgO+Jj9pgH1R1wLFKBd7ChXhMH80NF5z5AUrmQ= test"

    func testIsProtected() {
        XCTAssertTrue(SSHKeysCheck.isProtected(keygenOutput: ed25519SK + "\n"))
        XCTAssertTrue(SSHKeysCheck.isProtected(keygenOutput: ecdsaSK + "\n"))
        XCTAssertTrue(SSHKeysCheck.isProtected(keygenOutput: "Load key \"/tmp/id_ed25519\": incorrect passphrase supplied to decrypt private key\n"))
    }

    func testIsNotProtected() {
        for output in [ed25519, rsa, ecdsa, "", "garbage"] {
            XCTAssertFalse(SSHKeysCheck.isProtected(keygenOutput: output + "\n"), output)
        }
    }

    func testECDSASecurityKeyIsStrong() {
        let info = KeyInfo(stringLiteral: "256 SHA256:taL8G9YFkBGfA+ayt1vwRe7e27gDf4nxCAuaXGPqBoA sk-test (ECDSA-SK)")
        XCTAssertEqual(info.cipher, .ECDSA_SK)
        XCTAssertTrue(SSHKeysStrengthCheck.isKeyStrong(info))
    }

    func testECDSAKeyRequires521Bits() {
        let weak = KeyInfo(stringLiteral: "256 SHA256:taL8G9YFkBGfA+ayt1vwRe7e27gDf4nxCAuaXGPqBoA test (ECDSA)")
        let strong = KeyInfo(stringLiteral: "521 SHA256:taL8G9YFkBGfA+ayt1vwRe7e27gDf4nxCAuaXGPqBoA test (ECDSA)")
        XCTAssertFalse(SSHKeysStrengthCheck.isKeyStrong(weak))
        XCTAssertTrue(SSHKeysStrengthCheck.isKeyStrong(strong))
    }
}
