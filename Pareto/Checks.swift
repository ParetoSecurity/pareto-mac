//
//  Checks.swift
//  Pareto Security
//
//  Created by Janez Troha on 21/12/2021.
//

import Foundation

enum Claims {
    static let updateChecks = [
        App1Password7Check.sharedInstance,
        AppBitwardenCheck.sharedInstance,
        AppCyberduckCheck.sharedInstance,
        AppDashlaneCheck.sharedInstance,
        AppDockerCheck.sharedInstance,
        AppEnpassCheck.sharedInstance,
        AppFirefoxCheck.sharedInstance,
        AppGoogleChromeCheck.sharedInstance,
        AppiTermCheck.sharedInstance,
        AppNordLayerCheck.sharedInstance,
        AppSlackCheck.sharedInstance,
        AppTailscaleCheck.sharedInstance,
        AppZoomCheck.sharedInstance,
        AppSignalCheck.sharedInstance,
        AppWireGuardCheck.sharedInstance,
        AppLibreOfficeCheck.sharedInstance,
        AppSublimeTextCheck.sharedInstance,
        AppVSCodeCheck.sharedInstance
    ]

    static let all = [
        Claim(withTitle: "Access Security", withChecks: [
            AutologinCheck.sharedInstance,
            RequirePasswordToUnlock.sharedInstance,
            ScreensaverPasswordCheck.sharedInstance,
            ScreensaverCheck.sharedInstance,
            SSHKeysCheck.sharedInstance,
            SSHKeysStrenghtCheck.sharedInstance
        ]),
        Claim(withTitle: "Firewall & Sharing", withChecks: [
            FirewallCheck.sharedInstance,
            FileSharingCheck.sharedInstance,
            PrinterSharingCheck.sharedInstance,
            RemoteManagmentCheck.sharedInstance,
            RemoteLoginCheck.sharedInstance,
            AirPlayCheck.sharedInstance,
            MediaShareCheck.sharedInstance
        ]),
        Claim(withTitle: "System Integrity", withChecks: [
            GatekeeperCheck.sharedInstance,
            FileVaultCheck.sharedInstance,
            BootCheck.sharedInstance,
            OpenWiFiCheck.sharedInstance
        ]),
        Claim(withTitle: "Software Updates", withChecks: updateChecks + [MacOSVersionCheck.sharedInstance])
    ]

    static var sorted: [Claim] {
        Claims.all.sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
    }
}
