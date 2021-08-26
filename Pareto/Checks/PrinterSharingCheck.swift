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

    override var Title: String {
        "Sharing printers if off"
    }

    override func checkPasses() -> Bool {
        return !isListening(withPort: 88)
    }
}
