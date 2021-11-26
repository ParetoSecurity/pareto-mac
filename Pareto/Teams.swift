//
//  Team.swift
//  Team
//
//  Created by Janez Troha on 16/09/2021.
//

import Alamofire
import CryptoKit
import Defaults
import Foundation
import JWTDecode
import os.log

private extension JWT {
    var teamAuth: String? {
        return claim(name: "token").string
    }

    var role: String? {
        return claim(name: "role").string
    }

    var teamUUID: String? {
        return claim(name: "teamID").string
    }

    var isTeamOwner: Bool? {
        return claim(name: "isTeamOwner").boolean
    }
}

private extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

struct ReportingDevice: Encodable {
    let machineUUID: String
    let machineName: String
    let auth: String
    let macOSVersion: String

    static func current() -> ReportingDevice {
        return ReportingDevice(
            machineUUID: Defaults[.machineUUID],
            machineName: AppInfo.machineName,
            auth: Defaults[.teamAuth],
            macOSVersion: AppInfo.macOSVersionString
        )
    }
}

struct Report: Encodable {
    public enum CheckStatus: String {
        case Disabled = "off", Passing = "pass", Failing = "fail"
    }

    let passedCount: Int
    let failedCount: Int
    let disabledCount: Int
    let device: ReportingDevice
    let version: String
    let lastCheck: String
    let significantChange: String
    let state: [String: String]

    static func now() -> Report {
        var passed = 0
        var failed = 0
        var disabled = 0
        var disabledSeed = "\(Defaults[.machineUUID])"
        var failedSeed = "\(Defaults[.machineUUID])"
        var checkStates: [String: String] = [:]

        for claim in AppInfo.claims {
            for check in claim.checks {
                if check.isRunnable {
                    if check.checkPassed {
                        passed += 1
                        checkStates[check.UUID] = CheckStatus.Passing.rawValue
                    } else {
                        failed += 1
                        failedSeed.append(contentsOf: check.UUID)
                        checkStates[check.UUID] = CheckStatus.Failing.rawValue
                    }
                } else {
                    disabled += 1
                    disabledSeed.append(contentsOf: check.UUID)
                    checkStates[check.UUID] = CheckStatus.Disabled.rawValue
                }
            }
        }

        return Report(
            passedCount: passed,
            failedCount: failed,
            disabledCount: disabled,
            device: ReportingDevice.current(),
            version: AppInfo.appVersion,
            lastCheck: Date.fromTimeStamp(timeStamp: Defaults[.lastCheck]).as3339String(),
            significantChange: SHA256.hash(data: "\(disabledSeed).\(failedSeed)".data(using: .utf8)!).hexStr,
            state: checkStates
        )
    }
}

enum Team {
    public static let defaultAPI = "https://dash.paretosecurity.com/api/v1/team"
    private static let base = Defaults[.teamAPI]
    private static let queue = DispatchQueue(label: "co.pareto.api", qos: .utility, attributes: .concurrent)

    static func link(withDevice device: ReportingDevice) -> DataRequest {
        AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .put,
            parameters: device,
            encoder: JSONParameterEncoder.default
        ).validate().cURLDescription { cmd in
            debugPrint(cmd)
        }.response(queue: queue) { data in
            debugPrint(data)
        }
    }

    static func update(withReport report: Report) -> DataRequest {
        AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .patch,
            parameters: report,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { cmd in
            debugPrint(cmd)
        }.validate().response(queue: queue) { data in
            debugPrint(data)
        }
    }
}

struct TeamTicketPayload: Decodable, Equatable {
    // The "sub" (subject) claim identifies the principal that is the
    // subject of the JWT.
    var subject: String

    // The "exp" (expiration time) claim identifies the expiration time on
    // or after which the JWT MUST NOT be accepted for processing.
    var issuedAt: Date

    // Custom data.
    var teamUUID: String
    var teamAuth: String
    var role: String
    var isTeamOwner: Bool

    func isValid() -> Bool {
        return teamAuth != "" && teamUUID != "" && subject != "" && role == "team"
    }
}

func VerifyTeamTicket(withTicket data: String, publicKey key: String = rsaPublicKey) throws -> TeamTicketPayload {
    if try License.verify(jwt: data, withKey: key) {
        let jwt = try decode(jwt: data)

        let ticket = TeamTicketPayload(
            subject: jwt.subject ?? "",
            issuedAt: jwt.issuedAt ?? Date(),
            teamUUID: jwt.teamUUID ?? "",
            teamAuth: jwt.teamAuth ?? "",
            role: jwt.role ?? "",
            isTeamOwner: jwt.isTeamOwner ?? false
        )

        if !ticket.isValid() {
            throw License.Error.invalidLicense
        }
        return ticket
    }
    throw License.Error.invalidLicense
}
