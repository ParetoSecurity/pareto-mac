//
//  License.swift
//  License
//
//  Created by Janez Troha on 10/09/2021.
//

import Foundation
import JWTDecode
import Security
import SwiftUI

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

private extension JWT {
    var uuid: String? {
        return claim(name: "uuid").string
    }

    var role: String? {
        return claim(name: "role").string
    }

    var teamUUID: String? {
        return claim(name: "teamID").string
    }
}

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

enum License {
    public enum Part {
        case header
        case payload
        case signature
    }

    public indirect enum Error: Swift.Error {
        case badTokenStructure
        case cannotDecodeBase64Part(License.Part, String)
        case invalidJSON(License.Part, Swift.Error)
        case invalidJSONStructure(License.Part)
        case typeIsNotAJSONWebToken
        case invalidSignatureAlgorithm(String)
        case missingSignatureAlgorithm
        case invalidSignature
        case invalidLicense
        case badPublicKeyConversion
    }

    public static func verify(jwt token: String, withKey key: String) throws -> Bool {
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

struct LicensePayload: Decodable, Equatable {
    // The "sub" (subject) claim identifies the principal that is the
    // subject of the JWT.
    var subject: String

    // The "exp" (expiration time) claim identifies the expiration time on
    // or after which the JWT MUST NOT be accepted for processing.
    var issuedAt: Date

    // Custom data.
    var uuid: String
    var role: String
}

func VerifyLicense(withLicense data: String, publicKey: String = rsaPublicKey) throws -> LicensePayload {
    if try License.verify(jwt: data, withKey: publicKey) {
        let jwt = try decode(jwt: data)
        return LicensePayload(subject: jwt.subject!, issuedAt: jwt.issuedAt!, uuid: jwt.uuid!, role: jwt.role!)
    }
    throw License.Error.invalidLicense
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
    var role: String
}

func VerifyTeamTicket(withTicket data: String, publicKey key: String = rsaPublicKey) throws -> TeamTicketPayload {
    if try License.verify(jwt: data, withKey: key) {
        let jwt = try decode(jwt: data)
        return TeamTicketPayload(subject: jwt.subject!, issuedAt: jwt.issuedAt!, teamUUID: jwt.teamUUID!, role: jwt.role!)
    }
    throw License.Error.invalidLicense
}
