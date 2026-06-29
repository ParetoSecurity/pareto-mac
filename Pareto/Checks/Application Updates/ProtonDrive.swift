//
//  ProtonDrive.swift
//  Pareto Security
//
//  Created by Janez Troha on 29/06/2026.
//

class AppProtonDriveCheck: AppCheck {
    static let sharedInstance = AppProtonDriveCheck()

    override var appName: String { "Proton Drive" }
    override var appMarketingName: String { "Proton Drive" }
    override var appBundle: String { "ch.protonmail.drive" }
    override var sparkleURL: String { "https://proton.me/download/drive/macos/appcast.xml" }
    override var sparkleChannel: String? { "stable" }

    override var UUID: String {
        "93b44905-9f61-5d78-84dd-cdc5479165d7"
    }
}
