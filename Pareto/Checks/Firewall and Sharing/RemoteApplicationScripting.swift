//
//  RemoteApplicationScripting.swift
//  RemoteApplicationScriptingCheck
//
//  Created by ArchitektApx on 04/11/2026.
//

import Foundation

class RemoteApplicationScriptingCheck: ParetoCheck {
    static let sharedInstance = RemoteApplicationScriptingCheck()

    override var UUID: String {
        "9be07305-1f70-4062-8901-a82f3e185658"
    }

    override var TitleON: String {
        "Remote Application Scripting is off"
    }

    override var TitleOFF: String {
        "Remote Application Scripting is on"
    }

    override func checkPasses() -> Bool {
        isNotListening(withPort: 3031)
    }
}
