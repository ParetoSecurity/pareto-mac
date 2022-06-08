//
//  TimeMachineBackup.swift
//  Pareto Security
//
//  Created by Janez Troha on 03/05/2022.
//

import Foundation

enum EncryptionState: String {
    case Encrypted, NotEncrypted, Unknown = ""
}

struct TimeMachineDestinations {
    let LastKnownEncryptionState: EncryptionState
    let DestinationID: String
    let ConsistencyScanDate: Date // Last time of backup

    init(obj: [String: Any]?) {
        guard let dict = obj else {
            LastKnownEncryptionState = EncryptionState.Unknown
            DestinationID = ""
            ConsistencyScanDate = Date.distantPast
            return
        }

        LastKnownEncryptionState = EncryptionState(rawValue: dict["LastKnownEncryptionState"] as? String ?? "") ?? EncryptionState.Unknown
        DestinationID = dict["DestinationID"] as? String ?? ""
        ConsistencyScanDate = dict["ConsistencyScanDate"] as? Date ?? Date.distantPast
    }

    var isEncrypted: Bool {
        return LastKnownEncryptionState == EncryptionState.Encrypted
    }

    var isUpToDateBackup: Bool {
        let weekAgo = Date().addingTimeInterval(-(7 * 24 * 60 * 60))
        return ConsistencyScanDate >= weekAgo
    }
}

struct TimeMachineConfig {
    let AutoBackup: Bool
    let Destinations: [TimeMachineDestinations]
    let LastDestinationID: String

    init(obj: NSDictionary) {
        guard let dict = obj as? [String: Any]? else {
            AutoBackup = false
            Destinations = []
            LastDestinationID = ""
            return
        }
        AutoBackup = dict?["AutoBackup"] as? Bool ?? false
        LastDestinationID = dict?["LastDestinationID"] as? String ?? ""
        Destinations = (dict?["Destinations"] as? [[String: Any]?] ?? []).map { dict in
            TimeMachineDestinations(obj: dict)
        }
    }

    var upToDateBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        let lastBackupDestination = Destinations.filter { dests in
            dests.DestinationID == LastDestinationID
        }

        return lastBackupDestination.first?.isUpToDateBackup ?? false
    }

    var isEncryptedBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        let lastBackupDestination = Destinations.filter { dests in
            dests.DestinationID == LastDestinationID
        }

        return lastBackupDestination.first?.isEncrypted ?? false
    }
}
