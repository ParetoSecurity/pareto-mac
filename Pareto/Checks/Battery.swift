//
//  Battery.swift
//  Battery
//
//  Created by Janez Troha on 30/07/2021.
//

import Foundation
import IOKit
import os.log

class BatteryCheck: ParetoCheck {
    final var ID = "2e46c89a-5461-4865-a92e-3b799c12034f"
    final var TITLE = "Battery healthy"

    // ioreg -b -w 0 -f -r -c AppleSmartBattery
    func isBatteryInstalled() -> Bool {
        var batteryInstalled: Bool? {
            let batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))

            guard batteryService > 0 else {
                return nil
            }

            guard let batteryInstalled = (IORegistryEntryCreateCFProperty(batteryService, "BatteryInstalled" as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? Bool) else {
                return nil
            }

            IOObjectRelease(batteryService)

            return batteryInstalled
        }

        return batteryInstalled ?? false
    }

    func cycleCount() -> Int {
        var cycleCount: Int? {
            let batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("CycleCount"))

            guard batteryService > 0 else {
                return nil
            }

            guard let cycleCount = (IORegistryEntryCreateCFProperty(batteryService, "CycleCount" as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? Int) else {
                return nil
            }

            IOObjectRelease(batteryService)

            return cycleCount
        }

        return cycleCount ?? 0
    }

    func avgTimeToEmpty() -> Int {
        var avgTimeToEmpty: Int? {
            let batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("avgTimeToEmpty"))

            guard batteryService > 0 else {
                return nil
            }

            guard let avgTimeToEmpty = (IORegistryEntryCreateCFProperty(batteryService, "avgTimeToEmpty" as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? Int) else {
                return nil
            }

            IOObjectRelease(batteryService)

            return avgTimeToEmpty
        }

        return avgTimeToEmpty ?? 0
    }

    func designedCycleCount() -> Int {
        var designedCycleCount: Int? {
            let batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("CycleCount"))

            guard batteryService > 0 else {
                return nil
            }

            guard let designedCycleCount = (IORegistryEntryCreateCFProperty(batteryService, "DesignCycleCount9C" as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? Int) else {
                return nil
            }

            IOObjectRelease(batteryService)

            return designedCycleCount
        }

        return designedCycleCount ?? 0
    }

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        if isBatteryInstalled() {
            return cycleCount() < designedCycleCount()
        }
        return false
    }
}
