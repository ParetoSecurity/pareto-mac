//
//  Checks.swift
//  Pareto Security
//
//  Created by Janez Troha on 21/12/2021.
//

import Defaults
import Foundation

class Claims: ObservableObject {
    var customChecks: [ParetoCheck] = []
    var all: [Claim] = []

    static let global = Claims()

    init() {
        refresh()
    }

    func refresh() {
        customChecks = initCustomChecks()
        all = [
            Claim(withTitle: "macOS Updates", withChecks: [
                MacOSVersionCheck.sharedInstance,
                SecurityUpdateCheck.sharedInstance,
                AutomaticDownloadCheck.sharedInstance,
                SystemUpdatesCheck.sharedInstance,
                AutoUpdateCheck.sharedInstance
            ]),
            Claim(withTitle: "Access Security", withChecks: [
                AutologinCheck.sharedInstance,
                RequirePasswordToUnlock.sharedInstance,
                ScreensaverCheck.sharedInstance,
                SSHKeysCheck.sharedInstance,
                SSHKeysStrengthCheck.sharedInstance,
                PasswordAfterSleepCheck.sharedInstance
            ]),
            Claim(withTitle: "Firewall & Sharing", withChecks: [
                FirewallCheck.sharedInstance,
                FirewallStealthCheck.sharedInstance,
                FileSharingCheck.sharedInstance,
                PrinterSharingCheck.sharedInstance,
                RemoteManagementCheck.sharedInstance,
                RemoteLoginCheck.sharedInstance,
                AirPlayCheck.sharedInstance,
                AirDropCheck.sharedInstance,
                MediaShareCheck.sharedInstance,
                InternetShareCheck.sharedInstance
            ]),
            Claim(withTitle: "System Integrity", withChecks: [
                GatekeeperCheck.sharedInstance,
                FileVaultCheck.sharedInstance,
                BootCheck.sharedInstance,
                OpenWiFiCheck.sharedInstance,
                TimeMachineCheck.sharedInstance,
                SecureTerminalCheck.sharedInstance,
                SecureiTermCheck.sharedInstance,
                TimeMachineHasBackupCheck.sharedInstance,
                TimeMachineIsEncryptedCheck.sharedInstance
            ]),
            ClaimWithNudge(withTitle: "Software Updates", withChecks: Claims.updateChecks + [AutoUpdateAppCheck.sharedInstance]),
            Claim(withTitle: "My Checks", withChecks: customChecks)
        ].sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
    }

    static let updateChecks = [
        App1Password7Check.sharedInstance,
        App1Password8Check.sharedInstance,
        AppGrammarlyCheck.sharedInstance,
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
        AppVSCodeCheck.sharedInstance,
        AdobeReaderCheck.sharedInstance,
        AppLuLuCheck.sharedInstance,
        AppMicrosoftTeamsCheck.sharedInstance
    ]

    func initCustomChecks() -> [ParetoCheck] {
        var myChecks: [ParetoCheck] = []

        if !Defaults[.myChecks] {
            return myChecks
        }

        for rule in CustomCheck.getRules() {
            let check = MyCheck(check: rule)
            check.configure()
            myChecks.append(check)
        }
        return myChecks
    }
}
