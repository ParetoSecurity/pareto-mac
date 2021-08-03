//
//  Storage.swift
//  Storage
//
//  Created by Janez Troha on 03/08/2021.
//
import Foundation

class StorageCheck: ParetoCheck {
    final var ID = "c3aee29a-f16d-4573-a861-b3ba0d860061"
    final var TITLE = "Enough free storage"

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

        return self.systemFreeSize >= self.systemSize
    }
}

