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
    let ReferenceLocalSnapshotDate: Date // Last time of backup
    let BackupAlias: Data
    let IsNAS: Bool

    init(obj: [String: Any]?) {
        guard let dict = obj else {
            LastKnownEncryptionState = EncryptionState.Unknown
            DestinationID = ""
            ReferenceLocalSnapshotDate = Date.distantPast
            BackupAlias = Data(capacity: 0)
            IsNAS = false
            return
        }
        BackupAlias = dict["BackupAlias"] as? Data ?? Data(capacity: 0)
        let backup = String(decoding: BackupAlias, as: UTF8.self)
        IsNAS = backup.contains("afp://") || backup.contains("smb://")
        LastKnownEncryptionState = EncryptionState(rawValue: dict["LastKnownEncryptionState"] as? String ?? "") ?? EncryptionState.Unknown
        DestinationID = dict["DestinationID"] as? String ?? ""
        ReferenceLocalSnapshotDate = dict["ReferenceLocalSnapshotDate"] as? Date ?? Date.distantPast
    }

    var isEncrypted: Bool {
        return LastKnownEncryptionState == EncryptionState.Encrypted
    }

    var isUpToDateBackup: Bool {
        let weekAgo = Date().addingTimeInterval(-(7 * 24 * 60 * 60))
        return ReferenceLocalSnapshotDate >= weekAgo
    }
}

struct TimeMachineConfig {
    let AutoBackup: Bool
    let Destinations: [TimeMachineDestinations]
    let LastDestinationID: String

    init(dict: [String: Any]) {
        AutoBackup = dict["AutoBackup"] as? Bool ?? false
        LastDestinationID = dict["LastDestinationID"] as? String ?? ""
        Destinations = (dict["Destinations"] as? [[String: Any]?] ?? []).map { dict in
            TimeMachineDestinations(obj: dict)
        }
    }

    var upToDateBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        return Destinations.contains { d in
            d.isUpToDateBackup
        }
    }

    var isEncryptedBackup: Bool {
        return Destinations.allSatisfy { d in
            d.isEncrypted
        }
    }

    var canCheckIsEncryptedBackup: Bool {
        // no backup made yet
        if LastDestinationID.isEmpty {
            return false
        }

        let lastBackupDestination = Destinations.filter { dests in
            dests.DestinationID == LastDestinationID
        }

        return !(lastBackupDestination.first?.IsNAS ?? false)
    }
}
