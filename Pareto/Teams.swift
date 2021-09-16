//
//  Team.swift
//  Team
//
//  Created by Janez Troha on 16/09/2021.
//

import Alamofire
import Defaults
import Foundation

struct ReportingDevice: Encodable {
    let id: String
    let machineUUID: String

    static func current() -> ReportingDevice {
        return ReportingDevice(
            id: Defaults[.deviceID],
            machineUUID: Defaults[.machineUUID]
        )
    }
}

struct Report: Encodable {
    let passedCount: Int
    let failedCount: Int
    let disabledCount: Int
    let device: ReportingDevice
    let version: String
    let lastChecked: String

    static func now() -> Report {
        var passed = 0
        var failed = 0
        var disabled = 0

        for claim in AppInfo.claims {
            for check in claim.checks {
                if check.isActive {
                    if check.checkPassed {
                        passed += 1
                    } else {
                        failed += 1
                    }
                } else {
                    disabled += 1
                }
            }
        }

        return Report(
            passedCount: passed,
            failedCount: failed,
            disabledCount: disabled,
            device: ReportingDevice.current(),
            version: AppInfo.appVersion,
            lastChecked: Date.fromTimeStamp(timeStamp: Defaults[.lastCheck]).as3339String()
        )
    }
}

enum Team {
    public static let defaultAPI = "https://dash.paretosecurity.app/api/v1/team"
    private static let base = Defaults[.teamAPI]

    static func link(withDevice device: ReportingDevice) throws -> Request {
        return AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .put,
            parameters: device,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { description in
            print(description)
        }.validate().responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }

    static func unlink(withDevice device: ReportingDevice) throws -> Request {
        AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .delete,
            parameters: device,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { description in
            print(description)
        }.validate().responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }

    static func update(withReport report: Report) throws -> Request {
        AF.request(
            base + "/\(Defaults[.teamID])/device",
            method: .post,
            parameters: report,
            encoder: JSONParameterEncoder.default
        ).cURLDescription { description in
            print(description)
        }.validate().responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
}
