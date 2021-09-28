//
//  AirPlay.swift
//  AirPlay
//
//  Created by Janez Troha on 21/09/2021.
//

import Foundation

class AirPlayCheck: ParetoCheck {
    static let sharedInstance = AirPlayCheck()
    override var UUID: String {
        "0cd3ad3c-c41f-4291-82f8-c05dd23c0a9b"
    }

    override var TitleON: String {
        "AirPlay receiver is off"
    }

    override var TitleOFF: String {
        "AirPlay receiver is on"
    }

    override func checkPasses() -> Bool {
        return isNotListening(withPort: 5000) && isNotListening(withPort: 7000)
    }
}
