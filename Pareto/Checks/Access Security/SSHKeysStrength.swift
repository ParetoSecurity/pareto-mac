//
//  SSHKeysStrengthCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/12/2021.
//
import Foundation
import os.log
import Regex

private extension String {
    func strip() -> String {
        replacingAllMatches(of: Regex("[\n()]"), with: "")
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
    var owner: String = ""
    var cipher = Cipher.RSA

    // MARK: - Equatable Methods

    public static func == (lhs: KeyInfo, rhs: KeyInfo) -> Bool {
        return (lhs.signature == rhs.signature)
    }

    // MARK: - ExpressibleByStringLiteral Methods

    public init(stringLiteral value: String) {
        let components = value.components(separatedBy: " ")
        if components.count == 4 {
            strength = Int(components[0]) ?? 0
            signature = components[1]
            owner = components[2]
            cipher = Cipher(rawValue: components[3].strip().uppercased()) ?? Cipher.RSA
        }
    }

    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

class SSHKeysStrengthCheck: ParetoCheck {
    static let sharedInstance = SSHKeysStrengthCheck()
    private let sshPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh").resolvingSymlinksInPath()
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

    func itExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    override var isRunnable: Bool {
        if !itExists("/usr/bin/ssh-keygen") {
            os_log("Not found /usr/bin/ssh-keygen, check disabled")
        }
        if !itExists(sshPath.path) {
            os_log("Not found ~/.ssh, check disabled")
        }
        return itExists("/usr/bin/ssh-keygen") && itExists(sshPath.path) && isActive
    }

    func isKeyStrong(withKey path: String) -> Bool {
        let output = runCMD(app: "/usr/bin/ssh-keygen", args: ["-l", "-f", path])
        let info = KeyInfo(stringLiteral: output.strip())
        os_log("%s has %d", path, info.strength)
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
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sshPath, includingPropertiesForKeys: nil).filter { $0.pathExtension == "pub" }
            for pub in files {
                let privateKey = pub.path.replacingOccurrences(of: ".pub", with: "")
                if !itExists(privateKey) {
                    continue
                }
                if !isKeyStrong(withKey: pub.path) {
                    os_log("Checking %{public}s", pub.path)
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
