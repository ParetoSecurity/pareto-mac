//
//  ScreenSharing.swift
//  ScreenSharingCheck
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation

class ScreenSharingCheck: ParetoCheck {
    static let sharedInstance = ScreenSharingCheck()

    override var UUID: String {
        "6f696d41-d626-480a-8ac2-d386adc346bd"
    }

    override var TitleON: String {
        "Screen Sharing is off"
    }

    override var TitleOFF: String {
        "Screen Sharing is on"
    }

    override func checkPasses() -> Bool {
        isNotListening(withPort: 5900)
    }
}
