//
//  MediaShare.swift
//  MediaShare
//
//  Created by Janez Troha on 21/09/2021.
//

import Foundation

class MediaShareCheck: ParetoCheck {
    static let sharedInstance = MediaShareCheck()
    override var UUID: String {
        "0cd3ad3c-c41f-4291-82f8-c05dd23c0a9a"
    }

    override var TitleON: String {
        "Media Share is off"
    }

    override var TitleOFF: String {
        "Media Share is on"
    }

    override func checkPasses() -> Bool {
        return isNotListening(withPort: 3689)
    }
}
