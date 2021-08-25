//
//  Boot.swift
//  Boot
//
//  Created by Janez Troha on 18/08/2021.
//

import Foundation
import IOKit

class BootCheck: ParetoCheck {
    override var UUID: String {
        "b96524e0-850b-4bb9-abc7-517051b6c14e"
    }

    override var Title: String {
        "Boot is secure"
    }

    func GetNVRAM(_ name: String) -> String {
        let port = IOServiceGetMatchingService(kIOMasterPortDefault, nil)
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

    override func checkPasses() -> Bool {
        // only returns something if AMFI is disabled
        return GetNVRAM("boot-args") == ""
    }
}
