//
//  Checks.swift
//  Pareto Security
//
//  Created by Janez Troha on 21/12/2021.
//

import Defaults
import Foundation
import os.log

class Claims: ObservableObject {
    var customChecks: [ParetoCheck] = []
    var all: [Claim] = []

    static let global = Claims()

    init() {
        refresh()
    }

    func refresh() {
        all = [
            Claim(withTitle: "macOS Updates", withChecks: [
                MacOSVersionCheck.sharedInstance,
                SecurityUpdateCheck.sharedInstance,
                AutomaticDownloadCheck.sharedInstance,
                SystemUpdatesCheck.sharedInstance,
                AutoUpdateCheck.sharedInstance,
            ]),
            Claim(withTitle: "Access Security", withChecks: [
                AutologinCheck.sharedInstance,
                PasswordManager.sharedInstance,
                RequirePasswordToUnlock.sharedInstance,
                ScreensaverCheck.sharedInstance,
                SSHKeysCheck.sharedInstance,
                SSHKeysStrengthCheck.sharedInstance,
                SSHAgentForwardingCheck.sharedInstance,
                SSHHostKeyVerificationCheck.sharedInstance,
                PlaintextCredentialsCheck.sharedInstance,
                PasswordAfterSleepCheck.sharedInstance,
                NoUnusedUsers.sharedInstance,
                NoAdminUser.sharedInstance,
            ] + (SudoRequiresPasswordCheck.isSupported ? [SudoRequiresPasswordCheck.sharedInstance] : [])),
            Claim(withTitle: "Firewall & Sharing", withChecks: [
                FirewallCheck.sharedInstance,
                FirewallStealthCheck.sharedInstance,
                FirewallExceptionsCheck.sharedInstance,
                FileSharingCheck.sharedInstance,
                PrinterSharingCheck.sharedInstance,
                RemoteManagementCheck.sharedInstance,
                ScreenSharingCheck.sharedInstance,
                RemoteLoginCheck.sharedInstance,
                RemoteApplicationScriptingCheck.sharedInstance,
                AirPlayCheck.sharedInstance,
                AirDropCheck.sharedInstance,
                MediaShareCheck.sharedInstance,
                InternetShareCheck.sharedInstance,
            ]),
            Claim(withTitle: "System Integrity", withChecks: [
                GatekeeperCheck.sharedInstance,
                FileVaultCheck.sharedInstance,
                BootCheck.sharedInstance,
                UptimeCheck.sharedInstance,
                OpenWiFiCheck.sharedInstance,
                TimeMachineCheck.sharedInstance,
                SecureTerminalCheck.sharedInstance,
                SecureiTermCheck.sharedInstance,
                PackageManagerSupplyChainCheck.sharedInstance,
                EditorExtensionsSupplyChainCheck.sharedInstance,
                CompromisedCACheck.sharedInstance,
                TimeMachineHasBackupCheck.sharedInstance,
                TimeMachineIsEncryptedCheck.sharedInstance,
                TeamReportSentCheck.sharedInstance,
            ]),
            Claim(withTitle: "Application Updates", withChecks: Claims.updateChecks + [AutoUpdateAppCheck.sharedInstance, ParetoUpdated.sharedInstance]),
        ].sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
    }

    /// Configures all claims and waits for the pending lookups of their checks.
    /// The wait stops after `timeout` seconds.
    func prepareForReport(timeout: TimeInterval = 65) -> [ParetoCheck] {
        all.forEach { $0.configure() }
        let checks = all.flatMap(\.checksSorted)
        Self.prefetch(checks, timeout: timeout)
        return checks
    }

    @discardableResult
    static func prefetch(_ checks: [ParetoCheck], timeout: TimeInterval) -> Bool {
        let group = DispatchGroup()
        for check in checks {
            group.enter()
            check.prefetch { group.leave() }
        }
        if group.wait(timeout: .now() + timeout) == .timedOut {
            os_log("Timed out waiting for checks to resolve before report", log: Log.app)
            return false
        }
        return true
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
        AppProtonDriveCheck.sharedInstance,
        AppProtonMailCheck.sharedInstance,
        AppProtonVPNCheck.sharedInstance,
        AppSlackCheck.sharedInstance,
        AppTailscaleCheck.sharedInstance,
        AppZoomCheck.sharedInstance,
        AppSignalCheck.sharedInstance,
        AppWireGuardCheck.sharedInstance,
        AppLibreOfficeCheck.sharedInstance,
        AppSublimeTextCheck.sharedInstance,
        AppVSCodeCheck.sharedInstance,
        AdobeReaderCheck.sharedInstance,
        AppAnyDeskCheck.sharedInstance,
        AppLuLuCheck.sharedInstance,
        AppMicrosoftTeamsCheck.sharedInstance,
    ]
}
