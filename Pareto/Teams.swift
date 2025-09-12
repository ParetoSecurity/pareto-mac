//
//  Teams.swift
//  Team
//
//  Created by Janez Troha on 16/09/2021.
//

import Alamofire
import AppKit
import CryptoKit
import Defaults
import Foundation
import JWTDecode
import os.log

struct DeviceSettings: Codable {
    let requiredChecks: [APICheck]
    let forceSerialPush: Bool

    var enforcedList: [String] {
        requiredChecks.map { $0.id }
    }
}

struct APICheck: Codable {
    let id: String
}

struct DeviceEnrollmentRequest: Encodable {
    let inviteID: String
    let device: ReportingDevice

    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
        case device
    }
}

struct DeviceEnrollmentResponse: Codable {
    let auth: String
}

struct TokenError: Swift.Error {
    let localizedDescription: String

    init(_ message: String) {
        localizedDescription = message
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
    private static let queue = DispatchQueue(label: "co.pareto.api", qos: .userInteractive, attributes: .concurrent)

    static func showDeviceRemovedAlert() {
        // Only show alert once per week
        if Defaults.shouldShowDeviceRemovedAlert() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Device Unlinked"
                alert.informativeText = "This device has been removed from Pareto Cloud.\n\nUnlink the device in the app preferences or contact your administrator to link your device again."
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: "OK")
                alert.runModal()

                // Update timestamp after showing the alert
                Defaults[.lastDeviceRemovedAlert] = Date().currentTimeMs()
            }
        } else {
            os_log("Device removed alert suppressed (shown recently)", log: Log.api)
        }
    }

    static func enrollDevice(inviteID: String, completion: @escaping (Result<(String, String), Swift.Error>) -> Void) {
        let request = DeviceEnrollmentRequest(inviteID: inviteID, device: ReportingDevice.current())
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
        ]

        let url = URL(string: Defaults[.teamAPI])!.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("team").appendingPathComponent("enroll").absoluteString

        os_log("Enrolling device with invite ID: %{public}@", log: Log.api, inviteID)
        os_log("Enrollment URL: %{public}@", log: Log.api, url)
        // Log request body
        if let requestData = try? JSONEncoder().encode(request),
           let requestString = String(data: requestData, encoding: .utf8)
        {
            os_log("Request body: %{public}@", log: Log.api, requestString)
        }

        AF.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ) { $0.timeoutInterval = 10 }
            .cURLDescription { curl in
                os_log("cURL command: %{public}@", log: Log.api, curl)
            }
            .validate()
            .responseDecodable(of: DeviceEnrollmentResponse.self, queue: queue) { response in
                os_log("Enrollment response status: %d", log: Log.api, response.response?.statusCode ?? -1)
                os_log("Enrollment response headers: %{public}@", log: Log.api, response.response?.allHeaderFields.debugDescription ?? "None")

                if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                    os_log("Enrollment response body: %{public}@", log: Log.api, responseString)
                }

                os_log("Full enrollment response: %{public}@", log: Log.api, response.debugDescription)

                switch response.result {
                case let .success(enrollmentResponse):
                    os_log("Device enrollment successful, auth token received", log: Log.api)
                    // Extract team ID from the JWT token
                    if let teamID = extractTeamIDFromToken(enrollmentResponse.auth) {
                        os_log("Team ID extracted successfully: %{public}@", log: Log.api, teamID)
                        completion(.success((enrollmentResponse.auth, teamID)))
                    } else {
                        os_log("Failed to extract team ID from JWT token", log: Log.api)
                        completion(.failure(TokenError("Invalid authentication token")))
                    }
                case let .failure(error):
                    os_log("Device enrollment failed with error: %{public}@", log: Log.api, error.localizedDescription)
                    completion(.failure(error))
                }
            }
    }

    private static func extractTeamIDFromToken(_ token: String) -> String? {
        do {
            let jwt = try decode(jwt: token)
            return jwt.claim(name: "team_id").string
        } catch {
            os_log("Failed to extract team ID from token: %{public}@", error.localizedDescription)
            return nil
        }
    }

    static func update(withReport report: Report) -> DataRequest {
        let headers: HTTPHeaders = [
            "X-Device-Auth": Defaults[.teamAuth],
        ]
        let url = URL(string: Defaults[.teamAPI])!.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("team").appendingPathComponent("\(Defaults[.teamID])").appendingPathComponent("device").absoluteString

        os_log("Updating device report for team ID: %{public}@", log: Log.api, Defaults[.teamID])
        os_log("Update URL: %{public}@", log: Log.api, url)
        // Log report summary
        os_log("Report summary - Passed: %d, Failed: %d, Disabled: %d", log: Log.api, report.passedCount, report.failedCount, report.disabledCount)
        os_log("Device info - Name: %{public}@, OS: %{public}@", log: Log.api, report.device.machineName, report.device.macOSVersion)

        // Log request body (truncated for security)
        if let reportData = try? JSONEncoder().encode(report),
           let reportString = String(data: reportData, encoding: .utf8)
        {
            let truncatedReport = reportString.count > 1000 ? String(reportString.prefix(1000)) + "... [truncated]" : reportString
            os_log("Report body: %{public}@", log: Log.api, truncatedReport)
        }

        return AF.request(
            url,
            method: .patch,
            parameters: report,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ) { $0.timeoutInterval = 15 }.cURLDescription { cmd in
            os_log("Update cURL command: %{public}@", log: Log.api, cmd)
        }.validate().response(queue: queue) { response in
            os_log("Update response status: %d", log: Log.api, response.response?.statusCode ?? -1)
            os_log("Update response headers: %{public}@", log: Log.api, response.response?.allHeaderFields.debugDescription ?? "None")

            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                os_log("Update response body: %{public}@", log: Log.api, responseString)
            }

            if let error = response.error {
                os_log("Update failed with error: %{public}@", log: Log.api, error.localizedDescription)
            } else {
                os_log("Device report update successful", log: Log.api)
            }

            os_log("Full update response: %{public}@", log: Log.api, response.debugDescription)
        }
    }

    static func settings(completion: @escaping (DeviceSettings?) -> Void) {
        let headers: HTTPHeaders = [
            "X-Device-Auth": Defaults[.teamAuth],
        ]
        let url = URL(string: Defaults[.teamAPI])!.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("team").appendingPathComponent("\(Defaults[.teamID])").appendingPathComponent("settings").absoluteString

        os_log("Fetching team settings for team ID: %{public}@", log: Log.api, Defaults[.teamID])
        os_log("Settings URL: %{public}@", log: Log.api, url)

        AF.request(
            url,
            method: .get,
            headers: headers
        ) { $0.timeoutInterval = 5 }.cURLDescription { cmd in
            os_log("Settings cURL command: %{public}@", log: Log.api, cmd)
        }.validate().responseDecodable(of: DeviceSettings.self, queue: queue) { response in
            os_log("Settings response status: %d", log: Log.api, response.response?.statusCode ?? -1)
            os_log("Settings response headers: %{public}@", log: Log.api, response.response?.allHeaderFields.debugDescription ?? "None")

            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                os_log("Settings response body: %{public}@", log: Log.api, responseString)
            }

            if let error = response.error {
                os_log("Settings request failed with error: %{public}@", log: Log.api, error.localizedDescription)

                // Check if the error is a 404 (device/team not found)
                if let statusCode = response.response?.statusCode, statusCode == 404 {
                    os_log("Settings request failed with 404 - device removed from cloud", log: Log.api)
                    showDeviceRemovedAlert()
                }

                completion(nil)
            } else if let settings = response.value {
                os_log("Settings fetched successfully - Required checks: %d, Force serial push: %{public}s",
                       log: Log.api, settings.requiredChecks.count, settings.forceSerialPush ? "true" : "false")
                os_log("Enforced check IDs: %{public}@", log: Log.api, settings.enforcedList.joined(separator: ", "))
                completion(settings)
            } else {
                os_log("Settings response was successful but no data received", log: Log.api)
                completion(nil)
            }

            os_log("Full settings response: %{public}@", log: Log.api, response.debugDescription)
        }
    }
}

class TeamSettingsUpdater: ObservableObject {
    @Published var enforcedChecks: [String] = []
    @Published var forceSerialPush: Bool = false

    func update(completion: @escaping () -> Void) {
        Team.settings { res in
            self.enforcedChecks = res?.enforcedList ?? []
            self.forceSerialPush = res?.forceSerialPush ?? false
            os_log("Team enforced checks: %{public}@", self.enforcedChecks.debugDescription)
            completion()
        }
    }
}

