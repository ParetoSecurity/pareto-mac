//
//  PrinterSharingCheck.swift
//  PrinterSharingCheck
//
//  Created by Janez Troha on 19/08/2021.
//

class PrinterSharingCheck: ParetoCheck {
    static let sharedInstance = PrinterSharingCheck()
    override var UUID: String {
        "b96524e0-150b-4bb8-abc7-517051b6c14e"
    }

    override var TitleON: String {
        "Sharing printers is off"
    }

    override var TitleOFF: String {
        "Sharing printers is on"
    }

    override func checkPasses() -> Bool {
        let output = runCMD(app: "/usr/sbin/cupsctl", args: [])
        let settings = ["_share_printers=0", "_remote_admin=0", "_remote_any=0"]
        return settings.allSatisfy {
            output.contains($0)
        }
    }
}
