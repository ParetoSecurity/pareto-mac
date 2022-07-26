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

struct DeviceSettings: Codable {
    let ignoredChecks: [APICheck]
    let requiredChecks: [APICheck]
    let name: String
    let admin: String

    var ignoredList: [String] {
        ignoredChecks.map { $0.id }
    }

    var enforcedList: [String] {
        requiredChecks.map { $0.id }
    }
}

struct APICheck: Codable {
    let id: String
}

struct TokenSettings: Codable {
    let token: String
}

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
    let modelName: String
    let modelSerial: String

    static func current() -> ReportingDevice {
        return ReportingDevice(
            machineUUID: Defaults[.machineUUID],
            machineName: AppInfo.machineName,
            auth: Defaults[.teamAuth],
            macOSVersion: AppInfo.macOSVersionString,
            modelName: Defaults[.sendHWInfo] ? AppInfo.hwModelName : "Disabled",
            modelSerial: Defaults[.sendHWInfo] ? AppInfo.hwSerial : "Disabled"
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

        for claim in Claims.sorted {
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
                    if check.reportIfDisabled {
                        disabled += 1
                        disabledSeed.append(contentsOf: check.UUID)
                        checkStates[check.UUID] = CheckStatus.Disabled.rawValue
                    }
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
    private static let queue = DispatchQueue(label: "co.pareto.api", qos: .userInteractive, attributes: .concurrent)

    static func link(withDevice device: ReportingDevice) -> DataRequest {
        let headers: HTTPHeaders = [
            "X-Device-Auth": Defaults[.teamAuth]
        ]
        let url = base + "/\(Defaults[.teamID])/device"
        os_log("Requesting %{public}s", url)
        return AF.request(
            url,
            method: .put,
            parameters: device,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ).validate().cURLDescription { cmd in
            debugPrint(cmd)
        }.response(queue: queue) { data in
            os_log("%{public}s", log: Log.api, data.debugDescription)
        }
    }

    static func update(withReport report: Report) -> DataRequest {
        let headers: HTTPHeaders = [
            "X-Device-Auth": Defaults[.teamAuth]
        ]
        let url = base + "/\(Defaults[.teamID])/device"
        os_log("Requesting %{public}s", url)
        return AF.request(
            url,
            method: .patch,
            parameters: report,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ) { $0.timeoutInterval = 15 }.cURLDescription { cmd in
            debugPrint(cmd)
        }.redirect(using: Redirector(behavior: .doNotFollow)).responseDecodable(of: TokenSettings.self, queue: queue) { data in
            if data.response?.statusCode == 301 {
                os_log("Move detected, updating ticket", log: Log.api)
                do {
                    let ticket = try VerifyTeamTicket(withTicket: data.value!.token)
                    Defaults[.license] = data.value!.token
                    Defaults[.userID] = ""
                    Defaults[.teamAuth] = ticket.teamAuth
                    Defaults[.teamID] = ticket.teamUUID
                    AppInfo.Licensed = true
                    Defaults[.reportingRole] = .team
                    Defaults[.isTeamOwner] = ticket.isTeamOwner
                } catch {
                    os_log("Move detected, ticket parsing failed", log: Log.api)
                }
            } else {
                os_log("%{public}s", log: Log.api, data.debugDescription)
            }
        }
    }

    static func settings(completion: @escaping (DeviceSettings?) -> Void) {
        let headers: HTTPHeaders = [
            "X-Device-Auth": Defaults[.teamAuth]
        ]
        AF.request(
            base + "/\(Defaults[.teamID])/settings",
            method: .get,
            headers: headers
        ) { $0.timeoutInterval = 5 }.cURLDescription { cmd in
            debugPrint(cmd)
        }.validate().responseDecodable(of: DeviceSettings.self, queue: queue) { response in
            if response.error == nil {
                completion(response.value)
            } else {
                os_log("Device status failed: %{public}s", response.error.debugDescription)
                completion(nil)
            }
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

class TeamSettingsUpdater: ObservableObject {
    @Published var ignoredChecks: [String] = []
    @Published var enforcedChecks: [String] = []
    @Published var name: String = "Default Team"
    @Published var admin: String = "admin@niteo.co"

    func update(completion: @escaping () -> Void) {
        Team.settings { res in
            self.ignoredChecks = res?.ignoredList ?? []
            self.enforcedChecks = res?.enforcedList ?? []
            self.name = res?.name ?? "Default Team"
            self.admin = res?.admin ?? "admin@niteo.co"
            os_log("Team ignored checks: %s", self.ignoredChecks.debugDescription)
            os_log("Team enforced checks: %s", self.enforcedChecks.debugDescription)
            completion()
        }
    }

    func updateIgnored() {
        if Defaults[.appliedIgnoredChecks] {
            os_log("Team ignored checks already applied once.")
            return
        }

        for claim in Claims.all {
            for check in claim.checks {
                if ignoredChecks.contains(where: { $0 == check.UUID }) {
                    check.isActive = false
                }
            }
        }
        os_log("Team ignored checks applied.")
        Defaults[.appliedIgnoredChecks] = true
    }
}
