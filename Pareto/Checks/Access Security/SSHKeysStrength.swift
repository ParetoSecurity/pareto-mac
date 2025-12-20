//
//  SSHKeysStrengthCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/12/2021.
//
import Defaults
import Foundation
import os.log
import Regex

extension String {
    func strip() -> String {
        replacingAllMatches(of: Regex("[\n()]"), with: "")
    }

    func strip(_ string: String) -> String {
        replacingOccurrences(of: string, with: "")
    }
}

enum Cipher: String {
    case ED25519
    case ED25519_SK = "ED25519-SK"
    case ECDSA
    case ECDSA_SK = "ECDSA-SK"
    case DSA
    case RSA
}

struct KeyInfo: Equatable, ExpressibleByStringLiteral {
    var strength: Int = 0
    var signature: String = ""
    var cipher = Cipher.RSA

    // MARK: - Equatable Methods

    static func == (lhs: KeyInfo, rhs: KeyInfo) -> Bool {
        return lhs.signature == rhs.signature
    }

    // MARK: - ExpressibleByStringLiteral Methods

    init(stringLiteral value: String) {
        let components = value.components(separatedBy: " ")
        if components.count >= 4 {
            let rawCipher = components.last!.strip().uppercased()
            strength = Int(components[0]) ?? 0
            signature = components[1]
            cipher = Cipher(rawValue: rawCipher) ?? Cipher.RSA
        }
    }

    init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }

    init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

class SSHKeysStrengthCheck: SSHCheck {
    static let sharedInstance = SSHKeysStrengthCheck()
    private var sshKey = ""

    override var UUID: String {
        "b6aaec0f-d76c-429e-aecf-edab7f1ac400"
    }

    override var TitleON: String {
        "SSH keys use strong encryption"
    }

    override var TitleOFF: String {
        if sshKey.isEmpty {
            return "SSH key is using weak encryption"
        }
        return "SSH key \(sshKey) is using weak encryption"
    }

    func isKeyStrong(withKey path: String) -> Bool {
        let output = runCMD(app: getSSHKeygenPath(), args: ["-l", "-f", path])
        let info = KeyInfo(stringLiteral: output.strip())
        os_log("%{public}s has %d", log: Log.check, path, info.strength)
        // https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-57pt3r1.pdf
        switch info.cipher {
        case .RSA:
            return info.strength >= 2048 // for 2020 till 2030
        case .DSA:
            return info.strength >= 8192 // considered insecure, check requires much higher strength than attainable
        case .ECDSA, .ECDSA_SK:
            return info.strength >= 521 // for 2020 & beyond
        case .ED25519, .ED25519_SK:
            return info.strength >= 256 // recommended
        }
    }

    override func checkPasses() -> Bool {
        if !hasPrerequites() {
            return true
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: sshPath, includingPropertiesForKeys: nil).filter { $0.pathExtension == "pub" }
            for pub in files {
                let privateKey = pub.path.replacingOccurrences(of: ".pub", with: "")
                if !itExists(privateKey) {
                    continue
                }
                // Skip ignored keys by base filename
                let baseName = pub.deletingPathExtension().lastPathComponent
                if Defaults[.ignoredSSHKeys].contains(baseName) {
                    continue
                }
                if !isKeyStrong(withKey: pub.absoluteURL.path) {
                    sshKey = pub.lastPathComponent.replacingOccurrences(of: ".pub", with: "")
                    return false
                }
            }
            return true
        } catch {
            os_log("Failed to check SSH keys strength %{public}s", error.localizedDescription)
            return true
        }
    }
}
