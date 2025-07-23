//
//  Teams.swift
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
    let requiredChecks: [APICheck]
    let name: String
    let admin: String
    let forceSerialPush: Bool

    var enforcedList: [String] {
        requiredChecks.map { $0.id }
    }
}

struct APICheck: Codable {
    let id: String
}

struct DeviceEnrollmentRequest: Codable {
    let inviteID: String
    
    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
    }
}

struct DeviceEnrollmentResponse: Codable {
    let auth: String
}

struct TokenError: Swift.Error {
    let localizedDescription: String
    
    init(_ message: String) {
        self.localizedDescription = message
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
        let reason = "Disabled"

        var sendSerial = false
        if Defaults[.sendHWInfo] || AppInfo.TeamSettings.forceSerialPush {
            sendSerial = true
        }

        return ReportingDevice(
            machineUUID: Defaults[.machineUUID],
            machineName: AppInfo.machineName,
            auth: Defaults[.teamAuth],
            macOSVersion: AppInfo.macOSVersionString,
            modelName: sendSerial ? AppInfo.hwModelName : reason,
            modelSerial: sendSerial ? AppInfo.hwSerial : reason
        )
    }
}

struct Report: Encodable {
    enum CheckStatus: String {
        case Disabled = "off", Passing = "pass", Failing = "fail", Error = "error"
    }

    let passedCount: Int
    let failedCount: Int
    let disabledCount: Int
    let device: ReportingDevice
    let version: String
    let lastCheck: String
    let significantChange: String
    let state: [String: String]
    let sbom: [PublicApp]

    static func now() -> Report {
        var passed = 0
        var failed = 0
        var disabled = 0
        var disabledSeed = "\(Defaults[.machineUUID])"
        var failedSeed = "\(Defaults[.machineUUID])"
        var checkStates: [String: String] = [:]

        for claim in Claims.global.all {
            for check in claim.checks {
                if check.isRunnable {
                    if check.hasError {
                        failed += 1
                        failedSeed.append(contentsOf: check.UUID)
                        checkStates[check.UUID] = CheckStatus.Error.rawValue
                    } else {
                        if check.checkPassed {
                            passed += 1
                            checkStates[check.UUID] = CheckStatus.Passing.rawValue
                        } else {
                            failed += 1
                            failedSeed.append(contentsOf: check.UUID)
                            checkStates[check.UUID] = CheckStatus.Failing.rawValue
                        }
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

        var sendSerial = false
        if Defaults[.sendHWInfo] || AppInfo.TeamSettings.forceSerialPush {
            sendSerial = true
        }

        return Report(
            passedCount: passed,
            failedCount: failed,
            disabledCount: disabled,
            device: ReportingDevice.current(),
            version: AppInfo.appVersion,
            lastCheck: Date.fromTimeStamp(timeStamp: Defaults[.lastCheck]).as3339String(),
            significantChange: SHA256.hash(data: "\(disabledSeed).\(failedSeed)".data(using: .utf8)!).hexStr,
            state: checkStates,
            sbom: sendSerial ? PublicApp.all : []
        )
    }
}

enum Team {
    static let defaultAPI = "https://cloud.paretosecurity.com/api/v1/team"
    private static let base = Defaults[.teamAPI]
    private static let queue = DispatchQueue(label: "co.pareto.api", qos: .userInteractive, attributes: .concurrent)

    static func enrollDevice(inviteID: String, completion: @escaping (Result<(String, String), Swift.Error>) -> Void) {
        let request = DeviceEnrollmentRequest(inviteID: inviteID)
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        os_log("Enrolling device with invite ID: %{public}s", inviteID)
        
        AF.request(
            "https://cloud.paretosecurity.com/api/v1/team/enroll",
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ) { $0.timeoutInterval = 10 }
        .validate()
        .responseDecodable(of: DeviceEnrollmentResponse.self, queue: queue) { response in
            os_log("%{public}s", log: Log.api, response.debugDescription)
            
            switch response.result {
            case .success(let enrollmentResponse):
                // Extract team ID from the JWT token
                if let teamID = extractTeamIDFromToken(enrollmentResponse.auth) {
                    completion(.success((enrollmentResponse.auth, teamID)))
                } else {
                    completion(.failure(TokenError("Invalid authentication token")))
                }
            case .failure(let error):
                os_log("Device enrollment failed: %{public}s", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }
    
    private static func extractTeamIDFromToken(_ token: String) -> String? {
        do {
            let jwt = try decode(jwt: token)
            return jwt.claim(name: "team_id").string
        } catch {
            os_log("Failed to extract team ID from token: %{public}s", error.localizedDescription)
            return nil
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
        }.response(queue: queue) { data in
            os_log("%{public}s", log: Log.api, data.debugDescription)
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


class TeamSettingsUpdater: ObservableObject {
    @Published var enforcedChecks: [String] = []
    @Published var name: String = "Default Team"
    @Published var admin: String = "admin@niteo.co"
    @Published var forceSerialPush: Bool = false

    func update(completion: @escaping () -> Void) {
        Team.settings { res in
            self.enforcedChecks = res?.enforcedList ?? []
            self.name = res?.name ?? "Default Team"
            self.admin = res?.admin ?? "admin@niteo.co"
            self.forceSerialPush = res?.forceSerialPush ?? false
            os_log("Team enforced checks: %s", self.enforcedChecks.debugDescription)
            completion()
        }
    }
}
