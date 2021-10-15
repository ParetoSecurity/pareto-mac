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

    static func current() -> ReportingDevice {
        return ReportingDevice(
            machineUUID: Defaults[.machineUUID],
            machineName: Defaults[.machineName]
        )
    }
}

struct Report: Encodable {
    let passedCount: Int
    let failedCount: Int
    let disabledCount: Int
    let device: ReportingDevice
    let version: String
    let lastCheck: String
    let significantChange: String

    static func now() -> Report {
        var passed = 0
        var failed = 0
        var disabled = 0
        var disabledSeed = "\(Defaults[.machineUUID])"
        var failedSeed = "\(Defaults[.machineUUID])"

        for claim in AppInfo.claims {
            for check in claim.checks {
                if check.isActive {
                    if check.checkPassed {
                        passed += 1
                    } else {
                        failed += 1
                        failedSeed.append(contentsOf: check.UUID)
                    }
                } else {
                    disabled += 1
                    disabledSeed.append(contentsOf: check.UUID)
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
            significantChange: SHA256.hash(data: "\(disabledSeed).\(failedSeed)".data(using: .utf8)!).hexStr
        )
    }
}

enum Team {
    public static let defaultAPI = "https://dash.paretosecurity.com/api/v1/team"
    private static let base = Defaults[.teamAPI]

    static func link(withDevice device: ReportingDevice) throws -> Request {
        return AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .put,
            parameters: device,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { cmd in
            debugPrint(cmd)
        }.validate().responseJSON { response in
            os_log("Team.Link response: %{public}s", log: Log.api, response.description)
        }
    }

    static func update(withReport report: Report) throws -> Request {
        AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .patch,
            parameters: report,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { cmd in
            debugPrint(cmd)
        }.validate().responseJSON { response in
            os_log("Team.Update response: %{public}s", log: Log.api, response.description)
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
}

func VerifyTeamTicket(withTicket data: String, publicKey key: String = rsaPublicKey) throws -> TeamTicketPayload {
    if try License.verify(jwt: data, withKey: key) {
        let jwt = try decode(jwt: data)
        return TeamTicketPayload(
            subject: jwt.subject!,
            issuedAt: jwt.issuedAt!,
            teamUUID: jwt.teamUUID!,
            teamAuth: jwt.teamAuth!,
            role: jwt.role!
        )
    }
    throw License.Error.invalidLicense
}
