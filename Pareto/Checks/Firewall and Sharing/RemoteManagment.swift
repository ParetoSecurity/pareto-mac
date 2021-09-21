//
//  RemoteManagment.swift
//  RemoteManagment
//
//  Created by Janez Troha on 08/09/2021.
//

import Foundation

class RemoteManagmentCheck: ParetoCheck {
    override var UUID: String {
        "05423213-50e7-4535-ac88-60cc21626378"
    }

    override var TitleON: String {
        "Remote Management is off"
    }

    override var TitleOFF: String {
        "Remote Management is on"
    }

    override func checkPasses() -> Bool {
        return isNotListening(withPort: 3283)
    }
}
