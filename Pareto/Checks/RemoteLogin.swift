//
//  RemoteLogin.swift
//  RemoteLogin
//
//  Created by Janez Troha on 08/09/2021.
//

import Foundation

class RemoteLoginCheck: ParetoCheck {
    override var UUID: String {
        "4ced961d-7cfc-4e7b-8f80-195f6379446e"
    }

    override var TitleON: String {
        "Remote Login is off"
    }

    override var TitleOFF: String {
        "Remote Login is on"
    }

    override func checkPasses() -> Bool {
        return !isListening(withPort: 22)
    }
}
