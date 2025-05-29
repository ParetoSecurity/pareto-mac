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

let rsaPublicKey = """
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwGh64DK49GOq1KX+ojyg
Y9JSAZ4cfm5apavetQ42D2gTjfhDu1kivrDRwhjqj7huUWRI2ExMdMHp8CzrJI3P
zpzutEUXTEHloe0vVMZqPoP/r2f1cl4bmDkFZyHr6XTgiYPE4GgMjxUc04J2ksqU
/XbNwOVsBiuy1T2BduLYiYr1UyIx8VqEb+3tunQKlyRKF7a5LoEZatt5F/5vaMMI
4zp1yIc2PMoBdlBH4/tpJmC/PiwjBuwgp5gMIle4Hy7zwW4+rIJzF5P3Tg+Am+Lg
davB8TIZDBlqIWV7zK1kWBPj364a5cnaUP90BnOriMJBh7zPG0FNGTXTiJED2qDM
fajDrji3oAPO24mJsCCzSd8LIREK5c6iAf1X4UI/UFP+UhOBCsANrhNSXRpO2KyM
+60JYzFpMvyhdK9zMo7Tc+KM6R0YRNmBCYK/ePAGk3WU6qxN5+OmSjdTvFrqC4JQ
FyK51WJI80PKvp3B7ZB7XpH5B24wr/OhMRh5YZOcrpuBykfHaMozkDCudgaj/V+x
K79CqMF/BcSxCSBktWQmabYCM164utpmJaCSpZyDtKA4bYVv9iRCGTqFQT7jX+/h
Z37gmg/+TlIdTAeB5TG2ffHxLnRhT4AAhUgYmk+QP3a1hxP5xj2otaSTZ3DxQd6F
ZaoGJg3y8zjrxYBQDC8gF6sCAwEAAQ==
"""

private extension Data {
    init?(base64URLEncodedString: String, options: Data.Base64DecodingOptions) {
        let input = NSMutableString(string: base64URLEncodedString)
        input.replaceOccurrences(of: "-", with: "+",
                                 options: [.literal],
                                 range: NSRange(location: 0, length: input.length))
        input.replaceOccurrences(of: "_", with: "/",
                                 options: [.literal],
                                 range: NSRange(location: 0, length: input.length))
        switch input.length % 4 {
        case 0:
            break
        case 1:
            input.append("===")
        case 2:
            input.append("==")
        case 3:
            input.append("=")
        default:
            fatalError("unreachable")
        }
        if let decoded = Data(base64Encoded: input as String, options: options) {
            self = decoded
        } else {
            return nil
        }
    }
}

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
    public enum CheckStatus: String {
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
                    let ticket = try TeamTicket.verify(withTicket: data.value!.token)
                    Defaults[.teamTicket] = data.value!.token
                    Defaults[.userID] = ""
                    Defaults[.teamAuth] = ticket.teamAuth
                    Defaults[.teamID] = ticket.teamUUID
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

enum TeamTicket {
    struct Payload: Decodable, Equatable {
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

    public enum Part {
        case header
        case payload
        case signature
    }

    public indirect enum Error: Swift.Error {
        case badTokenStructure
        case cannotDecodeBase64Part(TeamTicket.Part, String)
        case invalidJSON(TeamTicket.Part, Swift.Error)
        case invalidJSONStructure(TeamTicket.Part)
        case typeIsNotAJSONWebToken
        case invalidSignatureAlgorithm(String)
        case missingSignatureAlgorithm
        case invalidSignature
        case invalidTicket
        case badPublicKeyConversion
    }

    public static func migrate(publicKey key: String = rsaPublicKey) {
        do {
            if !Defaults[.license].isEmpty, !Defaults[.migrated] {
                let ticket = try TeamTicket.verify(withTicket: Defaults[.license], publicKey: key)
                Defaults[.teamTicket] = Defaults[.license]
                Defaults[.teamAuth] = ticket.teamAuth
                Defaults[.teamID] = ticket.teamUUID
                Defaults[.reportingRole] = .team
                Defaults[.isTeamOwner] = ticket.isTeamOwner
                Defaults[.migrated] = true
            }
        } catch {
            os_log("Migration detected, ticket parsing failed", log: Log.api)
        }
    }

    public static func verify(withTicket data: String, publicKey key: String = rsaPublicKey) throws -> Payload {
        if try verifySignature(jwt: data, withKey: key) {
            let jwt = try decode(jwt: data)

            let ticket = Payload(
                subject: jwt.subject ?? "",
                issuedAt: jwt.issuedAt ?? Date(),
                teamUUID: jwt.teamUUID ?? "",
                teamAuth: jwt.teamAuth ?? "",
                role: jwt.role ?? "",
                isTeamOwner: jwt.isTeamOwner ?? false
            )

            if !ticket.isValid() {
                throw Error.invalidTicket
            }
            return ticket
        }
        throw Error.invalidTicket
    }

    private static func verifySignature(jwt token: String, withKey key: String) throws -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw Error.badTokenStructure
        }

        let base64Parts: (header: String, payload: String, signature: String)
        base64Parts = (parts[0], parts[1], parts[2])

        guard Data(base64URLEncodedString: base64Parts.header, options: []) != nil else {
            throw Error.cannotDecodeBase64Part(.header, base64Parts.header)
        }
        guard Data(base64URLEncodedString: base64Parts.payload, options: []) != nil else {
            throw Error.cannotDecodeBase64Part(.payload, base64Parts.payload)
        }
        guard let signatureData = Data(base64URLEncodedString: base64Parts.signature, options: []) else {
            throw Error.cannotDecodeBase64Part(.signature, base64Parts.signature)
        }
        guard let input = (base64Parts.header + "." + base64Parts.payload).data(using: String.Encoding.utf8) else {
            throw Error.badTokenStructure
        }
        guard let pubKeyData = Data(base64Encoded: key.replacingOccurrences(of: "\n", with: ""), options: .ignoreUnknownCharacters)! as CFData? else {
            throw Error.badPublicKeyConversion
        }
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        guard let publicKey = SecKeyCreateFromData(attributes as CFDictionary, pubKeyData, &error) else {
            throw Error.badPublicKeyConversion
        }

        return SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA512, input as CFData, signatureData as CFData, nil)
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
