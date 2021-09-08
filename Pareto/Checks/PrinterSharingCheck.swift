//
//  PrinterSharingCheck.swift
//  PrinterSharingCheck
//
//  Created by Janez Troha on 19/08/2021.
//

class PrinterSharingCheck: ParetoCheck {
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
        return isNotListening(withPort: 631)
    }
}
