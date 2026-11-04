//
//  Boot.swift
//  Boot
//
//  Created by Janez Troha on 18/08/2021.
//

import Foundation
import IOKit
import os.log

class BootCheck: ParetoCheck {
    static let sharedInstance = BootCheck()

    let sipStatusProvider: () -> String
    let bootArgsProvider: (() -> String)?

    init(
        sipStatusProvider: @escaping () -> String = { runCMD(app: "/usr/bin/csrutil", args: ["status"]) },
        bootArgsProvider: (() -> String)? = nil
    ) {
        self.sipStatusProvider = sipStatusProvider
        self.bootArgsProvider = bootArgsProvider
    }

    override var UUID: String {
        "b96524e0-850b-4bb9-abc7-517051b6c14e"
    }

    override var TitleON: String {
        "Boot is secure"
    }

    override var TitleOFF: String {
        "Boot is unsecure"
    }

    func GetNVRAM(_ name: String) -> String {
        let port = IOServiceGetMatchingService(kIOMainPortDefault, nil)
        let gOptionsRef = IORegistryEntryFromPath(port, "IODeviceTree:/options")

        let nameRef = CFStringCreateWithCString(kCFAllocatorDefault, name, CFStringBuiltInEncodings.UTF8.rawValue)

        let valueRef = IORegistryEntryCreateCFProperty(gOptionsRef, nameRef, kCFAllocatorDefault, 0)

        if valueRef != nil {
            // Read as NSData
            if let data = valueRef?.takeUnretainedValue() as? Data {
                return NSString(data: data, encoding: String.Encoding.ascii.rawValue)! as String
            }
            // Read as String
            return valueRef!.takeRetainedValue() as! String
        } else {
            return ""
        }
    }

    var isSIPEnabled: Bool {
        let output = sipStatusProvider()
        os_log("csrutil status: %{public}@", log: Log.check, output.trim())
        return output.contains("System Integrity Protection status: enabled")
    }

    override func checkPasses() -> Bool {
        // boot-args is only set when AMFI or similar protections are disabled
        let bootArgs = bootArgsProvider?() ?? GetNVRAM("boot-args")
        return bootArgs.isEmpty && isSIPEnabled
    }
}
