//
//  PrinterSharing.swift
//  PrinterSharing
//
//  Created by Janez Troha on 18/08/2021.
//

import Foundation

class PrinterSharingCheck: ParetoCheck {
    override var UUID: String {
        "b96524e0-150b-4bb8-abc7-517051b6c14e"
    }

    override var Title: String {
        "Printer sharing is disabled"
    }

    override func checkPasses() -> Bool {
        return !isListening(withPort: 88)
    }
}
