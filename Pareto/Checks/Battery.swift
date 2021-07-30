//
//  Battery.swift
//  Battery
//
//  Created by Janez Troha on 30/07/2021.
//

import Foundation
import IOKit
import IOKit.ps
import os.log

public class Battery {
    public var batteryInstalled: Bool?
    public var cycleCount: Int?
    public var designCycleCount: Int?
    public var avgTimeToEmpty: Int?

    public init() {}
}

// ioreg -b -w 0 -f -r -c AppleSmartBattery
public class BatteryInfo {
    static let BatteryInstalled = "BatteryInstalled" as CFString
    static let CycleCount = "CycleCount" as CFString
    static let AvgTimeToEmpty = "avgTimeToEmpty" as CFString
    static let DesignCycleCount = "DesignCycleCount9C" as CFString

    private var serviceInternal: io_connect_t = 0 // io_object_t

    public init() {}

    private func open() {
        serviceInternal = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
    }

    private func close() {
        IOServiceClose(serviceInternal)
        IOObjectRelease(serviceInternal)
        serviceInternal = 0
    }

    private func getIntValue(_ identifier: CFString) -> Int? {
        if let value = IORegistryEntryCreateCFProperty(serviceInternal, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Int
        }

        return nil
    }

    private func getStringValue(_ identifier: CFString) -> String? {
        if let value = IORegistryEntryCreateCFProperty(serviceInternal, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? String
        }

        return nil
    }

    private func getBoolValue(_ forIdentifier: CFString) -> Bool? {
        if let value = IORegistryEntryCreateCFProperty(serviceInternal, forIdentifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Bool
        }

        return nil
    }

    public func getInternalBattery() -> Battery {
        open()

        let battery = Battery()
        battery.batteryInstalled = getBoolValue(BatteryInfo.BatteryInstalled) ?? false
        battery.cycleCount = getIntValue(BatteryInfo.CycleCount) ?? 0
        battery.designCycleCount = getIntValue(BatteryInfo.DesignCycleCount) ?? 1000
        battery.avgTimeToEmpty = getIntValue(BatteryInfo.AvgTimeToEmpty) ?? 800

        close()

        return battery
    }
}

class BatteryCheck: ParetoCheck {
    final var ID = "2e46c89a-5461-4865-a92e-3b799c12034f"
    final var TITLE = "Battery healthy"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let bat = BatteryInfo().getInternalBattery()
        os_log("batteryService isInstalled:%{public}d", log: Log.check, bat.batteryInstalled!)
        if bat.batteryInstalled! {
            os_log("batteryService cycleCount:%{public}d", log: Log.check, bat.cycleCount!)
            os_log("batteryService designCycleCount:%{public}d", log: Log.check, bat.designCycleCount!)
            os_log("batteryService avgTimeToEmpty:%{public}d", log: Log.check, bat.avgTimeToEmpty!)
            return bat.cycleCount! < bat.designCycleCount!
        }
        return false
    }
}
