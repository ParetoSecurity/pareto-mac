//
//  License.swift
//  License
//
//  Created by Janez Troha on 10/09/2021.
//

import Foundation
import JWTKit
import SwiftUI

let rsaPublicKey = """
-----BEGIN PUBLIC KEY-----
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
-----END PUBLIC KEY-----
"""

struct LicensePayload: JWTPayload, Equatable {
    // Maps the longer Swift property names to the
    // shortened keys used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case issuedAt = "iat"
        case role
        case uuid
    }

    // The "sub" (subject) claim identifies the principal that is the
    // subject of the JWT.
    var subject: SubjectClaim

    // The "exp" (expiration time) claim identifies the expiration time on
    // or after which the JWT MUST NOT be accepted for processing.
    var issuedAt: IssuedAtClaim

    // Custom data.
    var uuid: String
    var role: AudienceClaim

    func verify(using _: JWTSigner) throws {
        try role.verifyIntendedAudience(includes: "single")
    }
}

func VerifyLicense(withLicense data: String, publicKey: String = rsaPublicKey) throws -> LicensePayload {
    let signers = JWTSigners()
    try signers.use(.rs512(key: .public(pem: publicKey)))
    return try signers.verify(data, as: LicensePayload.self)
}

struct TeamTicketPayload: JWTPayload, Equatable {
    // Maps the longer Swift property names to the
    // shortened keys used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case issuedAt = "iat"
        case teamUUID = "teamID"
        case deviceUUID = "deviceID"
        case role
    }

    // The "sub" (subject) claim identifies the principal that is the
    // subject of the JWT.
    var subject: SubjectClaim

    // The "exp" (expiration time) claim identifies the expiration time on
    // or after which the JWT MUST NOT be accepted for processing.
    var issuedAt: IssuedAtClaim

    // Custom data.
    var teamUUID: String
    var deviceUUID: String
    var role: AudienceClaim

    func verify(using _: JWTSigner) throws {
        try role.verifyIntendedAudience(includes: "team")
    }
}

func VerifyTeamTicket(withTicket data: String, publicKey: String = rsaPublicKey) throws -> TeamTicketPayload {
    let signers = JWTSigners()
    try signers.use(.rs512(key: .public(pem: publicKey)))
    return try signers.verify(data, as: TeamTicketPayload.self)
}
