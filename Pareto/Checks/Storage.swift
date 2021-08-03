//
//  Storage.swift
//  Storage
//
//  Created by Janez Troha on 03/08/2021.
//
import Foundation
import os.log

class StorageCheck: ParetoCheck {
    final var ID = "c3aee29a-f16d-4573-a861-b3ba0d860061"
    final var TITLE = "Enough free disk storage"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }
    var systemSize: Int64 {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
            let totalSize = (systemAttributes[.systemSize] as? NSNumber)?.int64Value else {
                return 0
        }

        return totalSize
    }

    var systemFreeSize: Int64 {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
            let freeSize = (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value else {
                return 0
        }

        return freeSize
    }
    
    override func checkPasses() -> Bool {
        let used = self.systemSize - self.systemFreeSize
        let perFree = (100 / self.systemSize ) * used
        os_log("systemSize: %{public}d", log: Log.check, systemSize)
        os_log("systemFreeSize: %{public}d", log: Log.check, systemSize)
        os_log("used: %{public}d", log: Log.check, used)
        os_log("perFree: %{public}d", log: Log.check, perFree)
        return perFree >= 20
    }
}

