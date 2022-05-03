//
//  TimeMachineBackup.swift
//  Pareto Security
//
//  Created by Janez Troha on 03/05/2022.
//

import Foundation

struct TimeMachineDestinations: Codable {
    let LastKnownEncryptionState: String
    let DestinationID: String
    let ConsistencyScanDate: Date // Last time of backup

    init(obj: NSDictionary) {
        LastKnownEncryptionState = obj.value(forKey: "LastKnownEncryptionState") as? String ?? ""
        DestinationID = obj.value(forKey: "DestinationID") as? String ?? ""
        ConsistencyScanDate = obj.value(forKey: "ConsistencyScanDate") as? Date ?? Date.distantPast
    }

    var isEncrypted: Bool {
        return !LastKnownEncryptionState.isEmpty
    }

    var upToDateBackup: Bool {
        let weekAgo = Date().addingTimeInterval(-(7 * 24 * 60 * 60))
        return ConsistencyScanDate >= weekAgo
    }
}

struct TimeMachineConfig: Codable {
    let AutoBackup: Bool
    let HostUUIDs: [String]
    let Destinations: [TimeMachineDestinations]
    let LastDestinationID: String

    init(obj: NSDictionary) {
        AutoBackup = (obj.value(forKey: "AutoBackup") as? Int ?? 0) != 0
        HostUUIDs = obj.mutableArrayValue(forKey: "HostUUIDs") as? [String] ?? []
        LastDestinationID = obj.value(forKey: "LastDestinationID") as? String ?? ""
        Destinations = (obj.mutableArrayValue(forKey: "Destinations") as? [NSDictionary] ?? []).map { dict in
            TimeMachineDestinations(obj: dict)
        }
    }

    var upToDateBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        let lastBackupDestination = Destinations.filter { dests in
            dests.DestinationID != LastDestinationID
        }

        return lastBackupDestination.first?.upToDateBackup ?? false
    }

    var isEncryptedBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        let lastBackupDestination = Destinations.filter { dests in
            dests.DestinationID != LastDestinationID
        }

        return lastBackupDestination.first?.isEncrypted ?? false
    }
}
