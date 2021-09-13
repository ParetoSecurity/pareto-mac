//
//  MenuItemCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import AppKit
import Combine
import Defaults
import Foundation
import os.log
import SwiftUI

class ParetoCheck: Hashable, ObservableObject, Identifiable {
    static func == (lhs: ParetoCheck, rhs: ParetoCheck) -> Bool {
        lhs.UUID == rhs.UUID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(UUID)
    }

    private(set) var UUID = "UUID"
    private(set) var TitleON = "TitleON"
    private(set) var TitleOFF = "TitleOFF"
    private(set) var canRunInSandbox = true

    var EnabledKey: String {
        "ParetoCheck-" + UUID + "-Enabled"
    }

    var PassesKey: String {
        "ParetoCheck-" + UUID + "-Passes"
    }

    var TimestampKey: String {
        "ParetoCheck-" + UUID + "-TS"
    }

    var Title: String {
        checkPassed ? TitleON : TitleOFF
    }

    public var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: EnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: EnabledKey) }
    }

    var checkTimestamp: Int {
        get { UserDefaults.standard.integer(forKey: TimestampKey) }
        set { UserDefaults.standard.set(newValue, forKey: TimestampKey) }
    }

    var checkPassed: Bool {
        get { UserDefaults.standard.bool(forKey: PassesKey) }
        set { UserDefaults.standard.set(newValue, forKey: PassesKey) }
    }

    func checkPasses() -> Bool {
        fatalError("checkPasses() is not implemented")
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: Title, action: #selector(moreInfo), keyEquivalent: "")
        item.target = self
        if isActive {
            if Defaults[.snoozeTime] > 0 {
                item.image = NSImage.SF(name: "seal.fill").tint(color: .systemGray)
            } else {
                if checkPassed {
                    item.image = NSImage.SF(name: "checkmark.seal.fill").tint(color: .systemGreen)
                } else {
                    item.image = NSImage.SF(name: "xmark.seal.fill").tint(color: .systemOrange)
                }
            }
        } else {
            item.image = NSImage.SF(name: "seal")
        }

        return item
    }

    func configure() {
        UserDefaults.standard.register(defaults: [
            EnabledKey: true,
            PassesKey: false,
            TimestampKey: 0
        ])
    }

    func run() {
        if !isActive {
            os_log("Disabled for %{public}s - %{public}s", log: Log.app, UUID, Title)
            return
        }

        os_log("Running check for %{public}s - %{public}s", log: Log.app, UUID, Title)
        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())
    }

    @objc func moreInfo() {
        if let url = URL(string: "https://paretosecurity.app/check/" + UUID + "?utm_source=app") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension ParetoCheck {
    func readDefaults(app: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["-currentHost", "read", app, key])
        return output.contains("does not exist") ? nil : output
    }

    func readDefaultsFile(path: String) -> NSDictionary? {
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        return dictionary
    }

    func appVersion(app: String) -> String? {
        let path = "/Applications/\(app).app/Contents/Info.plist"
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        // print("\(app): \(dictionary as AnyObject)")
        return dictionary.value(forKey: "CFBundleShortVersionString") as? String
    }

    func isNotListening(withPort port: Int) -> Bool {
        let port = UInt16(port)
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }

        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))

        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            return false
        }
        let isClosed = listen(socketFileDescriptor, SOMAXCONN) != -1
        Darwin.close(socketFileDescriptor)
        return isClosed
    }
}
